import UIKit

final class KeyboardViewController: UIInputViewController {
    private let keyboard = KeyboardView()
    private let scratchpad = ScratchpadView()
    private let favoritePad = FavoriteSymbolsPanel()
    private let scratchpadDocumentID = UUID()
    private var scratchpadWidth: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var normalSplitConstraints: [NSLayoutConstraint] = []
    private var leftSplitConstraints: [NSLayoutConstraint] = []
    private var isLeftHanded = false
    private var inputState = InputState()
    private var punctuationSpacing = PunctuationSpacing()
    private var noteSpacing = PunctuationSpacing()
    /// Only the most recent uninterrupted glide can be undone as a whole.
    /// Keep the exact inserted suffix so an outside edit never deletes other text.
    private var pendingGlide: (inserted: String, inNotes: Bool)?
    private var expander = TextExpander()
    private var lastKeyboardType: UIKeyboardType?
    private var lastHostDocument: UUID?
    private var reportedLanguage: KeyboardLanguage?
    /// iOS builds a new controller each time the keyboard appears and may unload the
    /// process between uses, so the language memory is kept in the keyboard's defaults.
    private static var memory = LanguageMemoryStore.load()
        ?? LanguageMemory(startingLanguage: KeyboardPreferences().defaultLanguage)
    private var languageContext: LanguageContext?
    private lazy var suggestions = SuggestionCoordinator(keyboard: keyboard)
    private var applyingSuggestion = false
    /// Shift that automatic capitals turned on, so they may also turn it off.
    private var autoShifted = false
    /// The text before the caret when the person last pressed Shift themselves.
    private var manualShiftContext: String?
    /// Safari's address bar is a web search field: mostly searches, so it gets suggestions
    /// and glide. URL-looking tokens never get suggestions, whatever the field.
    private static let suggestionTypes: [UIKeyboardType] = [.default, .asciiCapable, .twitter, .webSearch]
    /// URL/email fields need literal punctuation, never automatic spaces or capitals.
    private static let literalTypes: [UIKeyboardType] = [.URL, .emailAddress, .webSearch]

    override func viewDidLoad() {
        super.viewDidLoad()
        keyboard.accessibilityIdentifier = "system-keyboard-surface"
        keyboard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboard)
        // Overlay remains inside the keyboard extension, so symbols work in
        // every app that supports custom keyboards. It never steals note focus.
        favoritePad.translatesAutoresizingMaskIntoConstraints = false
        favoritePad.isHidden = true
        keyboard.addSubview(favoritePad)
        NSLayoutConstraint.activate([
            favoritePad.leadingAnchor.constraint(equalTo: keyboard.leadingAnchor),
            favoritePad.trailingAnchor.constraint(equalTo: keyboard.trailingAnchor),
            favoritePad.topAnchor.constraint(equalTo: keyboard.topAnchor),
            favoritePad.bottomAnchor.constraint(equalTo: keyboard.bottomAnchor)
        ])
        favoritePad.onClose = { [weak self] in self?.favoritePad.isHidden = true }
        favoritePad.onPick = { [weak self] character in self?.insertFavorite(character) }
        scratchpad.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scratchpad)
        scratchpadWidth = scratchpad.widthAnchor.constraint(equalToConstant: 0)
        scratchpadWidth?.isActive = true
        scratchpad.onInsert = { [weak self] text in
            self?.textDocumentProxy.insertText(text)
            self?.suggestions.refresh(force: true)
        }
        scratchpad.onEditingChange = { [weak self] active in
            self?.keyboard.editingScratchpad = active
            self?.pendingGlide = nil
            self?.noteSpacing.reset()
            self?.expander.forget()
            self?.suggestions.cancelGlide()
            self?.updateAutoShift()
            if let self { self.keyboard.inputState = self.inputState }
            self?.suggestions.refresh(force: true)
        }
        scratchpad.onTextChange = { [weak self] in
            // Ordinary input already changes the snapshot; do not force-rebuild
            // the suggestions UI for every character or during a glide insertion.
            self?.suggestions.refresh()
        }
        scratchpad.canUseClipboard = hasFullAccess
        NSLayoutConstraint.activate([
            scratchpad.topAnchor.constraint(equalTo: view.topAnchor),
            scratchpad.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keyboard.topAnchor.constraint(equalTo: view.topAnchor),
            keyboard.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        normalSplitConstraints = [
            scratchpad.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboard.leadingAnchor.constraint(equalTo: scratchpad.trailingAnchor),
            keyboard.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ]
        leftSplitConstraints = [
            keyboard.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scratchpad.leadingAnchor.constraint(equalTo: keyboard.trailingAnchor),
            scratchpad.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ]
        NSLayoutConstraint.activate(normalSplitConstraints)
        let height = view.heightAnchor.constraint(equalToConstant: keyboard.preferences.keyboardHeight)
        height.priority = .init(999)
        height.isActive = true
        heightConstraint = height
        keyboard.globeButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        suggestions.snapshot = { [weak self] in self?.suggestionSnapshot() }
        suggestions.apply = { [weak self] edit, snapshot in self?.applySuggestion(edit, snapshot: snapshot) }
        suggestions.insertWord = { [weak self] in self?.insertGlided($0) }
        suggestions.glideContext = { [weak self] in self?.glideContext() }
        suggestions.switchLanguage = { [weak self] in self?.switchLanguage(to: $0) }
        keyboard.onAction = { [weak self] in self?.handle($0) }
        keyboard.onLanguageHold = { [weak self] in
            guard let self else { return }
            let languages = self.keyboard.preferences.validated.languages
            guard languages.count > 1 else { return }
            self.switchLanguage(to: self.keyboard.preferences.language(after: self.inputState.language))
        }
        keyboard.onCursor = { [weak self] in
            guard let self else { return }
            self.suggestions.cancelGlide()
            self.pendingGlide = nil
            if self.scratchpad.isEditingNote {
                self.scratchpad.moveCaret(steps: $0)
                return
            }
            self.punctuationSpacing.reset()
            let proxy = self.textDocumentProxy
            proxy.adjustTextPosition(byCharacterOffset: TextNavigation.offset(
                steps: $0,
                before: proxy.documentContextBeforeInput ?? "",
                after: proxy.documentContextAfterInput ?? ""
            ))
            self.updateAutoShift()
            self.suggestions.refresh()
        }
        keyboard.onCursorVertical = { [weak self] rows in
            guard let self, rows != 0 else { return }
            self.pendingGlide = nil
            self.suggestions.cancelGlide()
            if self.scratchpad.isEditingNote {
                self.scratchpad.moveCaretVertically(rows: rows)
                return
            }
            // UITextDocumentProxy doesn't expose visual soft-wrapped lines.
            // Use hard-line boundaries; avoid guessing and moving into other text.
            let proxy = self.textDocumentProxy
            let before = proxy.documentContextBeforeInput ?? ""
            let after = proxy.documentContextAfterInput ?? ""
            for _ in 0..<abs(rows) {
                guard let offset = TextNavigation.verticalOffset(
                    rows: rows < 0 ? -1 : 1, before: proxy.documentContextBeforeInput ?? before,
                    after: proxy.documentContextAfterInput ?? after) else { break }
                proxy.adjustTextPosition(byCharacterOffset: offset)
            }
            self.updateAutoShift()
            self.suggestions.refresh()
        }
        keyboard.onDismiss = { [weak self] in self?.suggestions.cancelGlide(); self?.dismissKeyboard() }
        adoptLanguageSettings(PreferenceStore.load())
        inputState.language = Self.memory.fallback
        keyboard.inputState = inputState
        suggestions.refresh()
        // The completion arrives on an XPC queue, not the main thread.
        requestSupplementaryLexicon { @Sendable [weak self] lexicon in
            // Apple isolates UILexicon entries on the main actor. Transfer the
            // immutable result to MainActor before extracting those properties.
            let transfer = KeyScratchLexiconTransfer(value: lexicon)
            Task { @MainActor in
                let words = SupplementaryWords(entries: transfer.value.entries.map {
                    ($0.userInput, $0.documentText)
                })
                self?.suggestions.supplementary = words
                self?.suggestions.refresh(force: true)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        punctuationSpacing.reset()
        noteSpacing.reset()
        pendingGlide = nil
        // An extension instance can survive switching back to the containing app.
        // Always reload the shared note before any new editing, never overwrite
        // companion-app changes with the extension's stale text.
        scratchpad.deactivate()
        scratchpad.reloadSharedNote()
        let preferences = PreferenceStore.load()
        adoptLanguageSettings(preferences)
        scratchpad.canUseClipboard = hasFullAccess
        // The temporary color-coded comparisons are finished. The public
        // keyboard is the optimized split layout with neutral scratchpad chrome.
        scratchpad.isHidden = false
        scratchpad.configure(font: preferences.keyScratchNoteFont,
                             size: preferences.keyScratchNoteFontSize,
                             style: preferences.scratchpadVisualStyle)
        applyHandedness(preferences.leftHandedLayout)
        favoritePad.isHidden = true
        keyboard.preferences = preferences
        view.setNeedsLayout()
        heightConstraint?.constant = keyboard.layoutHeight
        lastKeyboardType = nil
        suggestions.beginSession()
        synchronize()
    }

    override func viewWillDisappear(_ animated: Bool) {
        keyboard.cancelTouches()
        suggestions.releaseMemory()
        super.viewWillDisappear(animated)
    }

    private func applyHandedness(_ leftHanded: Bool) {
        guard isLeftHanded != leftHanded else { return }
        NSLayoutConstraint.deactivate(isLeftHanded ? leftSplitConstraints : normalSplitConstraints)
        NSLayoutConstraint.activate(leftHanded ? leftSplitConstraints : normalSplitConstraints)
        isLeftHanded = leftHanded
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Draw the note's frame in exactly the same color as the keyboard
        // background, including dark mode and selectable keyboard themes.
        scratchpad.keyboardSurroundColor = keyboard.backgroundColor ?? .systemGray5
        if keyboard.needsGlobe != needsInputModeSwitchKey {
            keyboard.needsGlobe = needsInputModeSwitchKey
        }
        let available = Double(view.bounds.width)
        guard available > 0 else { return }
        // The host owns outer system controls. Left-handed mode reverses
        // the split in both orientations while keeping the same dimensions.
        let landscape = view.window?.windowScene?.interfaceOrientation.isLandscape
            ?? (traitCollection.verticalSizeClass == .compact && available >= 600)
        if keyboard.compactLandscape != landscape {
            keyboard.compactLandscape = landscape
        }
        let desiredHeight = keyboard.layoutHeight
        if abs((heightConstraint?.constant ?? 0) - desiredHeight) > 0.5 {
            heightConstraint?.constant = desiredHeight
        }
        let keyboardWidth = KeyScratchAdaptiveLayout.keyboardWidth(
            availableWidth: available,
            landscape: landscape,
            portraitNoteFraction: keyboard.preferences.keyScratchNoteWidth)
        let noteWidth = (available - keyboardWidth).rounded(.toNearestOrAwayFromZero)
        if abs((scratchpadWidth?.constant ?? 0) - noteWidth) > 0.5 {
            scratchpadWidth?.constant = noteWidth
        }
    }

    override func textWillChange(_ textInput: (any UITextInput)?) {
        super.textWillChange(textInput)
        // A new host text input becoming active should take focus from notes.
        if scratchpad.isEditingNote { scratchpad.deactivate() }
    }
    override func textDidChange(_ textInput: (any UITextInput)?) {
        guard !applyingSuggestion else { return }
        if scratchpad.isEditingNote { scratchpad.deactivate() }
        suggestions.cancelGlide()
        synchronize()
    }
    override func selectionDidChange(_ textInput: (any UITextInput)?) {
        guard !applyingSuggestion else { return }
        // Tapping a different caret in the host app restores normal typing.
        if scratchpad.isEditingNote { scratchpad.deactivate() }
        // Hosts may announce a caret change after textDocumentProxy.insertText.
        // Keep the word-level Delete option until the actual suffix changes.
        if let pendingGlide, !pendingGlide.inNotes,
           textDocumentProxy.documentContextBeforeInput?.hasSuffix(pendingGlide.inserted) != true {
            self.pendingGlide = nil
        }
        suggestions.cancelGlide()
        updateAutoShift()
        keyboard.inputState = inputState
        suggestions.refresh()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        suggestions.releaseMemory()
    }

    private func suggestionSnapshot() -> SuggestionSnapshot? {
        if scratchpad.isEditingNote {
            return scratchpad.snapshot(document: scratchpadDocumentID, language: inputState.language)
        }
        guard isViewLoaded, view.window != nil, lastKeyboardType != nil else { return nil }
        let allowed = Self.suggestionTypes
        guard allowed.contains(textDocumentProxy.keyboardType ?? .default),
              textDocumentProxy.isSecureTextEntry != true else { return nil }
        let before = textDocumentProxy.documentContextBeforeInput
        let after = textDocumentProxy.documentContextAfterInput
        let selected = textDocumentProxy.selectedText ?? ""
        // A completely unavailable context is not a safe replacement target.
        guard before != nil || after != nil || !selected.isEmpty, let document = documentIdentifier else { return nil }
        return .init(document: document, before: before ?? "", after: after ?? "",
                     selection: selected, language: inputState.language)
    }

    /// documentIdentifier is nil while the proxy is between documents, despite its nonoptional
    /// Swift type, and bridging that nil to UUID traps. Asking through Objective-C allows nil.
    private var documentIdentifier: UUID? {
        let getter = #selector(getter: UITextDocumentProxy.documentIdentifier)
        guard textDocumentProxy.responds(to: getter) else { return nil }
        return textDocumentProxy.perform(getter)?.takeUnretainedValue() as? UUID
    }

    private func glideContext() -> GlideContext? {
        if scratchpad.isEditingNote {
            return GlideContext(language: inputState.language, before: scratchpad.beforeCaret,
                                selection: scratchpad.selectedNoteText, document: scratchpadDocumentID)
        }
        guard isViewLoaded, view.window != nil, lastKeyboardType != nil else { return nil }
        let allowed = Self.suggestionTypes
        guard allowed.contains(textDocumentProxy.keyboardType ?? .default),
              textDocumentProxy.isSecureTextEntry != true else { return nil }
        return GlideContext(language: inputState.language,
                            before: textDocumentProxy.documentContextBeforeInput ?? "",
                            selection: textDocumentProxy.selectedText ?? "", document: documentIdentifier)
    }

    private func applySuggestion(_ edit: SuggestionEdit, snapshot: SuggestionSnapshot) {
        pendingGlide = nil
        if scratchpad.isEditingNote {
            _ = scratchpad.apply(edit, offered: snapshot, document: scratchpadDocumentID,
                                 language: inputState.language)
            return
        }
        guard suggestionSnapshot() == snapshot else { return }
        applyingSuggestion = true
        defer { applyingSuggestion = false }
        punctuationSpacing.reset()
        expander.forget()
        if edit.moveRight != 0 {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: edit.moveRight)
            // Some hosts don't honor cursor movement. Never delete from the old caret.
            let expected = snapshot.before + edit.right
            guard textDocumentProxy.documentContextBeforeInput?.hasSuffix(expected.suffix(24)) == true else { return }
        }
        for _ in 0..<edit.deleteCount { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(edit.text)
        if edit.text.hasSuffix(" ") {
            punctuationSpacing.adoptSpace(before: textDocumentProxy.documentContextBeforeInput ?? "", at: ProcessInfo.processInfo.systemUptime)
        }
        updateAutoShift()
        keyboard.inputState = inputState
    }

    /// Inserts exactly one separator *after* the word, the behavior iOS users
    /// expect when a swipe is immediately followed by individual key taps.
    /// A punctuation mark can replace that separator; Delete can remove the
    /// entire most recent glide rather than a single letter.
    private func insertGlided(_ word: String) -> String? {
        guard isViewLoaded, inputState.page == .letters else { return nil }
        applyingSuggestion = true
        defer { applyingSuggestion = false }
        var text = inputState.language == .english && word == "i" ? "I" : word
        switch inputState.shift {
        case .once:
            text = text.prefix(1).uppercased() + text.dropFirst()
            inputState.shift = .off
            autoShifted = false
        case .locked: text = text.uppercased()
        case .off: break
        }
        expander.forget()
        let inNotes = scratchpad.isEditingNote
        let before = inNotes ? scratchpad.beforeCaret : (textDocumentProxy.documentContextBeforeInput ?? "")
        let after = inNotes ? scratchpad.afterCaret : (textDocumentProxy.documentContextAfterInput ?? "")
        let selected = inNotes ? scratchpad.selectedNoteText : (textDocumentProxy.selectedText ?? "")
        let needsLeadingSpace = selected.isEmpty && (before.last.map {
            !$0.isWhitespace && !"([{«„“'\"-‐‑–—/’ʼ".contains($0)
        } ?? false)
        let needsTrailingSpace = after.first.map {
            !$0.isWhitespace && !".,!?;:)]}\"'-‐‑–—/’ʼ".contains($0)
        } ?? true
        let inserted = (needsLeadingSpace ? " " : "") + text + (needsTrailingSpace ? " " : "")
        pendingGlide = (inserted, inNotes)
        if inNotes {
            noteSpacing.reset()
            scratchpad.type(inserted)
            if needsTrailingSpace {
                noteSpacing.adoptSpace(before: scratchpad.beforeCaret)
            }
        } else {
            punctuationSpacing.reset()
            textDocumentProxy.insertText(inserted)
            if needsTrailingSpace {
                // Time 0 ensures a first explicit space accepts the automatic one
                // without accidentally triggering the two-space period shortcut.
                punctuationSpacing.adoptSpace(
                    before: textDocumentProxy.documentContextBeforeInput ?? "")
            }
        }
        updateAutoShift()
        keyboard.inputState = inputState
        return text
    }

    /// The first Delete after a glide removes exactly that just-inserted word.
    /// If the host edited its text meanwhile, the suffix check fails safely.
    private func deleteRecentGlide(inNotes: Bool) -> Bool {
        guard let pendingGlide, pendingGlide.inNotes == inNotes else { return false }
        let before = inNotes ? scratchpad.beforeCaret : (textDocumentProxy.documentContextBeforeInput ?? "")
        let selected = inNotes ? scratchpad.selectedNoteText : (textDocumentProxy.selectedText ?? "")
        guard selected.isEmpty, before.hasSuffix(pendingGlide.inserted) else {
            self.pendingGlide = nil
            return false
        }
        if inNotes {
            scratchpad.replaceBeforeCaret(characters: pendingGlide.inserted.count, with: "")
            noteSpacing.reset()
        } else {
            for _ in pendingGlide.inserted { textDocumentProxy.deleteBackward() }
            punctuationSpacing.reset()
        }
        self.pendingGlide = nil
        return true
    }

    /// Automatically capitalize English's standalone pronoun, including "i'm".
    /// Delay replacement until the following delimiter so "inside" remains
    /// lowercase while the user types it one character at a time.
    private func capitalizeStandaloneI(before: String, incoming: String, inNotes: Bool) {
        guard inputState.language == .english, before.last == "i",
              incoming == " " || incoming == "\n" || incoming == "'" || incoming == "’"
                  || incoming == "." || incoming == "," || incoming == "!" || incoming == "?" else { return }
        let previous = before.dropLast().last
        guard !(previous.map { $0.isLetter || $0.isNumber } ?? false) else { return }
        if inNotes {
            scratchpad.replaceBeforeCaret(characters: 1, with: "I")
        } else {
            textDocumentProxy.deleteBackward()
            textDocumentProxy.insertText("I")
        }
    }

    /// Punctuation spacing, the double-space period, and text replacements
    /// follow the same rules in the scratchpad as in the host app.
    @discardableResult
    private func insertNote(_ value: String) -> String {
        let before = scratchpad.beforeCaret
        capitalizeStandaloneI(before: before, incoming: value, inNotes: true)
        let prefs = keyboard.preferences
        let edit = noteSpacing.edit(for: value, before: scratchpad.beforeCaret,
                                    enabled: prefs.autoSpacePunctuation,
                                    doubleSpacePeriod: prefs.doubleSpacePeriod,
                                    at: ProcessInfo.processInfo.systemUptime,
                                    shortcutStarts: availableExpansions.shortcutStarts)
        if edit.deleteBackward { scratchpad.deleteBackward() }
        if !edit.text.isEmpty { scratchpad.type(edit.text) }
        return edit.text
    }

    private func insertFavorite(_ symbol: String) {
        guard !symbol.isEmpty else { return }
        favoritePad.isHidden = true
        FavoriteSymbolsHistory.record(symbol)
        suggestions.cancelGlide()
        pendingGlide = nil
        expander.forget()
        punctuationSpacing.reset()
        noteSpacing.reset()
        if scratchpad.isEditingNote {
            scratchpad.type(symbol)
        } else {
            textDocumentProxy.insertText(symbol)
        }
        updateAutoShift()
        keyboard.inputState = inputState
        suggestions.refresh(force: true)
    }

    private func switchLanguage(to language: KeyboardLanguage) {
        guard keyboard.preferences.validated.languages.contains(language) else { return }
        inputState.language = language
        inputState.page = .letters
        let context = languageContext ?? LanguageContext()
        updateMemory { $0.record(language, in: context, chosen: true) }
        reportLanguageIfNeeded()
        keyboard.inputState = inputState
    }

    private var autocapitalization: AutoCapitalization {
        if scratchpad.isEditingNote { return keyboard.preferences.autoCapitalize ? .sentences : .none }
        guard keyboard.preferences.autoCapitalize,
              !Self.literalTypes.contains(textDocumentProxy.keyboardType ?? .default) else { return .none }
        switch textDocumentProxy.autocapitalizationType ?? .sentences {
        case .none: return .none
        case .words: return .words
        case .allCharacters: return .allCharacters
        default: return .sentences
        }
    }

    /// Turns Shift on for one letter where the field's own capitalization asks for it.
    private func updateAutoShift() {
        guard inputState.page == .letters, inputState.shift != .locked else { return }
        let before: String? = scratchpad.isEditingNote
            ? scratchpad.beforeCaret : textDocumentProxy.documentContextBeforeInput
        guard manualShiftContext != (before ?? "") else { return }
        manualShiftContext = nil
        // A host that hides its context must not get a capital on every letter.
        let wanted = !(before == nil && textDocumentProxy.hasText) && autocapitalization.shouldCapitalize(before: before)
        if wanted, inputState.shift == .off {
            inputState.shift = .once
            autoShifted = true
        } else if !wanted, autoShifted, inputState.shift == .once {
            inputState.shift = .off
            autoShifted = false
        }
    }

    private func synchronize() {
        guard isViewLoaded else { return }
        // Switching to a different host text field is always a request to type
        // there, even if the scratchpad had previously been active.
        if let current = documentIdentifier {
            if let previous = lastHostDocument, previous != current, scratchpad.isEditingNote {
                scratchpad.deactivate()
            }
            lastHostDocument = current
        }
        let type = textDocumentProxy.keyboardType ?? .default
        // The proxy is not attached to a document during viewDidLoad. In particular,
        // documentIdentifier can be nil in Objective-C despite its nonoptional Swift API.
        if lastKeyboardType != type {
            keyboard.cancelTouches()
            lastKeyboardType = type
            inputState.shift = .off
            switch type {
            case .numberPad, .decimalPad, .numbersAndPunctuation, .asciiCapableNumberPad:
                inputState.page = .numbers
            default: inputState.page = .letters
            }
            languageContext = nil
        }
        let context = currentLanguageContext(type: type)
        if context != languageContext { resolveLanguage(in: context) }
        reportLanguageIfNeeded()
        keyboard.needsGlobe = needsInputModeSwitchKey
        keyboard.returnTitle = returnLabel
        keyboard.returnEnabled = !(textDocumentProxy.enablesReturnKeyAutomatically ?? false) || textDocumentProxy.hasText
        updateAutoShift()
        keyboard.inputState = inputState
        suggestions.refresh()
    }

    private func currentLanguageContext(type: UIKeyboardType) -> LanguageContext {
        var context = LanguageContext(requiresLatin: [.emailAddress, .URL, .asciiCapable].contains(type))
        guard keyboard.preferences.rememberLanguage else { return context }
        // Keyboards never learn the app, window or chat (conversationContext isn't
        // delivered to them), and documentIdentifier is new on every focus. These traits
        // survive refocusing, so a message box, a search box and an address bar each
        // keep their own language. Capitalization isn't used: it changes on resign.
        context.field = [String(type.rawValue), String((textDocumentProxy.returnKeyType ?? .default).rawValue),
                         (textDocumentProxy.textContentType ?? nil)?.rawValue ?? ""].joined(separator: "|")
        return context
    }

    private func resolveLanguage(in context: LanguageContext) {
        languageContext = context
        let preferences = keyboard.preferences
        let suggested = preferences.rememberLanguage
            ? textDocumentProxy.documentInputMode?.primaryLanguage.flatMap(KeyboardLanguage.init(languageCode:)) : nil
        let language = Self.memory.resolve(context, enabled: preferences.validated.languages, suggested: suggested)
        inputState.language = language
        updateMemory { $0.record(language, in: context, chosen: false) }
    }

    private func adoptLanguageSettings(_ preferences: KeyboardPreferences) {
        updateMemory {
            $0.adopt(startingLanguage: preferences.defaultLanguage, generation: preferences.languageMemoryGeneration,
                     enabled: preferences.validated.languages)
        }
    }

    private func updateMemory(_ change: (inout LanguageMemory) -> Void) {
        var memory = Self.memory
        change(&memory)
        guard memory != Self.memory else { return }
        Self.memory = memory
        LanguageMemoryStore.save(memory)
    }

    private func reportLanguageIfNeeded() {
        // The proxy can echo an older/normalized primaryLanguage while host updates
        // are in flight. Track what we sent, so text callbacks cannot feed back
        // another language notification for an unchanged keyboard language.
        guard reportedLanguage != inputState.language else { return }
        reportedLanguage = inputState.language
        primaryLanguage = inputState.language.code
        suggestions.prepareGlide(for: inputState.language)
    }

    private var returnLabel: String {
        switch textDocumentProxy.returnKeyType ?? .default {
        case .go: "go"
        case .search, .google, .yahoo: "search"
        case .send: "send"
        case .next: "next"
        case .done: "done"
        case .join: "join"
        case .route: "route"
        default: "return"
        }
    }

    private func handle(_ action: KeyAction) {
        if scratchpad.isEditingNote {
            if action != .backspace && action != .shift { pendingGlide = nil }
            switch action {
            case .text(let value):
                let typed = inputState.consume(value)
                expandNote(before: typed)
                expander.triggerTyped(as: insertNote(typed))
                updateAutoShift()
                keyboard.inputState = inputState
                return
            case .space:
                expandNote(before: " ")
                expander.triggerTyped(as: insertNote(" "))
                inputState.returnToLettersAfterSpace()
                updateAutoShift()
                keyboard.inputState = inputState
                return
            case .enter:
                expandNote(before: "\n")
                expander.triggerTyped(as: insertNote("\n"))
                updateAutoShift()
                keyboard.inputState = inputState
                return
            case .backspace:
                if !deleteRecentGlide(inNotes: true) {
                    noteSpacing.reset()
                    if let edit = expander.revert(before: scratchpad.beforeCaret,
                                                  selected: scratchpad.selectedNoteText) {
                        scratchpad.replaceBeforeCaret(characters: edit.deleteCount, with: edit.insert)
                    } else {
                        scratchpad.deleteBackward()
                    }
                }
                updateAutoShift()
                keyboard.inputState = inputState
                return
            case .command(let command):
                expander.forget()
                switch TextNavigation.edit(for: command, before: scratchpad.beforeCaret,
                                           after: scratchpad.afterCaret) {
                case .move(let offset): scratchpad.moveCaret(steps: offset)
                case .deleteBackward(let count):
                    for _ in 0..<count { scratchpad.deleteBackward() }
                case nil: break
                }
                return
            case .pair(let value, let back):
                expander.forget()
                scratchpad.type(value)
                scratchpad.moveCaret(steps: -String(value.suffix(back)).count)
                return
            default: break
            }
        }
        suggestions.cancelGlide()
        if action != .backspace && action != .shift { pendingGlide = nil }
        switch action {
        case .text, .space, .enter, .backspace: break
        default: expander.forget()
        }
        switch action {
        case .text(let value):
            let typed = inputState.consume(value)
            expand(before: typed)
            expander.triggerTyped(as: insert(typed))
        case .space:
            expand(before: " ")
            expander.triggerTyped(as: insert(" "))
            inputState.returnToLettersAfterSpace()
        case .backspace:
            if !deleteRecentGlide(inNotes: false) {
                punctuationSpacing.reset()
                if let edit = expander.revert(before: textDocumentProxy.documentContextBeforeInput ?? "",
                                               selected: textDocumentProxy.selectedText ?? "") {
                    for _ in 0..<edit.deleteCount { textDocumentProxy.deleteBackward() }
                    textDocumentProxy.insertText(edit.insert)
                } else {
                    textDocumentProxy.deleteBackward()
                }
            }
        case .enter: expand(before: "\n"); expander.triggerTyped(as: insert("\n"))
        case .shift:
            if inputState.page == .letters {
                inputState.tapShift(at: Date.timeIntervalSinceReferenceDate)
                autoShifted = false
                manualShiftContext = textDocumentProxy.documentContextBeforeInput ?? ""
            } else { inputState.page = KeyboardLayout.page(after: inputState.page, preferences: keyboard.preferences) }
        case .favorites:
            // Tapping the scratchpad and a host field already selects the
            // text destination, so this control now opens one-tap characters.
            favoritePad.configure(symbols: FavoriteSymbolsHistory.display(
                favorites: keyboard.preferences.favoriteSymbols))
            favoritePad.isHidden.toggle()
        case .language:
            inputState.language = keyboard.preferences.language(after: inputState.language)
            inputState.page = .letters
            let language = inputState.language, context = languageContext ?? LanguageContext()
            updateMemory { $0.record(language, in: context, chosen: true) }
        case .page: inputState.page = inputState.page == .letters ? .numbers : .letters
        case .layers: inputState.page = KeyboardLayout.firstLayerPage(keyboard.preferences) ?? .letters
        case .command(let command):
            punctuationSpacing.reset()
            switch TextNavigation.edit(for: command, before: textDocumentProxy.documentContextBeforeInput ?? "",
                                       after: textDocumentProxy.documentContextAfterInput ?? "") {
            case .move(let offset): textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
            case .deleteBackward(let count): for _ in 0..<count { textDocumentProxy.deleteBackward() }
            case nil: break
            }
        case .pair(let text, let back):
            punctuationSpacing.reset()
            textDocumentProxy.insertText(text)
            textDocumentProxy.adjustTextPosition(byCharacterOffset: -String(text.suffix(back)).utf16.count)
        case .globe: advanceToNextInputMode()
        case .dismiss: dismissKeyboard()
        }
        reportLanguageIfNeeded()
        keyboard.returnEnabled = !(textDocumentProxy.enablesReturnKeyAutomatically ?? false) || textDocumentProxy.hasText
        if action != .shift { updateAutoShift() }
        keyboard.inputState = inputState
        suggestions.refresh()
    }

    private var hasSelection: Bool { !(textDocumentProxy.selectedText ?? "").isEmpty }

    private var availableExpansions: [TextExpansion] {
        var result = keyboard.preferences.shownExpansions
        let custom = Set(result.map { $0.abbreviation.lowercased() })
        for (shortcut, expansion) in suggestions.supplementary.shortcuts
            where !custom.contains(shortcut.lowercased()) {
            result.append(TextExpansion(shortcut, expansion))
        }
        return result
    }

    /// Uses the same custom and iOS text replacements within the local scratchpad.
    private func expandNote(before trigger: String) {
        guard let edit = expander.expand(before: scratchpad.beforeCaret, trigger: trigger,
                                         expansions: availableExpansions,
                                         selected: scratchpad.selectedNoteText) else { return }
        scratchpad.replaceBeforeCaret(characters: edit.deleteCount, with: edit.insert)
    }

    /// Swaps a just-finished shortcut for its expansion, before `trigger` is typed after it.
    private func expand(before trigger: String) {
        guard let edit = expander.expand(before: textDocumentProxy.documentContextBeforeInput ?? "", trigger: trigger,
                                         expansions: availableExpansions,
                                         selected: textDocumentProxy.selectedText ?? "") else { return }
        for _ in 0..<edit.deleteCount { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(edit.insert)
        punctuationSpacing.reset()
    }

    @discardableResult
    private func insert(_ value: String) -> String {
        if hasSelection { punctuationSpacing.reset() }
        if !Self.literalTypes.contains(textDocumentProxy.keyboardType ?? .default) {
            capitalizeStandaloneI(before: textDocumentProxy.documentContextBeforeInput ?? "",
                                   incoming: value, inNotes: false)
        }
        let literal = Self.literalTypes.contains(textDocumentProxy.keyboardType ?? .default)
        let preferences = keyboard.preferences
        let edit = punctuationSpacing.edit(for: value, before: textDocumentProxy.documentContextBeforeInput,
                                           enabled: preferences.autoSpacePunctuation && !literal,
                                           doubleSpacePeriod: preferences.doubleSpacePeriod && !literal,
                                           at: ProcessInfo.processInfo.systemUptime,
                                           shortcutStarts: preferences.shownExpansions.shortcutStarts)
        if edit.deleteBackward { textDocumentProxy.deleteBackward() }
        if !edit.text.isEmpty { textDocumentProxy.insertText(edit.text) }
        return edit.text
    }
}

/// The keyboard's own defaults: writable without Full Access, unlike the App Group
/// the app shares settings through.
private enum LanguageMemoryStore {
    private static let key = "language-memory"
    static func load() -> LanguageMemory? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(LanguageMemory.self, from: $0) }
    }
    static func save(_ memory: LanguageMemory) {
        guard let data = try? JSONEncoder().encode(memory) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

/// This UILexicon result is owned by the one-shot completion callback and is
/// handed to MainActor without concurrent access to its UIKit-isolated entries.
private struct KeyScratchLexiconTransfer: @unchecked Sendable {
    let value: UILexicon
}


/// User-picked favorites, most recently used first, stored only on-device.
/// The list in preferences is editable in the containing app.
private enum FavoriteSymbolsHistory {
    private static let key = "key-scratch.recent-symbols.v1"

    private static var defaults: UserDefaults {
        if let group = Bundle.main.object(forInfoDictionaryKey: "OrtholinearAppGroup") as? String,
           let shared = UserDefaults(suiteName: group) { return shared }
        return .standard
    }

    static func display(favorites: [String]) -> [String] {
        var seen = Set<String>()
        return ((defaults.stringArray(forKey: key) ?? []) + favorites)
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .prefix(48).map { $0 }
    }

    static func record(_ symbol: String) {
        let old = defaults.stringArray(forKey: key) ?? []
        defaults.set(Array(([symbol] + old.filter { $0 != symbol }).prefix(8)), forKey: key)
    }
}


import UIKit

/// A local, selectable note inside the keyboard extension.
/// The Ortholinear keys edit this text view directly via its selected range.
/// It intentionally never becomes first responder: that would summon a second keyboard.
@MainActor
final class ScratchpadView: UIView, UITextViewDelegate {
    private let editor = UITextView()
    private let caret = UIView()
    private let modeButton = UIButton(type: .system)
    private let message = UILabel()
    private let storeKey = "key-scratch.local-note.v1"
    private(set) var isEditingNote = false

    var onInsert: ((String) -> Void)?
    var onEditingChange: ((Bool) -> Void)?
    var onTextChange: (() -> Void)?
    var canUseClipboard = false

    var beforeCaret: String { pieces().before }
    var afterCaret: String { pieces().after }
    var selectedNoteText: String { pieces().selection }

    private func safeSelection() -> NSRange {
        let count = (editor.text as NSString).length
        let selected = editor.selectedRange
        guard selected.location != NSNotFound, selected.location <= count,
              selected.length <= count - selected.location else {
            return NSRange(location: count, length: 0)
        }
        return selected
    }

    private func pieces() -> (before: String, after: String, selection: String) {
        let note = editor.text as NSString
        let range = safeSelection()
        let end = range.location + range.length
        return (note.substring(to: range.location),
                note.substring(from: end),
                note.substring(with: range))
    }

    func snapshot(document: UUID, language: KeyboardLanguage) -> SuggestionSnapshot {
        let parts = pieces()
        return SuggestionSnapshot(document: document, before: parts.before, after: parts.after,
                                  selection: parts.selection, language: language)
    }

    func activate() {
        guard !isEditingNote else { return }
        isEditingNote = true
        modeButton.setTitle("App", for: .normal)
        layer.borderColor = UIColor.systemBlue.cgColor
        layer.borderWidth = 1
        onEditingChange?(true)
        updateCaret()
    }

    func deactivate() {
        guard isEditingNote else { return }
        isEditingNote = false
        modeButton.setTitle("Notes", for: .normal)
        layer.borderColor = UIColor.separator.cgColor
        layer.borderWidth = 0.5
        onEditingChange?(false)
        updateCaret()
    }

    /// Replaces the selected UTF-16 range, keeping the selection/caret in the note.
    func type(_ replacement: String) {
        guard isEditingNote else { return }
        let range = safeSelection()
        guard let swiftRange = Range(range, in: editor.text) else { return }
        var value = editor.text ?? ""
        value.replaceSubrange(swiftRange, with: replacement)
        editor.text = value
        editor.selectedRange = NSRange(location: range.location + (replacement as NSString).length, length: 0)
        editor.scrollRangeToVisible(editor.selectedRange)
        updateCaret()
        save()
        onTextChange?()
    }

    /// Used by TextExpander to replace the shortcut immediately before the caret.
    func replaceBeforeCaret(characters: Int, with replacement: String) {
        guard isEditingNote, characters >= 0 else { return }
        let selection = safeSelection()
        guard selection.length == 0, beforeCaret.count >= characters else { return }
        let previous = String(beforeCaret.suffix(characters))
        let utf16Length = (previous as NSString).length
        guard selection.location >= utf16Length else { return }
        editor.selectedRange = NSRange(location: selection.location - utf16Length,
                                       length: utf16Length)
        type(replacement)
    }

    func deleteBackward() {
        guard isEditingNote else { return }
        let selection = safeSelection()
        if selection.length > 0 {
            type("")
        } else if selection.location > 0 {
            let previous = (editor.text as NSString).rangeOfComposedCharacterSequence(at: selection.location - 1)
            editor.selectedRange = previous
            type("")
        }
    }

    func moveCaret(steps: Int) {
        guard isEditingNote, steps != 0,
              let start = editor.selectedTextRange?.start,
              let next = editor.position(from: start, offset: steps),
              let range = editor.textRange(from: next, to: next) else { return }
        editor.selectedTextRange = range
        updateCaret()
        onTextChange?()
    }

    /// Safely applies an Ortholinear suggestion against the exact note it was offered for.
    func apply(_ edit: SuggestionEdit, offered: SuggestionSnapshot, document: UUID,
               language: KeyboardLanguage) -> Bool {
        guard isEditingNote, snapshot(document: document, language: language) == offered else { return false }
        let selected = safeSelection()
        let left = (edit.left as NSString).length
        let right = (edit.right as NSString).length
        let total = (editor.text as NSString).length
        guard selected.location >= left,
              selected.location + selected.length + right <= total else { return false }
        editor.selectedRange = NSRange(location: selected.location - left,
                                      length: left + selected.length + right)
        type(edit.text)
        return true
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemBackground
        layer.borderColor = UIColor.separator.cgColor
        layer.borderWidth = 0.5

        let toolbar = UIStackView()
        toolbar.axis = .vertical
        toolbar.spacing = 1

        let top = UIStackView()
        top.axis = .horizontal
        top.distribution = .fillEqually
        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.distribution = .fillEqually
        toolbar.addArrangedSubview(top)
        toolbar.addArrangedSubview(bottom)

        modeButton.setTitle("Notes", for: .normal)
        modeButton.titleLabel?.font = .systemFont(ofSize: 10, weight: .semibold)
        modeButton.addTarget(self, action: #selector(toggleDestination), for: .touchUpInside)
        top.addArrangedSubview(modeButton)

        func add(_ title: String, action: Selector, to row: UIStackView) {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 9, weight: .semibold)
            button.addTarget(self, action: action, for: .touchUpInside)
            row.addArrangedSubview(button)
        }

        add("Insert", action: #selector(insertNote), to: top)
        add("Paste", action: #selector(pasteClipboard), to: bottom)
        add("Copy", action: #selector(copyNote), to: bottom)

        let erase = UIButton(type: .system)
        erase.setTitle("Hold Clear", for: .normal)
        erase.titleLabel?.font = .systemFont(ofSize: 9)
        erase.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(clearNoteOnHold(_:))))
        bottom.addArrangedSubview(erase)

        editor.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        editor.backgroundColor = .clear
        editor.isEditable = false
        editor.isSelectable = true
        editor.isScrollEnabled = true
        editor.delegate = self
        caret.backgroundColor = .systemBlue
        caret.isHidden = true
        caret.isUserInteractionEnabled = false
        editor.addSubview(caret)
        editor.textContainerInset = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        editor.text = UserDefaults.standard.string(forKey: storeKey) ?? ""
        editor.accessibilityLabel = "Scratchpad note. Tap to type with Key Scratch."
        let tap = UITapGestureRecognizer(target: self, action: #selector(noteTapped(_:)))
        tap.cancelsTouchesInView = false
        editor.addGestureRecognizer(tap)

        message.font = .systemFont(ofSize: 9)
        message.textColor = .secondaryLabel
        message.numberOfLines = 2
        message.isHidden = true

        let stack = UIStackView(arrangedSubviews: [toolbar, message, editor])
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func noteTapped(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        activate()
        let location = gesture.location(in: editor)
        if let position = editor.closestPosition(to: location) {
            editor.selectedTextRange = editor.textRange(from: position, to: position)
        }
        updateCaret()
        onTextChange?()
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        updateCaret()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCaret()
    }

    private func updateCaret() {
        guard isEditingNote, let selection = editor.selectedTextRange,
              selection.isEmpty else {
            caret.isHidden = true
            return
        }
        let rect = editor.caretRect(for: selection.start)
        guard rect.isFinite, rect.height > 0 else {
            caret.isHidden = true
            return
        }
        caret.frame = CGRect(x: rect.minX, y: rect.minY, width: 1.5, height: max(rect.height, 12))
        caret.isHidden = false
    }

    @objc private func toggleDestination() {
        if isEditingNote { deactivate() } else { activate() }
    }

    private func inform(_ text: String) {
        message.text = text
        message.isHidden = false
    }

    @objc private func pasteClipboard() {
        activate()
        guard canUseClipboard else {
            inform("Paste: enable Allow Full Access in iPhone keyboard settings")
            return
        }
        guard let value = UIPasteboard.general.string, !value.isEmpty else {
            inform("Clipboard has no text")
            return
        }
        message.isHidden = true
        type(value)
    }

    @objc private func copyNote() {
        guard canUseClipboard else {
            inform("Copy: enable Allow Full Access in iPhone keyboard settings")
            return
        }
        let value = selectedNoteText.isEmpty ? editor.text ?? "" : selectedNoteText
        guard !value.isEmpty else { return }
        UIPasteboard.general.string = value
        inform("Copied")
    }

    @objc private func insertNote() {
        let value = selectedNoteText.isEmpty ? editor.text ?? "" : selectedNoteText
        guard !value.isEmpty else { return }
        deactivate()
        onInsert?(value)
    }

    @objc private func clearNoteOnHold(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        editor.text = ""
        editor.selectedRange = NSRange(location: 0, length: 0)
        save()
        onTextChange?()
        inform("Note cleared")
    }

    private func save() {
        UserDefaults.standard.set(editor.text, forKey: storeKey)
    }
}

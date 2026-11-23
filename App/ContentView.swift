import SwiftUI
import PhotosUI
import ImageIO

private let accent = Color(red: 0.70, green: 0.29, blue: 0.20)

/// A notebook-inspired identity for the containing app, deliberately separate
/// from the system keyboard's themes and touch geometry.
enum CompanionStyle {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.085, green: 0.092, blue: 0.105, alpha: 1)
            : UIColor(red: 0.977, green: 0.968, blue: 0.947, alpha: 1)
    })
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.16, blue: 0.175, alpha: 1)
            : UIColor(red: 1.0, green: 0.997, blue: 0.986, alpha: 1)
    })
    static let ink = Color.primary
    static let muted = Color.secondary
    static let line = Color.primary.opacity(0.12)
    static let accent = Color(red: 0.70, green: 0.29, blue: 0.20)
    static let radius: CGFloat = 16
}

private enum CompanionPage: Hashable {
    case notes, characters, keyboard
}

/// The companion's purpose is to use and maintain the notes and character shelf.
/// Keyboard setup is a separate workspace, not a marketing home screen.
struct ContentView: View {
    @State private var preferences = PreferenceStore.load()
    @State private var page: CompanionPage =
        ProcessInfo.processInfo.arguments.contains("-keyboard-workspace-ui-test") ? .keyboard : .notes
    @State private var showGeometry = false
    @State private var showSetup = false
    @State private var showSystemTest = false
    @State private var showScratchpadSettings = false
    @State private var saveError: String?
    @State private var triedGestures: Set<KeyboardGesture> = []
    @State private var showGestureGuide = false

    var body: some View {
        TabView(selection: $page) {
            KeyScratchFullNotes(embedded: true)
                .tag(CompanionPage.notes)
                .tabItem { Label("Notes", systemImage: "note.text") }

            FavoriteSymbolPicker(favorites: $preferences.favoriteSymbols, embedded: true)
                .tag(CompanionPage.characters)
                .tabItem { Label("Characters", systemImage: "character.book.closed") }

            keyboardWorkspace
                .tag(CompanionPage.keyboard)
                .tabItem { Label("Keyboard", systemImage: "keyboard") }
        }
        .tint(CompanionStyle.accent)
        .sheet(isPresented: $showGeometry) { GeometrySettings(preferences: $preferences) }
        .sheet(isPresented: $showSetup) { SetupView() }
        .sheet(isPresented: $showSystemTest) { SystemKeyboardTest() }
        .sheet(isPresented: $showScratchpadSettings) { ScratchpadPreferences(preferences: $preferences) }
        .onChange(of: preferences) { _, updated in
            do { try KeyboardPublisher.publish(updated) }
            catch {
                saveError = "The keyboard could not receive the new settings. Check App Group signing."
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ProHooks.accessChanged)) { _ in
            try? KeyboardPublisher.publish(preferences)
        }
        .alert("Settings weren’t saved", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    private var keyboardWorkspace: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 12) {
                        Image("KeyScratchIcon")
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("KEY SCRATCH")
                                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                .tracking(2.0)
                            Text("Keyboard studio")
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                        }
                        Spacer()
                        Button { showGeometry = true } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18, weight: .medium))
                                .frame(width: 46, height: 46)
                                .foregroundStyle(CompanionStyle.accent)
                                .background(CompanionStyle.card, in: RoundedRectangle(cornerRadius: 13))
                        }
                        .accessibilityLabel("Keyboard settings")
                        .accessibilityIdentifier("customize-keyboard")
                    }
                    .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Test drive")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                            Spacer()
                            Button("Clear") {
                                NotificationCenter.default.post(name: .clearKeyboardPreview, object: nil)
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .accessibilityIdentifier("clear-preview")
                        }
                        Text("Use the keys below. This is a separate test field, not a scratchpad page.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        PreviewSurface(
                            preferences: KeyboardPublisher.published(preferences),
                            isActive: !showGeometry && !showSetup && !showSystemTest && !showScratchpadSettings
                                && page == .keyboard
                        ) { gesture in
                            triedGestures.insert(gesture)
                        }
                        .frame(height: 100 + preferences.keyboardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .overlay {
                            RoundedRectangle(cornerRadius: 11)
                                .strokeBorder(CompanionStyle.line)
                        }
                        .accessibilityIdentifier("interactive-keyboard-workbench")
                    }
                    .padding(14)
                    .background(CompanionStyle.card,
                                in: RoundedRectangle(cornerRadius: CompanionStyle.radius))

                    HStack(spacing: 10) {
                        workspaceAction(title: "Keyboard settings", subtitle: "Keys, languages, typing",
                                        icon: "slider.horizontal.3", id: "adjust-geometry") {
                            showGeometry = true
                        }
                        workspaceAction(title: "Scratchpad options", subtitle: "Width, type, Surround",
                                        icon: "rectangle.split.2x1", id: "key-scratch-layout-settings") {
                            showScratchpadSettings = true
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            showSetup = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.shield")
                                    .font(.system(size: 21))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Enable Key Scratch")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Add the keyboard to your iPhone")
                                        .font(.system(size: 12)).opacity(0.88)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .padding(.horizontal, 17).frame(minHeight: 60)
                            .foregroundStyle(.white)
                            .background(CompanionStyle.accent,
                                        in: RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityIdentifier("enable-keyboard")
                        Button { showSystemTest = true } label: {
                            Label("Test the installed keyboard in a real text field",
                                  systemImage: "rectangle.and.pencil.and.ellipsis")
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 7)
                        }
                        .accessibilityIdentifier("system-test")
                    }

                    DisclosureGroup(isExpanded: $showGestureGuide) {
                        GestureReference(preferences: preferences, tried: triedGestures)
                            .padding(.top, 12)
                    } label: {
                        Label("Typing gestures", systemImage: "hand.draw")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .accessibilityIdentifier("gesture-reference")
                    .padding(15)
                    .background(CompanionStyle.card,
                                in: RoundedRectangle(cornerRadius: CompanionStyle.radius))

                    HStack {
                        Label("On-device by design", systemImage: "lock")
                        Spacer()
                        Text(languageSummary).lineLimit(1)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        Link("Privacy", destination: URL(string:
                            "https://github.com/udeudeude/Key-Scratch/blob/feature/scratchpad-first-pass/PRIVACY.md")!)
                        Link("Source & feedback", destination: URL(string:
                            "https://github.com/udeudeude/Key-Scratch/issues")!)
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(maxWidth: 690)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(CompanionStyle.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func workspaceAction(title: String, subtitle: String, icon: String,
                                 id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .frame(width: 27)
                    .foregroundStyle(CompanionStyle.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 65, alignment: .leading)
            .padding(13)
            .background(CompanionStyle.card,
                        in: RoundedRectangle(cornerRadius: CompanionStyle.radius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var languageSummary: String {
        preferences.validated.languages.prefix(3).map(\.badge).joined(separator: " · ")
    }
}

private struct GestureReference: View {
    let preferences: KeyboardPreferences
    let tried: Set<KeyboardGesture>
    private var gestures: [(KeyboardGesture, String)] {
        var result: [(KeyboardGesture, String)] = [
            (.alternative, "Hold a key and slide to its alternate character"),
            (.symbolSlide, "Hold 123 and slide to a symbol"),
            (.spaceCursor, "Slide on Space to move the caret")
        ]
        if preferences.digitAccess == .flick {
            result.append((.flick, "Flick a top-row key down for its digit"))
        }
        if preferences.glideTyping {
            result.append((.glide, "Trace a word across the letter keys"))
        }
        return result
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(gestures, id: \.0) { gesture, description in
                Label(description, systemImage: tried.contains(gesture) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(tried.contains(gesture) ? CompanionStyle.accent : .secondary)
                    .accessibilityIdentifier("try-\(gesture.rawValue)")
            }
            Text("Double-tap Shift for capitals lock; double-tap Space for a period.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

struct GeometrySettings: View {
    @State private var preferences: KeyboardPreferences
    private let commit: (KeyboardPreferences) -> Void
    @State private var saveError = false

    init(preferences: Binding<KeyboardPreferences>) {
        _preferences = State(initialValue: preferences.wrappedValue)
        _previewLanguage = State(initialValue: preferences.wrappedValue.validated.defaultLanguage)
        commit = { preferences.wrappedValue = $0 }
    }
    @Environment(\.dismiss) private var dismiss

    @State private var previewLanguage: KeyboardLanguage
    @State private var showAppearance = false
    @State private var showResetConfirmation = false
    @State private var showAdvanced =
        ProcessInfo.processInfo.arguments.contains("-keyboard-workspace-ui-test")
    private enum SettingsPage: Hashable { case suggestions, languages, workshop }
    @State private var navigationPath: [SettingsPage] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    HStack(spacing: 0) {
                        controls.frame(maxWidth: .infinity)
                        livePreview(maxHeight: geometry.size.height - 60)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    VStack(spacing: 0) {
                        controls
                        // Leaves room for several settings rows while the keys stay readable.
                        livePreview(maxHeight: geometry.size.height * 0.36)
                    }
                }
            }
            .background(CompanionStyle.background)
            .navigationTitle("Keyboard settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .navigationDestination(for: SettingsPage.self) { page in
                switch page {
                case .suggestions: SuggestionSettings(preferences: $preferences)
                case .languages: LanguageSettings(preferences: $preferences)
                case .workshop: LayoutWorkshop(preferences: $preferences)
                }
            }
            .sheet(isPresented: $showAppearance) { AppearanceSettings(preferences: $preferences) }
        }
        .tint(CompanionStyle.accent)
        .onChange(of: preferences) { _, value in
            do { try KeyboardPublisher.publish(value) }
            catch { saveError = true }
            if !value.validated.languages.contains(previewLanguage) { previewLanguage = value.validated.defaultLanguage }
        }
        .onDisappear { commit(preferences) }
        .alert("Settings weren’t saved", isPresented: $saveError) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please reopen settings and try again.") }
        .confirmationDialog("Restore keyboard defaults?", isPresented: $showResetConfirmation,
                            titleVisibility: .visible) {
            Button("Restore keyboard settings", role: .destructive) {
                restoreKeyboardDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Keyboard layout and typing options return to defaults. Your notes, favorite characters, custom Surround pairs and text expansions are preserved.")
        }
    }

    private func livePreview(maxHeight: CGFloat) -> some View {
        VStack(spacing: 10) {
            HStack {
                // Several language segments need the room the title would take.
                if (4...5).contains(preferences.validated.languages.count) {
                    Image(systemName: "keyboard").font(.subheadline.weight(.semibold))
                        .accessibilityLabel("Live preview")
                } else {
                    Label("Live preview", systemImage: "keyboard")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                Button { showAppearance = true } label: {
                    Image(systemName: "paintpalette").frame(width: 34, height: 34)
                }
                .accessibilityLabel("Choose keyboard theme")
                .accessibilityIdentifier("choose-theme")
                // Segments fit up to five languages; beyond that, a menu.
                if preferences.validated.languages.count > 5 {
                    Picker("Preview language", selection: $previewLanguage) {
                        ForEach(preferences.validated.languages, id: \.self) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("preview-language")
                } else {
                    Picker("Preview language", selection: $previewLanguage) {
                        ForEach(preferences.validated.languages, id: \.self) { Text($0.badge).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(width: max(112, CGFloat(preferences.validated.languages.count) * 48))
                    .accessibilityIdentifier("preview-language")
                }
            }.padding(.horizontal, 16)
            SettingsKeyboardPreview(preferences: KeyboardPublisher.published(preferences), language: previewLanguage)
                .frame(height: maxHeight)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 8)
        }
        .padding(.top, 12).padding(.bottom, 8)
        .background(CompanionStyle.card)
        // Not Divider: beside the form in landscape it would turn vertical, through the preview.
        .overlay(alignment: .top) { Rectangle().fill(Color(uiColor: .separator)).frame(height: 0.5) }
    }

    private var controls: some View {
        Form {
            Section("Languages & layouts") {
                NavigationLink(value: SettingsPage.languages) {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Languages and layouts")
                            Text(languageSummary).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "globe") }
                }.accessibilityIdentifier("language-settings")
                NavigationLink(value: SettingsPage.workshop) {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Layout Workshop")
                            Text(workshopSummary).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "square.grid.3x3.square") }
                }.accessibilityIdentifier("layout-workshop")
            }
            if let proRows = ProHooks.settingsRows {
                Section("Additional features") { proRows($preferences) }
            }
            Section("Look & feel") {
                Button { showAppearance = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "paintpalette.fill").font(.title3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Appearance").font(.body.weight(.medium))
                            Text(preferences.appleKeyAppearance ? "iPhone-style · automatic light/dark" : "\(preferences.theme.title) · \(preferences.accent.title)").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }.padding(.vertical, 4)
                }
                .accessibilityIdentifier("theme-settings")
            }
            Section("Words & corrections") {
                NavigationLink(value: SettingsPage.suggestions) {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Words and corrections")
                            Text(preferences.suggestionsEnabled ? "On-device · changes only when tapped" : "Suggestions are off")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "text.bubble") }
                }.accessibilityIdentifier("suggestion-settings")
            }
            Section {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { showAdvanced.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.3x3.topleft.filled")
                            .font(.system(size: 18)).foregroundStyle(CompanionStyle.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Advanced key controls")
                                .foregroundStyle(.primary).font(.body.weight(.semibold))
                            Text("Presets, spacing, key placement and number access")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("advanced-key-controls")
            }
            if showAdvanced {
            Section {
                HStack(spacing: 6) {
                    ForEach(KeyboardPreset.allCases) { preset in
                        Button(preset.title) { preferences.apply(preset) }
                            .font(.system(size: 12, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("preset-\(preset.rawValue)")
                    }
                }
                Text(activePreset?.detail ?? "Your custom geometry")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Label("Starting points", systemImage: "square.grid.3x3") }
            Section {
                slider("Key height", value: $preferences.keyHeight, range: 36...88)
                slider("Control row height", value: $preferences.controlHeight, range: 36...72)
                slider("Letter size", value: $preferences.letterSize, range: 18...36)
                VStack(alignment: .leading) {
                    HStack {
                        Text("Return and Delete width")
                        Spacer()
                        Text(preferences.actionKeyWidth, format: .number.precision(.fractionLength(1)))
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $preferences.actionKeyWidth, in: 1.25...3.5, step: 0.05)
                        .accessibilityLabel("Return and Delete width")
                }
            } header: { Label("Dimensions", systemImage: "textformat.size") } footer: {
                Text("Size letters and controls separately. The preview updates as you drag.")
            }
            Section {
                slider("Column spacing", value: $preferences.columnSpacing, range: 0...8)
                slider("Row spacing", value: $preferences.rowSpacing, range: 0...12)
                Toggle("Fill gaps between keys", isOn: $preferences.fillGaps)
                    .accessibilityIdentifier("fill-gaps")
            } header: { Label("Spacing", systemImage: "arrow.left.and.right") } footer: {
                Text("Fill gaps keeps the visual spacing while extending touch targets to meet. Turn it off to make only the visible keys respond.")
            }
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Shift position")
                    Picker("Shift position", selection: $preferences.shiftPlacement) {
                        ForEach(ShiftPlacement.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Toggle("Show header strip", isOn: $preferences.showHeader)
                    .accessibilityIdentifier("show-header")
                Toggle("iPhone key positions", isOn: $preferences.iphoneKeyPositions)
                    .accessibilityIdentifier("iphone-key-positions")
            } header: { Label("Key positions & controls", systemImage: "rectangle.bottomthird.inset.filled") } footer: {
                Text("Hide the header to leave more room for letters.")
            }
            Section {
                Toggle("Dot, comma and question mark", isOn: $preferences.showPunctuation)
                    .accessibilityIdentifier("show-punctuation")
                Toggle("English apostrophe", isOn: $preferences.showApostrophe)
                    .disabled(preferences.iphoneKeyPositions)
                    .accessibilityIdentifier("show-apostrophe")
                if preferences.validated.languages.contains(.ukrainian) {
                    Toggle("ї on long-press і", isOn: $preferences.yiOnLongPress)
                        .accessibilityIdentifier("yi-on-long-press")
                }
            } header: { Label("Optional characters", systemImage: "character.cursor.ibeam") } footer: {
                Text("Punctuation remains available under 123." +
                     (preferences.validated.languages.contains(.ukrainian)
                         ? " Ukrainian: the ї option puts it on long-press і."
                         : "") +
                     (preferences.customLayouts.isEmpty ? "" : " Your custom layouts retain the keys you assigned."))
            }
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Digits on the letter page")
                    Picker("Digits on the letter page", selection: $preferences.digitAccess) {
                        ForEach(DigitAccess.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented)
                }
                .accessibilityIdentifier("digit-access")
            } header: { Label("Number access", systemImage: "number") } footer: {
                Text(digitFooter)
            }
            }
            Section {
                Toggle("Capitalize sentences", isOn: $preferences.autoCapitalize)
                    .accessibilityIdentifier("auto-capitalize")
                Toggle("Double-space for period", isOn: $preferences.doubleSpacePeriod)
                    .accessibilityIdentifier("double-space-period")
                Toggle("Space after punctuation", isOn: $preferences.autoSpacePunctuation)
                    .accessibilityIdentifier("auto-space-punctuation")
                Toggle("Glide typing", isOn: $preferences.glideTyping)
                    .accessibilityIdentifier("glide-typing")
            } header: { Label("Typing", systemImage: "keyboard") } footer: {
                Text("Capitals follow each text field, so email and web addresses stay lowercase. Automatic spacing adds a space after punctuation; apostrophes and numbers such as 3.14 stay together. For swipe typing, slide across a word and lift; suggestions appear above the keys. Hold Delete to gradually delete faster.")
            }
            Section {
                Button("Restore keyboard defaults…", role: .destructive) {
                    showResetConfirmation = true
                }
                .accessibilityIdentifier("restore-keyboard-defaults")
            } footer: {
                Text("Changes save automatically. Switch to another keyboard and back to apply them in other apps.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(CompanionStyle.background)
        .accessibilityIdentifier("geometry-controls")
    }

    private func restoreKeyboardDefaults() {
        var restored = KeyboardPreferences()
        restored.favoriteSymbols = preferences.favoriteSymbols
        restored.customWrappers = preferences.customWrappers
        restored.expansions = preferences.expansions
        restored.keyScratchNoteWidth = preferences.keyScratchNoteWidth
        restored.keyScratchNoteFontSize = preferences.keyScratchNoteFontSize
        restored.keyScratchNoteFont = preferences.keyScratchNoteFont
        restored.scratchpadVisualStyle = preferences.scratchpadVisualStyle
        restored.leftHandedLayout = preferences.leftHandedLayout
        preferences = restored.validated
    }

    private var digitFooter: String {
        switch preferences.digitAccess {
        case .flick: "Flick a top-row key down to type the small digit in its corner. No extra height."
        case .numberRow: "A row of digits above the letters. It adds about \(Int(preferences.numberRowHeight)) pt to the keyboard."
        case .off: "Digits stay under 123."
        }
    }

    private var activePreset: KeyboardPreset? {
        KeyboardPreset.allCases.first { preset in
            // Presets only change geometry, so applying the active one is a no-op.
            var candidate = preferences
            candidate.apply(preset)
            return candidate == preferences
        }
    }

    private var workshopSummary: String {
        let custom = preferences.validated.languages.filter { preferences.customLayouts[$0] != nil }
        return custom.isEmpty ? "Move letters and choose what each key holds"
            : "Your layout: " + custom.map(\.badge).joined(separator: " · ")
    }

    private var languageSummary: String {
        preferences.validated.languages.map { language in
            language == .english && preferences.englishLayout != .qwerty ? "EN \(preferences.englishLayout.title)" : language.badge
        }.joined(separator: " · ")
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(title); Spacer(); Text("\(Int(value.wrappedValue)) pt")
                    .font(.subheadline.monospacedDigit().weight(.medium))
                    .foregroundStyle(accent)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(accent.opacity(0.08), in: Capsule()) }
            Slider(value: value, in: range, step: 1).accessibilityLabel(title)
        }.padding(.vertical, 4)
    }
}

struct SetupView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 11) {
                        Text("GET STARTED")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.4).foregroundStyle(CompanionStyle.accent)
                        Text("A few taps.\nThen it's yours.")
                            .font(.system(size: 32, weight: .semibold, design: .serif))
                            .tracking(-1.2)
                        Text("Key Scratch works in almost any app that accepts a third-party keyboard. Setup happens once in iPhone Settings.")
                            .font(.system(size: 14)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(spacing: 0) {
                        step(1, title: "Open Keyboard settings",
                             detail: "Settings → General → Keyboard")
                        Divider().padding(.leading, 57)
                        step(2, title: "Add a keyboard",
                             detail: "Keyboards → Add New Keyboard")
                        Divider().padding(.leading, 57)
                        step(3, title: "Select Key Scratch",
                             detail: "It appears under third-party keyboards.")
                        Divider().padding(.leading, 57)
                        step(4, title: "Start typing",
                             detail: "In any text field, hold the globe and choose Key Scratch.")
                    }
                    .background(CompanionStyle.card,
                                in: RoundedRectangle(cornerRadius: CompanionStyle.radius))
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Label("Open Settings", systemImage: "gearshape")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 18).frame(height: 54)
                        .foregroundStyle(.white)
                        .background(CompanionStyle.accent,
                                    in: RoundedRectangle(cornerRadius: 15))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Optional: Allow Full Access", systemImage: "lock.shield")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Enable this in Key Scratch's keyboard settings for clipboard features and sharing local scratchpad pages with the companion app. Typing itself does not require it.")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                        Text("Password and phone-number fields use Apple's system keyboard. No account or internet connection is required.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .background(CompanionStyle.card,
                                in: RoundedRectangle(cornerRadius: CompanionStyle.radius))
                }
                .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
            .background(CompanionStyle.background.ignoresSafeArea())
            .navigationTitle("Set up Key Scratch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(CompanionStyle.accent)
    }

    private func step(_ index: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(String(format: "%02d", index))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(CompanionStyle.accent)
                .frame(width: 29, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 1)
        }
        .padding(17)
    }
}

struct SystemKeyboardTest: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var email = ""
    @State private var fields = [String](repeating: "", count: 6)
    @FocusState private var focused: Int?
    var body: some View {
        NavigationStack {
            Form {
                // Kinds of fields that change the keyboard's page and behavior under it. Only on
                // request: they would push the email field under the keyboard for other tests.
                if ProcessInfo.processInfo.arguments.contains("-field-types") {
                    Section("Field types") {
                        HStack {
                            field(0, "Next ⏎", .default).submitLabel(.next).onSubmit { focused = 1 }
                            field(1, "Number", .numberPad)
                            field(2, "Decimal", .decimalPad)
                        }
                        // No secure field: iOS would take the URL field for a login's username
                        // and give both its own keyboard.
                        HStack {
                            field(3, "Phone", .phonePad)
                            field(4, "URL", .URL)
                            field(5, "Numbers & punctuation", .numbersAndPunctuation)
                        }
                    }
                }
                Section("Use the globe to choose Key Scratch") {
                    TextEditor(text: $text).frame(minHeight: 150).accessibilityIdentifier("system-editor")
                }
                Section("Email input") {
                    TextField("name@example.com", text: $email).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).accessibilityIdentifier("email-editor")
                }
            }
            .navigationTitle("System keyboard test").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func field(_ index: Int, _ title: String, _ type: UIKeyboardType) -> some View {
        TextField(title, text: $fields[index]).keyboardType(type).textInputAutocapitalization(.never)
            .autocorrectionDisabled().focused($focused, equals: index).accessibilityIdentifier("field-\(index)")
    }
}


/// Companion-only preferences for the notebook beside the keyboard.
/// Changes publish immediately, through ContentView, without a second Apply step.
private struct ScratchpadPreferences: View {
    @Binding var preferences: KeyboardPreferences
    @Environment(\.dismiss) private var dismiss
    @State private var pairName = ""
    @State private var opening = ""
    @State private var closing = ""

    private var prospectivePair: SelectionWrapper {
        SelectionWrapper(pairName.trimmingCharacters(in: .whitespacesAndNewlines), opening, closing)
    }
    private var canAddPair: Bool {
        let pair = prospectivePair
        return pair.isUsable && preferences.customWrappers.count < 12
            && !preferences.customWrappers.contains {
                $0.opening == pair.opening && $0.closing == pair.closing
            }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Portrait notes width")
                            Spacer()
                            Text("\(Int(preferences.keyScratchNoteWidth * 100))%")
                                .monospacedDigit().foregroundStyle(.secondary)
                        }
                        Slider(value: $preferences.keyScratchNoteWidth, in: 0.18...0.42, step: 0.02)
                            .accessibilityLabel("Portrait notes width")
                    }
                    Toggle("Put keyboard on the left", isOn: $preferences.leftHandedLayout)
                        .accessibilityIdentifier("left-handed-keyboard-layout")
                } header: {
                    Label("Placement", systemImage: "rectangle.split.2x1")
                } footer: {
                    Text("In landscape, the notes use the available space beside a compact keyboard. In portrait, adjust their share here.")
                }

                Section {
                    HStack {
                        Text("Text size")
                        Spacer()
                        Text("\(Int(preferences.keyScratchNoteFontSize)) pt")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $preferences.keyScratchNoteFontSize, in: 9...16, step: 1)
                        .accessibilityLabel("Scratchpad text size")
                    Picker("Typeface", selection: $preferences.keyScratchNoteFont) {
                        ForEach(KeyScratchNoteFont.allCases) { font in
                            Text(font.title).tag(font)
                        }
                    }
                    Picker("Note surface", selection: $preferences.scratchpadVisualStyle) {
                        ForEach(ScratchpadVisualStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .accessibilityIdentifier("scratchpad-visual-style")
                    Text("A quick note, a useful address, or a line of symbols.")
                        .font(.system(size: CGFloat(preferences.keyScratchNoteFontSize) + 2,
                                      design: .monospaced))
                        .foregroundStyle(preferences.scratchpadVisualStyle == .standard
                                         ? Color.primary : CompanionStyle.accent)
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .background(CompanionStyle.card,
                                    in: RoundedRectangle(cornerRadius: 10))
                } header: {
                    Label("Note appearance", systemImage: "textformat")
                } footer: {
                    Text("These choices change the small scratchpad inside the keyboard, not the full-size editor here.")
                }

                Section {
                    HStack {
                        Text("Custom pairs")
                        Spacer()
                        Text("\(preferences.customWrappers.count)/12")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    ForEach(preferences.customWrappers.indices, id: \.self) { index in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(preferences.customWrappers[index].name)
                                    .font(.body.weight(.medium))
                                Text(preferences.customWrappers[index].opening + " text "
                                     + preferences.customWrappers[index].closing)
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                preferences.customWrappers.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .accessibilityLabel("Remove " + preferences.customWrappers[index].name)
                        }
                    }
                    TextField("Name, for example Spoiler", text: $pairName)
                        .textInputAutocapitalization(.words)
                    HStack(spacing: 12) {
                        TextField("Before", text: $opening)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        TextField("After", text: $closing)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    Button {
                        guard canAddPair else { return }
                        preferences.customWrappers.append(prospectivePair)
                        pairName = ""
                        opening = ""
                        closing = ""
                    } label: {
                        Label("Add Surround pair", systemImage: "plus.circle.fill")
                    }
                    .disabled(!canAddPair)
                    .accessibilityIdentifier("add-surround-pair")
                } header: {
                    Label("Surround text", systemImage: "curlybraces")
                } footer: {
                    Text("The keyboard's ⋯ menu has quotes, brackets and Markdown marks. Add personal opening and closing text here. Tap a pair in Surround selection to enclose selected text.")
                }

                Section {
                    Label("Pages and pictures live in Notes.", systemImage: "note.text")
                    Text("Copy and Paste in the keyboard require its optional Full Access permission. You do not need it to type.")
                        .foregroundStyle(.secondary)
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    } label: {
                        Label("Open iPhone Settings", systemImage: "gearshape")
                    }
                } header: {
                    Text("Device access")
                }
            }
            .scrollContentBackground(.hidden)
            .background(CompanionStyle.background)
            .navigationTitle("Scratchpad options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(CompanionStyle.accent)
    }
}

/// Full-size companion editor of the *same pages* as the keyboard extension.
/// App Group storage is the source of truth. Text changes save only the
/// selected page, preserving any edits to the other pages.
private struct KeyScratchFullNotes: View {
    var embedded = false
    init(embedded: Bool = false) { self.embedded = embedded }
    @Environment(\.dismiss) private var dismiss
    @State private var notebook = ScratchpadNotebook.initial(legacy: "")
    @State private var note = ""
    @State private var loaded = false
    @State private var showClearConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var pickedPhotos: [PhotosPickerItem] = []
    @State private var photoPreview: ScratchpadImage?
    @State private var photoPendingRemoval: ScratchpadImage?
    @State private var imageRemovalPageID: String?
    @State private var showImageRemovalConfirmation = false
    @State private var importingPhotos = false
    @State private var notice: String?
    @State private var showNotesSetup = false
    @State private var showCreateNotebook = false
    @FocusState private var focused: Bool

    private var editableNote: Binding<String> {
        Binding(get: { note }, set: { next in
            note = next
            guard loaded else { return }
            if notebook.pages.indices.contains(notebook.selectedIndex) {
                notebook.pages[notebook.selectedIndex].text = next
            }
            notice = ScratchpadStore.savePage(id: notebook.selectedID, text: next)
                ? nil : "Shared note storage unavailable. Check App Group signing."
        })
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("KEY SCRATCH / NOTES")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.6).foregroundStyle(CompanionStyle.accent)
                        Text("Scratchpad")
                            .font(.system(size: 27, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                    Label(loaded ? "Stored on this iPhone" : "Waiting for first use",
                          systemImage: loaded ? "checkmark.circle" : "clock")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 7) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(notebook.pages.indices, id: \.self) { index in
                                let page = notebook.pages[index]
                                Button("Page \(index + 1)") { switchPage(to: page.id) }
                                    .disabled(importingPhotos)
                                    .font(.system(size: 13, weight: notebook.selectedID == page.id ? .semibold : .regular))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(notebook.selectedID == page.id
                                        ? CompanionStyle.accent.opacity(0.15) : CompanionStyle.card,
                                        in: RoundedRectangle(cornerRadius: 11))
                                    .accessibilityIdentifier("full-scratchpad-page-\(index + 1)")
                            }
                        }
                    }
                    Button { addPage() } label: { Image(systemName: "plus.circle.fill") }
                        .disabled(!loaded || importingPhotos || notebook.pages.count >= ScratchpadNotebook.maximumPages)
                        .accessibilityLabel("Add scratchpad page")
                }
                .buttonStyle(.plain)

                HStack(alignment: .center) {
                    PhotosPicker(selection: $pickedPhotos, maxSelectionCount: 8, matching: .images) {
                        Label("Add images", systemImage: "photo.on.rectangle.angled")
                    }
                    .disabled(!loaded || importingPhotos ||
                              notebook.selectedPage.images.count >= ScratchpadNotebook.maximumImagesPerPage)
                    .accessibilityIdentifier("add-scratchpad-images")
                    Button {
                        pasteClipboardImage()
                    } label: {
                        Label("Paste image", systemImage: "doc.on.clipboard")
                    }
                    .disabled(!loaded || importingPhotos ||
                              notebook.selectedPage.images.count >= ScratchpadNotebook.maximumImagesPerPage)
                    .accessibilityIdentifier("paste-image-in-companion-scratchpad")
                    Spacer()
                    if importingPhotos {
                        ProgressView()
                            .controlSize(.small)
                        Text("Importing…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(notebook.selectedPage.images.count)/\(ScratchpadNotebook.maximumImagesPerPage) images")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.bordered)

                if !notebook.selectedPage.images.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .center, spacing: 10) {
                            ForEach(notebook.selectedPage.images) { photo in
                                Button {
                                    photoPreview = photo
                                } label: {
                                    Group {
                                        if let url = ScratchpadImageStore.imageURL(
                                            id: photo.id, thumbnail: true),
                                           let image = UIImage(contentsOfFile: url.path) {
                                            Image(uiImage: image).resizable().scaledToFill()
                                        } else {
                                            Image(systemName: "photo").resizable().scaledToFit()
                                                .padding(14)
                                        }
                                    }
                                    .frame(width: 69, height: 69)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Preview scratchpad image")
                                .contextMenu {
                                    Button("Preview image", systemImage: "eye") {
                                        photoPreview = photo
                                    }
                                    Button("Copy image", systemImage: "doc.on.doc") {
                                        copyImage(photo)
                                    }
                                    Button("Remove from page", systemImage: "trash", role: .destructive) {
                                        confirmImageRemoval(photo)
                                    }
                                }
                            }
                        }
                    }
                    Text("Tap an image to preview it. Hold for Copy and Remove from page.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if loaded {
                    TextEditor(text: editableNote)
                        .focused($focused)
                        .font(.system(size: 17))
                        .scrollContentBackground(.hidden)
                        .padding(12)
                        .background(CompanionStyle.card,
                                    in: RoundedRectangle(cornerRadius: CompanionStyle.radius))
                        .overlay(RoundedRectangle(cornerRadius: CompanionStyle.radius)
                            .strokeBorder(CompanionStyle.line, lineWidth: 1))
                        .accessibilityIdentifier("full-scratchpad-editor")
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "note.text")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(CompanionStyle.accent)
                        Text("Your notes will appear here")
                            .font(.system(size: 21, weight: .semibold, design: .rounded))
                        Text("Enable Key Scratch and open its keyboard once to finish bringing existing notes into the shared notebook.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Button("Start a blank notebook") { showCreateNotebook = true }
                            .buttonStyle(.borderedProminent)
                        Button("Set up the keyboard") { showNotesSetup = true }
                            .buttonStyle(.bordered)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .background(CompanionStyle.card,
                                in: RoundedRectangle(cornerRadius: CompanionStyle.radius))
                }

                if let notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = note
                        notice = "Copied this page"
                    } label: {
                        Label("Copy page", systemImage: "doc.on.doc")
                    }
                    .disabled(note.isEmpty)
                    ShareLink(item: note) {
                        Label("Share / export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(note.isEmpty)
                    Spacer()
                    Button(role: .destructive) { showClearConfirmation = true } label: {
                        Image(systemName: "eraser")
                    }
                    .disabled(note.isEmpty)
                    .accessibilityLabel("Clear current page")
                    if notebook.pages.count > 3 {
                        Button(role: .destructive) { showDeleteConfirmation = true } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Delete current scratchpad page")
                    }
                }
                .buttonStyle(.bordered)

                if loaded {
                    Text("Each page stays on this device. Text and attached images are saved separately.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(CompanionStyle.background)
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
        }
        .sheet(isPresented: $showNotesSetup) { SetupView() }
        .onChange(of: pickedPhotos) { _, selection in
            guard !selection.isEmpty else { return }
            Task { @MainActor in await importPhotos(selection) }
        }
        .sheet(item: $photoPreview) { photo in
            NavigationStack {
                Group {
                    if let url = ScratchpadImageStore.imageURL(id: photo.id),
                       let image = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    } else {
                        ContentUnavailableView("Image unavailable", systemImage: "photo")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.94))
                .navigationTitle("Scratchpad image")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { photoPreview = nil }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Copy", systemImage: "doc.on.doc") {
                            copyImage(photo)
                            photoPreview = nil
                        }
                    }
                }
            }
        }
        .onAppear { reloadNotebook() }
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification
        )) { _ in
            // A return from another app may bring changes made in the keyboard.
            // Never discard a draft that is being edited in this companion.
            if !focused && !importingPhotos { reloadNotebook() }
        }
        .confirmationDialog("Start a blank notebook?",
                            isPresented: $showCreateNotebook,
                            titleVisibility: .visible) {
            Button("Create blank notebook") { createNotebook() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("If you have notes from an older Key Scratch keyboard, open that keyboard once to migrate them before creating a blank notebook.")
        }
        .confirmationDialog("Remove this image from the page?",
                            isPresented: $showImageRemovalConfirmation,
                            titleVisibility: .visible) {
            Button("Remove image", role: .destructive) {
                if let photoPendingRemoval, let imageRemovalPageID {
                    removeImage(photoPendingRemoval, from: imageRemovalPageID)
                }
                photoPendingRemoval = nil
                imageRemovalPageID = nil
            }
            Button("Cancel", role: .cancel) {
                photoPendingRemoval = nil
                imageRemovalPageID = nil
            }
        } message: {
            Text("The saved image and thumbnail will be deleted from Key Scratch. Your original photo is unaffected.")
        }
        .confirmationDialog("Clear this page?", isPresented: $showClearConfirmation,
                            titleVisibility: .visible) {
            Button("Erase page text", role: .destructive) { editableNote.wrappedValue = "" }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone. Other pages will be preserved.")
        }
        .confirmationDialog("Delete this page?", isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Delete page", role: .destructive) {
                if let updated = ScratchpadStore.removePage(id: notebook.selectedID) {
                    notebook = updated
                    note = updated.selectedPage.text
                } else {
                    notice = "Could not delete this page."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The entire current page will be deleted. Other pages remain.")
        }
    }

    private func reloadNotebook() {
        // Avoid creating a notebook over an older extension-only local note.
        // The keyboard can migrate that source the first time it is opened.
        if let shared = ScratchpadStore.loadNotebook() {
            notebook = shared
            note = shared.selectedPage.text
            loaded = true
            notice = nil
        } else if let legacy = ScratchpadStore.load() {
            let migrated = ScratchpadStore.migrateNotebook(legacy: legacy)
            notebook = migrated
            note = migrated.selectedPage.text
            loaded = true
            notice = nil
        } else {
            loaded = false
            notice = nil
        }
    }

    private func createNotebook() {
        if let existing = ScratchpadStore.loadNotebook() {
            notebook = existing
            note = existing.selectedPage.text
            loaded = true
            notice = nil
            return
        }
        let initial = ScratchpadStore.migrateNotebook(legacy: ScratchpadStore.load())
        guard ScratchpadStore.loadNotebook() != nil else {
            notice = "Could not create the notebook. Check App Group signing."
            return
        }
        notebook = initial
        note = initial.selectedPage.text
        loaded = true
        notice = nil
    }

    /// Resize through ImageIO without ever decoding the original full-sized
    /// photo into a UIImage. This matters on older iPhones and large HEICs.
    private static func makeJPEGs(from data: Data) -> (full: Data, thumb: Data)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        func downsized(_ size: Int, quality: CGFloat) -> Data? {
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: size
            ]
            guard let raster = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
            else { return nil }
            return UIImage(cgImage: raster).jpegData(compressionQuality: quality)
        }
        guard let full = downsized(1200, quality: 0.76),
              let thumb = downsized(180, quality: 0.66) else { return nil }
        return (full, thumb)
    }

    @MainActor
    private func importPhotos(_ items: [PhotosPickerItem]) async {
        guard loaded, !importingPhotos else { return }
        let targetPage = notebook.selectedID
        importingPhotos = true
        defer {
            importingPhotos = false
            pickedPhotos = []
        }
        var imported = 0
        var lastIssue: String?
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let jpeg = Self.makeJPEGs(from: data) else {
                    lastIssue = "One image could not be decoded."
                    continue
                }
                _ = try ScratchpadImageStore.addImage(
                    pageID: targetPage, jpeg: jpeg.full, thumbnail: jpeg.thumb)
                imported += 1
            } catch {
                lastIssue = error.localizedDescription
                break
            }
        }
        if let updated = ScratchpadStore.loadNotebook() {
            notebook = updated
        }
        notice = lastIssue == nil
            ? "Added \(imported) image\(imported == 1 ? "" : "s") to this page."
            : "Added \(imported). \(lastIssue!)"
    }

    /// Unlike TextEditor, the explicitly labeled paste control accepts
    /// an image from Photos, Files, a screenshot, or another source. The image
    /// becomes a separate shelf attachment on the selected page.
    @MainActor
    private func pasteClipboardImage() {
        guard loaded, !importingPhotos else { return }
        guard let image = UIPasteboard.general.image else {
            notice = "Copy a picture in Photos or another app, then tap Paste image."
            return
        }
        do {
            let updated = try ScratchpadImageStore.addImage(
                pageID: notebook.selectedID, from: image)
            notebook = updated
            notice = "Image pasted onto Page \(updated.selectedIndex + 1)."
        } catch {
            notice = "Couldn't paste image: \(error.localizedDescription)"
        }
    }

    private func copyImage(_ photo: ScratchpadImage) {
        guard let url = ScratchpadImageStore.imageURL(id: photo.id),
              let image = UIImage(contentsOfFile: url.path) else {
            notice = "This image could not be opened."
            return
        }
        UIPasteboard.general.image = image
        notice = "Image copied. Paste into an app that accepts pictures."
    }

    private func confirmImageRemoval(_ photo: ScratchpadImage) {
        photoPendingRemoval = photo
        imageRemovalPageID = notebook.selectedID
        showImageRemovalConfirmation = true
    }

    private func removeImage(_ photo: ScratchpadImage, from pageID: String) {
        guard let updated = ScratchpadImageStore.removeImage(
            pageID: pageID, id: photo.id) else {
            notice = "Could not remove this image."
            return
        }
        notebook = updated
        notice = "Image removed from this page."
    }

    private func switchPage(to id: String) {
        guard loaded, id != notebook.selectedID else { return }
        if let updated = ScratchpadStore.selectPage(id: id) {
            notebook = updated
        } else {
            notebook.selectedID = id
            notice = "Page selection couldn't be saved."
        }
        note = notebook.selectedPage.text
    }

    private func addPage() {
        guard loaded else { return }
        if let updated = ScratchpadStore.addPage() {
            notebook = updated
            note = updated.selectedPage.text
        } else {
            notice = "Could not add a page. Maximum: \(ScratchpadNotebook.maximumPages)."
        }
    }
}


// MARK: - Companion character library
// Reuses the same lazily constructed Unicode source as the actual keyboard.
// No second, hand-maintained catalog to become outdated.

private struct FavoriteSymbolPicker: View {
    @Environment(\.dismiss) private var dismiss
    var embedded = false
    @Binding var favorites: [String]
    init(favorites: Binding<[String]>, embedded: Bool = false) {
        _favorites = favorites
        self.embedded = embedded
    }
    @State private var group = "All"
    @State private var query = ""
    @State private var manual = ""
    @State private var message = ""
    @State private var confirmClear = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 6)

    private var visible: [CharacterFinderItem] {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CharacterFinder.search(query, limit: 500)
        }
        if group == "All" {
            return CharacterFinder.categories.flatMap { category in
                Array(CharacterFinder.symbols(in: category.title).prefix(36))
            }
        }
        return CharacterFinder.symbols(in: group)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 17) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("KEY SCRATCH / CHARACTERS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.6).foregroundStyle(CompanionStyle.accent)
                        Text("Pin what you actually use.")
                            .font(.system(size: 23, weight: .semibold, design: .rounded))
                    }
                    HStack {
                        Text("Favorites on ★")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text("\(favorites.count)/48")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Button("Reset") {
                            favorites = KeyboardPreferences().favoriteSymbols
                        }
                        Button("Clear", role: .destructive) { confirmClear = true }
                    }
                    if favorites.isEmpty {
                        Text("Choose characters below or type them with Apple's emoji keyboard.")
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(favorites, id: \.self) { symbol in
                                    Button { remove(symbol) } label: {
                                        HStack(spacing: 2) {
                                            Text(symbol).font(.system(size: 22))
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 8)
                                        .frame(height: 42)
                                        .background(CompanionStyle.card,
                                                    in: RoundedRectangle(cornerRadius: 11))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove \(symbol) from favorites")
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Add a character")
                            .font(.system(size: 15, weight: .semibold))
                        HStack {
                            TextField("Type or paste a symbol", text: $manual)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(size: 20))
                                .submitLabel(.done)
                                .onSubmit(addEntered)
                                .accessibilityIdentifier("unicode-favorite-entry")
                            Button("Add", action: addEntered)
                                .buttonStyle(.borderedProminent)
                                .disabled(manual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        Text("Paste a symbol, or use Apple's emoji keyboard. Separate multiple items with spaces.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            if let value = UIPasteboard.general.string {
                                manual = value
                                addEntered()
                            } else {
                                message = "Clipboard contains no text symbols."
                            }
                        } label: {
                            Label("Add symbols from clipboard", systemImage: "doc.on.clipboard")
                        }
                        .font(.subheadline)
                    }
                    Divider()
                    TextField("Search symbols (heart, arrow, check…)", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("search-unicode-catalog")
                    Picker("Category", selection: $group) {
                        Text("All categories").tag("All")
                        ForEach(CharacterFinder.categories, id: \.title) { category in
                            Text(category.title).tag(category.title)
                        }
                    }
                    .pickerStyle(.menu)
                    HStack {
                        Text(query.isEmpty ? (group == "All" ? "Browse characters" : group) : "Search results")
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                        Spacer()
                        Text("\(visible.count) available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: columns, spacing: 7) {
                        ForEach(visible, id: \.symbol) { candidate in
                            let chosen = favorites.contains(candidate.symbol)
                            Button {
                                toggle(candidate.symbol)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    Text(candidate.symbol)
                                        .font(.system(size: 24))
                                        .frame(maxWidth: .infinity, minHeight: 43)
                                    if chosen {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 10))
                                            .offset(x: -1, y: 1)
                                    }
                                }
                                .background(chosen ? CompanionStyle.accent.opacity(0.16)
                                                   : CompanionStyle.card,
                                            in: RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(candidate.name): \(candidate.symbol), \(chosen ? "remove" : "add")")
                        }
                    }
                    if visible.isEmpty {
                        ContentUnavailableView.search(text: query)
                    }
                    if !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .frame(maxWidth: 660)
                .frame(maxWidth: .infinity)
            }
            .background(CompanionStyle.background.ignoresSafeArea())
            .navigationTitle("Characters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .confirmationDialog("Clear all favorite symbols?", isPresented: $confirmClear) {
                Button("Clear favorites", role: .destructive) { favorites = [] }
            } message: {
                Text("You can add them again from the catalog.")
            }
        }
        .tint(CompanionStyle.accent)
    }

    private func addEntered() {
        let tokens = manual.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !tokens.isEmpty else { return }
        var added = 0
        for symbol in tokens where symbol.count <= 8 {
            guard !favorites.contains(symbol), favorites.count < 48 else { continue }
            favorites.append(symbol)
            added += 1
        }
        message = added > 0 ? "Added \(added) item\(added == 1 ? "" : "s")."
            : "No new symbols added. Check for duplicates, the 48-item limit or symbols longer than 8 characters."
        manual = ""
    }

    private func toggle(_ symbol: String) {
        if favorites.contains(symbol) {
            remove(symbol)
        } else if favorites.count < 48 {
            favorites.append(symbol)
            message = ""
        } else {
            message = "48 favorites is the maximum. Remove an item first."
        }
    }

    private func remove(_ symbol: String) {
        favorites.removeAll { $0 == symbol }
        message = ""
    }
}

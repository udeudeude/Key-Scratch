import SwiftUI

private let accent = Color(uiColor: .systemBlue)
private let paper = Color(uiColor: .systemGroupedBackground)

struct ContentView: View {
    /// The app's own copy keeps every extra on; the published copy is what the edition allows.
    @State private var preferences = { var loaded = PreferenceStore.load(); loaded.extrasEnabled = true; return loaded }()
    @State private var showGeometry = false
    @State private var showSetup = false
    @State private var showSystemTest = false
    @State private var showKeyScratchLab = false
    @State private var showFullNotes = false
    @State private var saveError: String?
    @State private var triedGestures: Set<KeyboardGesture> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 10) {
                    Image("KeyScratchIcon")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .accessibilityLabel("Key Scratch car-key icon")
                    Text("Key Scratch").font(.system(size: 23, weight: .bold))
                    Spacer()
                    Text(languageBadge).font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .overlay(Capsule().stroke(.primary.opacity(0.18)))
                    Button { showGeometry = true } label: {
                        Label("Settings", systemImage: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .semibold)).frame(minHeight: 40)
                    }.accessibilityLabel("Customize keyboard").accessibilityIdentifier("customize-keyboard")
                }
                .padding(.top, 12)

                Button { showKeyScratchLab = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.split.2x1")
                            .font(.title3)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scratchpad & layout")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Adjust notes, key spacing and landscape layout")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("key-scratch-layout-settings")

                Button { showFullNotes = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "note.text")
                            .font(.title3)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scratchpad")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text("Edit your keyboard notes full-size, copy, or export")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .background(.primary.opacity(0.065), in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("open-key-scratch-notes")

                VStack(alignment: .leading, spacing: 12) {
                    Text("Notes alongside\nyour keyboard.")
                        .font(.system(size: 43, weight: .medium, design: .rounded)).tracking(-2)
                        .lineSpacing(-5).fixedSize(horizontal: false, vertical: true)
                    Text("Swipe naturally while keeping your notes visible beside the keyboard.")
                        .font(.system(size: 16)).foregroundStyle(.secondary).lineSpacing(4)
                }

                HStack(spacing: 8) {
                    Label("Private typing", systemImage: "lock.shield")
                    Text("·")
                    Text("No tracking")
                    Text("·")
                    Text("Local notes")
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(accent)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("KEYBOARD PREVIEW").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2)
                        Spacer()
                        Button("Clear") { NotificationCenter.default.post(name: .clearKeyboardPreview, object: nil) }
                            .font(.system(size: 12, weight: .medium)).accessibilityIdentifier("clear-preview")
                    }
                    PreviewSurface(preferences: KeyboardPublisher.published(preferences),
                                   isActive: !showGeometry && !showSetup && !showSystemTest) { gesture in
                        triedGestures.insert(gesture)
                    }
                        .frame(height: 100 + preferences.keyboardHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.primary.opacity(0.08)))
                    GestureChecklist(preferences: preferences, tried: triedGestures)
                }

                VStack(spacing: 10) {
                    Button { showSetup = true } label: {
                        HStack { Text("Enable keyboard"); Spacer(); Image(systemName: "arrow.up.right") }
                            .font(.system(size: 14, weight: .semibold)).padding(17)
                            .foregroundStyle(.white).background(accent, in: RoundedRectangle(cornerRadius: 12))
                    }.accessibilityIdentifier("enable-keyboard")
                    Button { showGeometry = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3").font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Keyboard settings").font(.system(size: 15, weight: .semibold))
                                Text("Themes, layout and typing").font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }.padding(17).frame(maxWidth: .infinity)
                            .background(.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }.accessibilityLabel("Keyboard settings, themes, layout and typing").accessibilityIdentifier("adjust-geometry")
                }

                VStack(spacing: 0) {
                    detailRow("01", title: "Familiar keyboard geometry.", subtitle: "iPhone-like key positions with adjustable height and note width.")
                    Divider().padding(.vertical, 17)
                    detailRow("02", title: "Your note, always visible.", subtitle: "Keep a reference in sight while composing text in another app.")
                    Divider().padding(.vertical, 17)
                    detailRow("03", title: "Notes remain on-device.", subtitle: "Full Access enables the clipboard and the companion app's shared note.")
                }
                .padding(20).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))

                Button("Test the installed system keyboard") { showSystemTest = true }
                    .font(.system(size: 13, weight: .medium)).accessibilityIdentifier("system-test")
                HStack(spacing: 20) {
                    Link("Privacy policy", destination: URL(string: "https://github.com/udeudeude/Key-Scratch/blob/feature/scratchpad-first-pass/PRIVACY.md")!)
                    Link("Source and feedback", destination: URL(string: "https://github.com/udeudeude/Key-Scratch/issues")!)
                }
                .font(.system(size: 13, weight: .medium))
                Text("KEY SCRATCH / LOCAL NOTES")
                    .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1.5)
                    .foregroundStyle(.tertiary).padding(.bottom, 20)
            }
            .padding(.horizontal, 22).frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(paper).tint(accent)
        .sheet(isPresented: $showGeometry) { GeometrySettings(preferences: $preferences) }
        .sheet(isPresented: $showSetup) { SetupView() }
        .sheet(isPresented: $showSystemTest) { SystemKeyboardTest() }
        .sheet(isPresented: $showKeyScratchLab) { KeyScratchExperimentLab(preferences: $preferences) }
        .sheet(isPresented: $showFullNotes) { KeyScratchFullNotes() }
        .onChange(of: preferences) { _, value in
            do { try KeyboardPublisher.publish(value) }
            catch { saveError = "The preview was updated, but settings could not be shared with the extension. Check that both targets use the same App Group and signing team." }
        }
        .onReceive(NotificationCenter.default.publisher(for: ProHooks.accessChanged)) { _ in
            try? KeyboardPublisher.publish(preferences)
        }
        .alert("Settings weren’t saved", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "") }
    }

    private func detailRow(_ index: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(index).font(.system(size: 11, design: .monospaced)).foregroundStyle(accent).padding(.top, 3)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary).lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
    }

    private var languageBadge: String {
        let languages = preferences.validated.languages
        let shown = languages.prefix(2).map(\.badge).joined(separator: " + ")
        return languages.count > 2 ? "\(shown) +\(languages.count - 2)" : shown
    }
}

/// Ticks off each gesture as it's tried in the preview above.
private struct GestureChecklist: View {
    let preferences: KeyboardPreferences
    let tried: Set<KeyboardGesture>

    private var items: [(KeyboardGesture, String)] {
        var items: [(KeyboardGesture, String)] = [
            (.alternative, "Hold a letter, then slide to choose an accent"),
            (.symbolSlide, "Hold 123, slide to a symbol, release"),
            (.spaceCursor, "Slide on Space to move the cursor")
        ]
        if preferences.digitAccess == .flick { items.append((.flick, "Flick a top-row key down for its digit")) }
        if preferences.glideTyping { items.append((.glide, "Slide across letters to type a whole word")) }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("TRY THIS").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2)
                .foregroundStyle(.secondary)
            ForEach(items, id: \.0) { gesture, title in
                let done = tried.contains(gesture)
                Label(title, systemImage: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundStyle(done ? accent : .secondary)
                    .accessibilityIdentifier("try-\(gesture.rawValue)")
                    .accessibilityValue(done ? "Done" : "Not yet")
            }
            Text("Tap Space twice to end a sentence. Double-tap Shift for caps lock.")
                .font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(3)
        }
        .animation(.easeOut(duration: 0.2), value: tried)
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
            .background(Color(uiColor: .systemGroupedBackground))
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
        .tint(accent)
        .onChange(of: preferences) { _, value in
            do { try KeyboardPublisher.publish(value) }
            catch { saveError = true }
            if !value.validated.languages.contains(previewLanguage) { previewLanguage = value.validated.defaultLanguage }
        }
        .onDisappear { commit(preferences) }
        .alert("Settings weren’t saved", isPresented: $saveError) {
            Button("OK", role: .cancel) { }
        } message: { Text("Please reopen settings and try again.") }
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
        .background(.regularMaterial)
        // Not Divider: beside the form in landscape it would turn vertical, through the preview.
        .overlay(alignment: .top) { Rectangle().fill(Color(uiColor: .separator)).frame(height: 0.5) }
    }

    private var controls: some View {
        Form {
            Section("Languages") {
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
            Section("Appearance") {
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
            Section("Suggestions") {
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
            } header: { Label("Layout · Presets", systemImage: "square.grid.3x3") }
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
            } header: { Label("Layout · Size", systemImage: "textformat.size") } footer: {
                Text("Size letters and controls separately. The preview updates as you drag.")
            }
            Section {
                slider("Column spacing", value: $preferences.columnSpacing, range: 0...8)
                slider("Row spacing", value: $preferences.rowSpacing, range: 0...12)
                Toggle("Fill gaps between keys", isOn: $preferences.fillGaps)
                    .accessibilityIdentifier("fill-gaps")
            } header: { Label("Layout · Spacing", systemImage: "arrow.left.and.right") } footer: {
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
                Toggle("iPhone key positions", isOn: $preferences.iphoneKeyPositions)
                    .accessibilityIdentifier("iphone-key-positions")
                    .accessibilityIdentifier("show-header")
            } header: { Label("Layout · Controls", systemImage: "rectangle.bottomthird.inset.filled") } footer: {
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
            } header: { Label("Letters · Optional keys", systemImage: "character.cursor.ibeam") } footer: {
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
            } header: { Label("Letters · Digits", systemImage: "number") } footer: {
                Text(digitFooter)
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
                Button("Reset to defaults") { preferences = KeyboardPreferences() }
            } footer: {
                Text("Settings save on this device. Dismiss and reopen the system keyboard to apply changes. Hold the ★ key to switch between enabled languages.")
            }
        }
        .accessibilityIdentifier("geometry-controls")
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
            List {
                Section {
                    Label("Open Settings → General → Keyboard", systemImage: "1.circle")
                    Label("Choose Keyboards → Add New Keyboard", systemImage: "2.circle")
                    Label("Select Key Scratch", systemImage: "3.circle")
                    Label("In any text field, use the globe to switch to Key Scratch", systemImage: "4.circle")
                } header: { Text("A one-time setup") } footer: {
                    Text("For notes Copy/Paste and sharing the scratchpad with this app, select Key Scratch under Settings → General → Keyboard → Keyboards and enable Allow Full Access. No internet connection or account is needed.")
                }
                Section {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } footer: { Text("If Settings opens the app page, return to the main Settings list and follow the steps above.") }
                Section("Where it works") {
                    Text("Use it in apps that allow third-party keyboards. iOS uses its own keyboard for passwords and phone-pad fields. Some apps disable third-party keyboards entirely.")
                    Text("Suggestions change a word only when you tap one. Sentences start with a capital where the text field asks for it. Capitals, suggestions, glide typing and punctuation spacing can each be turned off in settings.")
                }
            }
            .navigationTitle("Meet your new keyboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(accent)
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


/// One everyday split keyboard, not the old color-coded A/B experiment.
private struct KeyScratchExperimentLab: View {
    @Binding var preferences: KeyboardPreferences
    @State private var draft: KeyboardPreferences
    @State private var testText = ""
    @State private var symbolsText: String
    @State private var status = "Adjust settings, then Apply and test."
    @FocusState private var testing: Bool
    @Environment(\.dismiss) private var dismiss

    init(preferences: Binding<KeyboardPreferences>) {
        _preferences = preferences
        _draft = State(initialValue: PreferenceStore.normalized(preferences.wrappedValue))
        _symbolsText = State(initialValue: preferences.wrappedValue.validated.favoriteSymbols.joined(separator: " "))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Notes width in portrait")
                        Spacer()
                        Text("\(Int(draft.keyScratchNoteWidth * 100))%")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $draft.keyScratchNoteWidth, in: 0.18...0.42, step: 0.02)
                        .accessibilityLabel("Portrait notes width")
                    HStack {
                        Text("Note text size")
                        Spacer()
                        Text("\(Int(draft.keyScratchNoteFontSize)) pt")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: $draft.keyScratchNoteFontSize, in: 9...16, step: 1)
                    Picker("Note typeface", selection: $draft.keyScratchNoteFont) {
                        ForEach(KeyScratchNoteFont.allCases) { font in
                            Text(font.title).tag(font)
                        }
                    }
                } header: {
                    Text("Scratchpad")
                } footer: {
                    Text("In landscape, the keyboard stays compact at the far right and the scratchpad fills the available space to its left. Portrait proportions are unchanged.")
                }

                Section {
                    adjustment("Letter row", value: $draft.keyHeight, bounds: 36...88)
                    adjustment("Control row", value: $draft.controlHeight, bounds: 36...72)
                    adjustment("Row spacing", value: $draft.rowSpacing, bounds: 0...12)
                    adjustment("Column spacing", value: $draft.columnSpacing, bounds: 0...8)
                } header: {
                    Text("Keyboard size")
                } footer: {
                    Text("Landscape uses shorter keys and tighter gaps automatically. The entire area between visible keys remains tappable while Fill Gaps is enabled.")
                }

                Section("Layout") {
                    Toggle("iPhone key positions", isOn: $draft.iphoneKeyPositions)
                    Toggle("Fill invisible key gaps", isOn: $draft.fillGaps)
                    Toggle("Show tiny key hints", isOn: $draft.showLongPressHints)
                }

                Section {
                    Text("Tap ★ on the keyboard for these favorites. Recently used symbols appear first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $symbolsText)
                        .font(.system(size: 19))
                        .frame(minHeight: 78)
                        .accessibilityIdentifier("favorite-symbols-editor")
                        .onChange(of: symbolsText) { _, edited in
                            draft.favoriteSymbols = Array(edited.split(whereSeparator: \.isWhitespace)
                                .map(String.init).prefix(48))
                        }
                    Button("Restore standard favorites") {
                        draft.favoriteSymbols = KeyboardPreferences().favoriteSymbols
                        symbolsText = draft.favoriteSymbols.joined(separator: " ")
                    }
                } header: {
                    Text("Favorite emoji & symbols")
                } footer: {
                    Text("Enter emoji or Unicode symbols separated by spaces (up to 48). Tap Apply and test to update the keyboard. Recent usage is remembered on this iPhone.")
                }

                Section("Clipboard access") {
                    Text("Allow Full Access enables Copy and Paste in the keyboard and lets the containing app share your local scratchpad. Key Scratch does not transmit your text.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open iOS Settings", systemImage: "gear")
                    }
                    Text("General → Keyboard → Keyboards → Key Scratch → Allow Full Access")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Try it immediately") {
                    Button {
                        let next = PreferenceStore.normalized(draft)
                        do {
                            try KeyboardPublisher.publish(next)
                            preferences = next
                            status = "Applied. Switch away from Key Scratch and back with the globe to reload."
                            testing = true
                        } catch {
                            status = "Settings could not be shared. Check App Group signing."
                        }
                    } label: {
                        Label("Apply and test", systemImage: "checkmark.circle")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("apply-key-scratch-layout")

                    Button {
                        let setup = PreferenceStore.normalized(draft)
                        UIPasteboard.general.string = [
                            "Key Scratch layout",
                            "Portrait notes: \(Int(setup.keyScratchNoteWidth * 100))%",
                            "Landscape: compact keyboard right, notes fill remainder",
                            "Note: \(setup.keyScratchNoteFont.title), \(Int(setup.keyScratchNoteFontSize)) pt",
                            "Letters: \(Int(setup.keyHeight)) pt; controls: \(Int(setup.controlHeight)) pt",
                            "Gaps: \(Int(setup.rowSpacing)) pt rows, \(Int(setup.columnSpacing)) pt columns",
                            "Fill gaps: \(setup.fillGaps); hints: \(setup.showLongPressHints)"
                        ].joined(separator: "\n")
                        status = "Settings copied."
                    } label: {
                        Label("Copy settings", systemImage: "doc.on.doc")
                    }
                    Text(status).font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $testText)
                        .focused($testing)
                        .frame(height: 100)
                        .accessibilityIdentifier("layout-test-text-editor")
                    Text("This uses the installed keyboard, not a mockup.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Scratchpad & layout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(accent)
    }

    private func adjustment(_ title: String, value: Binding<Double>,
                            bounds: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(value.wrappedValue)) pt")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: bounds, step: 1)
                .accessibilityLabel(title)
        }
    }
}


/// Full-size companion editor for the very same local note shown in the keyboard.
/// The keyboard extension is short-lived; the App Group note is shared locally
/// without accounts, synchronization services, or network access.
private struct KeyScratchFullNotes: View {
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var loaded = false
    @State private var showClearConfirmation = false
    @State private var notice: String?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("The note shown beside your keyboard, with room to edit it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $note)
                    .focused($focused)
                    .font(.system(size: 16))
                    .scrollContentBackground(.hidden)
                    .padding(7)
                    .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("full-scratchpad-editor")
                    .disabled(!loaded)
                if let notice {
                    Text(notice).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = note
                        notice = "Copied all note text"
                    } label: {
                        Label("Copy all", systemImage: "doc.on.doc")
                    }
                    .disabled(note.isEmpty)
                    ShareLink(item: note) {
                        Label("Share / export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(note.isEmpty)
                    Spacer()
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(note.isEmpty)
                    .accessibilityLabel("Clear entire note")
                }
                .buttonStyle(.bordered)
                Text("For normal selection, Cut, Copy, Paste, and Select All, touch and hold inside the editor. Changes save on this iPhone and appear in the keyboard when it opens again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Scratchpad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            // Do not write an empty new note over an older extension-only note.
            // The extension imports that old note the first time it starts.
            if let shared = ScratchpadStore.load() {
                note = shared
                loaded = true
            } else {
                loaded = false
                notice = "Open the updated Key Scratch keyboard once to import your existing note, then reopen this editor."
            }
        }
        .onChange(of: note) { _, value in
            guard loaded else { return }
            if !ScratchpadStore.save(value) {
                notice = "Shared note storage is unavailable. Check App Group signing before closing."
            } else {
                notice = nil
            }
        }
        .confirmationDialog("Erase the entire scratchpad?", isPresented: $showClearConfirmation,
                            titleVisibility: .visible) {
            Button("Erase note", role: .destructive) { note = "" }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Use Share / export if you want a backup first.")
        }
    }
}

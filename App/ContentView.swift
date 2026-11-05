import SwiftUI
import PhotosUI
import ImageIO

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
    @State private var showSymbolPicker = false
    @State private var status = "Adjust settings, then Apply and test."
    @FocusState private var testing: Bool
    @Environment(\.dismiss) private var dismiss

    init(preferences: Binding<KeyboardPreferences>) {
        _preferences = preferences
        _draft = State(initialValue: PreferenceStore.normalized(preferences.wrappedValue))
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
                    Toggle("Left-handed layout", isOn: $draft.leftHandedLayout)
                        .accessibilityIdentifier("left-handed-keyboard-layout")
                    Picker("Scratchpad appearance", selection: $draft.scratchpadVisualStyle) {
                        ForEach(ScratchpadVisualStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    .accessibilityIdentifier("scratchpad-visual-style")
                    if draft.scratchpadVisualStyle != .standard {
                        Text("KEY SCRATCH / FIELD NOTES\nThe universe is still there. ✓")
                            .font(.custom("CourierNewPSMT", size: 12))
                            .foregroundStyle(terminalInk)
                            .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
                            .padding(.horizontal, 12)
                            .background(terminalGlass, in: RoundedRectangle(cornerRadius: 7))
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .strokeBorder(terminalInk.opacity(0.32), lineWidth: 0.7)
                            }
                            .accessibilityLabel("Preview of terminal scratchpad appearance")
                    }
                } header: {
                    Text("Scratchpad")
                } footer: {
                    Text("Standard: notes left, keys right. Left-handed: keys left, notes right, in portrait and landscape. Terminal styles adapt the green, amber and composite-television visuals of Temporarily Leave the Universe without running a web browser.")
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
                    HStack {
                        Text("Your favorites")
                        Spacer()
                        Text("\(draft.favoriteSymbols.count)/48")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    if draft.favoriteSymbols.isEmpty {
                        Text("No favorites yet. Add them from the symbol browser or iPhone's emoji keyboard.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 7) {
                                ForEach(draft.favoriteSymbols.indices, id: \.self) { index in
                                    Text(draft.favoriteSymbols[index])
                                        .font(.system(size: 22))
                                        .frame(minWidth: 38, minHeight: 38)
                                        .background(Color.secondary.opacity(0.10),
                                                    in: RoundedRectangle(cornerRadius: 7))
                                }
                            }
                        }
                    }
                    Button {
                        showSymbolPicker = true
                    } label: {
                        Label("Browse & manage favorites", systemImage: "square.grid.3x3")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityIdentifier("browse-favorite-symbols")
                } header: {
                    Text("Favorite emoji & Unicode")
                } footer: {
                    Text("Browse hundreds of emoji and Unicode characters, search by name, or enter characters with the standard iPhone emoji keyboard. Tap Apply and test afterward.")
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
                            "Left-handed: \(setup.leftHandedLayout)",
                            "Scratchpad appearance: \(setup.scratchpadVisualStyle.title)",
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
        .sheet(isPresented: $showSymbolPicker) {
            FavoriteSymbolPicker(favorites: $draft.favoriteSymbols)
        }
    }

    private var terminalInk: Color {
        switch draft.scratchpadVisualStyle {
        case .standard: .primary
        case .phosphorGreen: Color(red: 0.47, green: 0.94, blue: 0.44)
        case .amber: Color(red: 1, green: 0.73, blue: 0.22)
        case .composite: Color(white: 0.95)
        }
    }

    private var terminalGlass: Color {
        switch draft.scratchpadVisualStyle {
        case .standard: .clear
        case .phosphorGreen: Color(red: 0.004, green: 0.016, blue: 0.004)
        case .amber: Color(red: 0.016, green: 0.008, blue: 0)
        case .composite: Color(red: 0.008, green: 0.008, blue: 0.016)
        }
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


/// Full-size companion editor of the *same pages* as the keyboard extension.
/// App Group storage is the source of truth. Text changes save only the
/// selected page, preserving any edits to the other pages.
private struct KeyScratchFullNotes: View {
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
                Text("Your pages appear beside the keyboard. Tap a tab to switch.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

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
                                        ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 9))
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
                                    Button("Copy image", systemImage: "doc.on.doc") {
                                        copyImage(photo)
                                    }
                                    Button("Remove from page", systemImage: "trash", role: .destructive) {
                                        confirmImageRemoval(photo)
                                    }
                                }
                                .overlay(alignment: .topTrailing) {
                                    Button(role: .destructive) {
                                        confirmImageRemoval(photo)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .black.opacity(0.85))
                                            .padding(3)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove scratchpad image")
                                    .accessibilityIdentifier("remove-companion-scratchpad-image-\(photo.id)")
                                }
                            }
                        }
                    }
                    Text("Tap an image to preview or copy it. Tap its X to remove it, or hold for more options.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text("To paste a picture here: copy it in Photos, then tap Paste image. The picture is saved separately from this page's text.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: editableNote)
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

                Text("Select, Cut, Copy or Paste using the normal iPhone edit menu. Edits are saved locally to the active page. The keyboard's bottom tabs switch between those same pages.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Scratchpad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
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
        .onAppear {
            // Preserve any extension-only legacy note until the keyboard has
            // migrated it. An empty editor must never overwrite old content.
            if let shared = ScratchpadStore.loadNotebook() {
                notebook = shared
                note = shared.selectedPage.text
                loaded = true
            } else if let legacy = ScratchpadStore.load() {
                notebook = ScratchpadStore.migrateNotebook(legacy: legacy)
                note = notebook.selectedPage.text
                loaded = true
            } else {
                loaded = false
                notice = "Open the updated Key Scratch keyboard once to import your existing note, then reopen this editor."
            }
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


// MARK: - Searchable Unicode and Emoji Favorites

/// A curated, local browse library; not a network emoji service.
/// The edit field uses the native iPhone keyboard, including Apple's Emoji
/// keyboard, so users can choose anything that isn't in the catalog.
private struct SymbolCatalogItem: Identifiable, Sendable {
    let symbol: String
    let group: String
    let names: String
    var id: String { group + ":" + symbol }
}

private enum SymbolCatalog {
    struct Group: Sendable {
        let name: String
        let glyphs: String
    }
    static let groups: [Group] = [
        .init(name: "Faces & gestures",
              glyphs: "😀 😃 😄 😁 😆 😅 😂 🤣 😊 🙂 🙃 😉 😌 😍 🥰 😘 😋 😎 🤓 🧐 🤔 🤨 😐 😑 😶 🙄 😏 😒 😔 😕 🥺 😢 😭 😤 😡 🤯 🫠 🫢 🤫 😴 😵 🥴 😈 👻 💀 🤖 👍 👎 👌 🤌 🤏 ✌️ 🤞 🫰 🤟 🤘 🤙 👏 🙌 👐 🫶 🤲 🙏 💪 👋"),
        .init(name: "Hearts & everyday",
              glyphs: "❤️ 🩷 🧡 💛 💚 💙 🩵 💜 🤎 🖤 🩶 🤍 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 ✨ ⭐ 🌟 💫 🎉 🎊 🎁 🔥 🌈 ☀️ 🌙 ☁️ ❄️ 🌸 🌹 🌻 🌲 🍀 🍎 🍋 🍓 🍕 🍜 ☕ 🍵 🎂 🎈 🐈 🐕 🦋 🐦 🐝"),
        .init(name: "Arrows",
              glyphs: "← ↑ → ↓ ↔ ↕ ↖ ↗ ↘ ↙ ↞ ↠ ↟ ↡ ↢ ↣ ↤ ↦ ↩ ↪ ↫ ↬ ↭ ↮ ↯ ↰ ↱ ↲ ↳ ↴ ↶ ↷ ↺ ↻ ⇐ ⇑ ⇒ ⇓ ⇔ ⇕ ⇖ ⇗ ⇘ ⇙ ⇠ ⇢ ⇤ ⇥ ⇦ ⇧ ⇨ ⇩ ⇪ ⇫ ⇬ ⇭ ⇮ ⇯ ➔ ➜ ➝ ➞ ➡ ➤ ⟵ ⟶ ⟷ ⟸ ⟹ ⟺"),
        .init(name: "Math & logic",
              glyphs: "± ∓ × ÷ ≠ ≈ ≅ ≡ ≤ ≥ ≪ ≫ ∞ ∝ ∂ ∇ ∑ ∏ ∐ ∫ ∬ ∮ ∯ ∰ √ ∛ ∜ ∴ ∵ ∀ ∃ ∄ ∅ ∈ ∉ ∋ ∌ ∩ ∪ ⊂ ⊃ ⊆ ⊇ ⊄ ⊅ ∧ ∨ ¬ ⊕ ⊗ ⊥ ∥ ∠ ∡ ∢ ∟ ∧ ∨ ∼ ∽ ∘ ∙ ⋅ ⊢ ⊣ ⊨ ⊩ ⊤ ⊥"),
        .init(name: "Typography",
              glyphs: "• ◦ ‣ ⁃ … ‥ — – ‒ ― ‐ ‑ ‧ · ′ ″ ‴ ‘ ’ “ ” ‚ „ ‹ › « » ※ ⁂ § ¶ † ‡ ⁄ ‰ ‱ № ⸮ ¿ ¡ ‽ ⁎ ⁑ ⁒ ⁓ ⁕ ⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹ ₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉"),
        .init(name: "Checkmarks & shapes",
              glyphs: "✓ ✔ ☑ ☐ ✅ ❌ ✕ ✖ ✗ ❎ ⚠️ ⛔ ⭕ ◯ ○ ● ◉ ◎ ◌ ◍ ◐ ◑ ◒ ◓ ◔ ◕ ◖ ◗ ◘ ◙ ◚ ◛ ◜ ◝ ◞ ◟ □ ■ ▣ ▢ ▪ ▫ ▰ ▱ ▲ △ ▼ ▽ ▶ ▷ ◀ ◁ ◆ ◇ ◈ ◊ ★ ☆ ✦ ✧ ✩ ✪ ✫ ✬ ✭ ✮ ✯ ✰"),
        .init(name: "Science & technical",
              glyphs: "° ℃ ℉ K Å µ μ Ω ℧ π τ φ λ Δ Σ α β γ δ ε θ κ ρ σ ω ħ ℏ ℎ ℓ ℘ ℜ ℑ ℵ ℶ ℷ ℸ ∿ ⌁ ⌂ ⌃ ⌄ ⌅ ⌆ ⌇ ⌘ ⌥ ⌦ ⌫ ⌧ ⌨ ⏎ ⎋ ⏏ ⏻ ⏼ ⏽ ⭘ ⚙️ ⚛️ 🧪 🧬 🔬 🔭"),
        .init(name: "Currency & legal",
              glyphs: "$ ¢ £ € ¥ ₹ ₩ ₽ ₺ ₴ ₦ ₱ ฿ ₪ ₫ ₲ ₵ ₡ ₢ ₣ ₤ ₥ ₧ ₨ ₭ ₮ ₯ ₰ ₳ ₸ ₼ ₿ © ® ™ ℠ ℗ ℞ ℡ ℅ №"),
        .init(name: "Music, games & symbols",
              glyphs: "♩ ♪ ♫ ♬ ♭ ♮ ♯ 𝄞 𝄢 ♠ ♣ ♥ ♦ ♤ ♧ ♡ ♢ ♔ ♕ ♖ ♗ ♘ ♙ ♚ ♛ ♜ ♝ ♞ ♟ ⚀ ⚁ ⚂ ⚃ ⚄ ⚅ ☀ ☁ ☂ ☃ ☄ ☉ ☊ ☋ ☌ ☍ ☎ ☏ ☒ ☓ ☠ ☮ ☯ ☸ ☹ ☺ ☻ ☼ ♀ ♂ ⚢ ⚣ ⚤ ⚥ ⚦ ⚧")
    ]
    static let names: [String: String] = [
        "❤️":"red heart love", "🩷":"pink heart love", "😀":"grinning smile happy",
        "😂":"laughing tears joy", "🤣":"rolling laughing", "🤔":"thinking face",
        "🙃":"upside down", "👍":"thumbs up yes", "👎":"thumbs down no",
        "🙏":"prayer thanks", "🫶":"heart hands", "💀":"skull", "☕":"coffee cup",
        "🎉":"party celebration", "🔥":"fire hot", "✨":"sparkles stars",
        "←":"left arrow", "↑":"up arrow", "→":"right arrow", "↓":"down arrow",
        "↔":"left right arrow", "↩":"return arrow", "↪":"forward arrow",
        "↗":"northeast arrow", "⇔":"equivalence arrow", "⇒":"implies arrow",
        "✓":"check mark tick", "✔":"check mark tick", "☑":"checked box",
        "☐":"empty box unchecked", "❌":"cross red no",
        "★":"filled star", "☆":"outline star", "•":"bullet point",
        "…":"ellipsis dots", "—":"em dash", "–":"en dash",
        "‘":"single opening quotation", "’":"single closing apostrophe",
        "“":"double opening quotation", "”":"double closing quotation",
        "©":"copyright", "®":"registered trademark", "™":"trademark",
        "°":"degree", "℃":"celsius", "℉":"fahrenheit", "µ":"micro",
        "π":"pi", "Ω":"omega ohm", "λ":"lambda", "Δ":"delta",
        "≠":"not equal", "≈":"approximately", "≤":"less than equal",
        "≥":"greater than equal", "∞":"infinity", "±":"plus minus",
        "×":"multiply", "÷":"divide", "√":"square root",
        "∑":"sum sigma", "∫":"integral", "∈":"element of",
        "∅":"empty set", "∴":"therefore", "∵":"because",
        "€":"euro", "£":"pound sterling", "¥":"yen yuan", "₿":"bitcoin",
        "♩":"quarter note music", "♪":"eighth note music", "♭":"flat music",
        "♯":"sharp music", "♠":"spade card", "♣":"club card",
        "♥":"heart card", "♦":"diamond card", "⌘":"command mac keyboard",
        "⌥":"option alt mac keyboard", "⌫":"delete backspace",
        "⏎":"return enter", "⚛️":"atom", "🧬":"dna", "🔭":"telescope"
    ]
    static let items: [SymbolCatalogItem] = groups.flatMap { group in
        group.glyphs.split(whereSeparator: \.isWhitespace).map { glyph in
            let text = String(glyph)
            return SymbolCatalogItem(symbol: text, group: group.name,
                                     names: names[text] ?? "")
        }
    }
}

/// A small local symbol library with a normal iPhone text field for accessing
/// the full system emoji keyboard. Saves to the existing favorites preference.
private struct FavoriteSymbolPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var favorites: [String]
    @State private var group = "All"
    @State private var query = ""
    @State private var manual = ""
    @State private var message = ""
    @State private var confirmClear = false
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 6)

    private var visible: [SymbolCatalogItem] {
        SymbolCatalog.items.filter { candidate in
            let matchingGroup = group == "All" || candidate.group == group
            let matchingSearch = query.isEmpty ||
                candidate.symbol.localizedCaseInsensitiveContains(query) ||
                candidate.names.localizedCaseInsensitiveContains(query) ||
                candidate.group.localizedCaseInsensitiveContains(query)
            return matchingGroup && matchingSearch
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        Text("Selected")
                            .font(.headline)
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
                                        .background(Color.secondary.opacity(0.10),
                                                    in: RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove \(symbol) from favorites")
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Enter any emoji or Unicode character")
                            .font(.subheadline.weight(.medium))
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
                        Text("Use the globe key to switch to Apple's Emoji keyboard. Separate several symbols with spaces.")
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
                        ForEach(SymbolCatalog.groups, id: \.name) { category in
                            Text(category.name).tag(category.name)
                        }
                    }
                    .pickerStyle(.menu)
                    HStack {
                        Text(group == "All" ? "Browse characters" : group)
                            .font(.headline)
                        Spacer()
                        Text("\(visible.count) available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    LazyVGrid(columns: columns, spacing: 7) {
                        ForEach(visible) { candidate in
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
                                .background(chosen ? Color.accentColor.opacity(0.19)
                                                   : Color.secondary.opacity(0.09),
                                            in: RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(candidate.names.isEmpty ? candidate.group : candidate.names): \(candidate.symbol), \(chosen ? "remove" : "add")")
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
                .padding()
            }
            .navigationTitle("Emoji & Unicode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear all favorite symbols?", isPresented: $confirmClear) {
                Button("Clear favorites", role: .destructive) { favorites = [] }
            } message: {
                Text("You can add them again from the catalog.")
            }
        }
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

import Foundation

enum PreferenceStore {
    // Only the containing app writes. The extension reads this file without Full Access.
    static var fileURL: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "OrtholinearAppGroup") as? String else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent("geometry.json")
    }

    static func load() -> KeyboardPreferences {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let preferences = try? JSONDecoder().decode(KeyboardPreferences.self, from: data) else {
            return KeyboardPreferences()
        }
        return normalized(preferences)
    }

    /// Historical color-coded A/B modes are retained only for decoding older
    /// files. Key Scratch now has one ordinary split layout and its adjustable
    /// geometry; old Blue/Red/Amber/Purple choices migrate to it automatically.
    static func normalized(_ preferences: KeyboardPreferences) -> KeyboardPreferences {
        var result = preferences.validated
        result.keyScratchMode = .split
        return result
    }

    static func save(_ preferences: KeyboardPreferences) throws {
        guard let url = fileURL else { throw CocoaError(.fileNoSuchFile) }
        try JSONEncoder().encode(normalized(preferences)).write(to: url, options: .atomic)
    }
}

 
enum ScratchpadStore {
    private static let legacyKey = "key-scratch.local-note.v1"
    private static let notebookKey = "key-scratch.notebook.v2"

    private static var sharedDefaults: UserDefaults? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "OrtholinearAppGroup") as? String,
              !group.isEmpty else { return nil }
        return UserDefaults(suiteName: group)
    }

    static func loadNotebook() -> ScratchpadNotebook? {
        guard let data = sharedDefaults?.data(forKey: notebookKey),
              let notebook = try? JSONDecoder().decode(ScratchpadNotebook.self, from: data) else { return nil }
        return notebook.normalized
    }

    @discardableResult
    static func saveNotebook(_ notebook: ScratchpadNotebook) -> Bool {
        guard let defaults = sharedDefaults,
              let data = try? JSONEncoder().encode(notebook.normalized) else { return false }
        defaults.set(data, forKey: notebookKey)
        return true
    }

    /// Prefer the new multi-page record, then the old shared note, then the
    /// keyboard extension's local note. No existing note is ever overwritten.
    static func migrateNotebook(legacy: String?) -> ScratchpadNotebook {
        if let existing = loadNotebook() { return existing }
        let text = sharedDefaults?.string(forKey: legacyKey) ?? legacy ?? ""
        let notebook = ScratchpadNotebook.initial(legacy: text)
        _ = saveNotebook(notebook)
        return notebook
    }

    /// Update only the current page from fresh shared data; do not replace
    /// changes another app made to unrelated pages since this view appeared.
    @discardableResult
    static func savePage(id: String, text: String) -> Bool {
        guard var notebook = loadNotebook(), let index = notebook.pages.firstIndex(where: { $0.id == id })
        else { return false }
        notebook.pages[index].text = text
        return saveNotebook(notebook)
    }

    @discardableResult
    static func selectPage(id: String) -> ScratchpadNotebook? {
        guard var notebook = loadNotebook(), notebook.pages.contains(where: { $0.id == id })
        else { return nil }
        notebook.selectedID = id
        return saveNotebook(notebook) ? notebook : nil
    }

    static func addPage() -> ScratchpadNotebook? {
        guard var notebook = loadNotebook(), notebook.pages.count < ScratchpadNotebook.maximumPages else { return nil }
        let page = ScratchpadPage()
        notebook.pages.append(page)
        notebook.selectedID = page.id
        return saveNotebook(notebook) ? notebook : nil
    }

    static func removePage(id: String) -> ScratchpadNotebook? {
        guard var notebook = loadNotebook(), notebook.pages.count > 1,
              let index = notebook.pages.firstIndex(where: { $0.id == id }) else { return nil }
        notebook.pages.remove(at: index)
        if notebook.selectedID == id { notebook.selectedID = notebook.pages[min(index, notebook.pages.count - 1)].id }
        return saveNotebook(notebook) ? notebook : nil
    }

    // Compatibility with the old one-note consumers while they migrate.
    static func load() -> String? {
        if let notebook = loadNotebook() { return notebook.selectedPage.text }
        return sharedDefaults?.string(forKey: legacyKey)
    }

    @discardableResult
    static func save(_ note: String) -> Bool {
        let notebook = migrateNotebook(legacy: note)
        return savePage(id: notebook.selectedID, text: note)
    }

    static func migrate(legacy: String?) -> String {
        migrateNotebook(legacy: legacy).selectedPage.text
    }
}

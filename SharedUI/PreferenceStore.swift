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

 
/// A single local note shared by the containing app and keyboard extension.
/// A shared App Group lets the companion app provide full-size editing and export
/// while the keyboard keeps its compact, offline scratchpad. No network involved.
enum ScratchpadStore {
    private static let key = "key-scratch.local-note.v1"

    private static var sharedDefaults: UserDefaults? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "OrtholinearAppGroup") as? String,
              !group.isEmpty else { return nil }
        return UserDefaults(suiteName: group)
    }

    /// Nil means the shared note has not yet been initialized or migrated.
    static func load() -> String? { sharedDefaults?.string(forKey: key) }

    @discardableResult
    static func save(_ note: String) -> Bool {
        guard let defaults = sharedDefaults else { return false }
        defaults.set(note, forKey: key)
        return true
    }

    /// Existing extension installations kept their note in extension-local
    /// defaults. Migrate once; never replace a shared note with stale local data.
    static func migrate(legacy: String?) -> String {
        if let shared = load() { return shared }
        let note = legacy ?? ""
        _ = save(note)
        return note
    }
}

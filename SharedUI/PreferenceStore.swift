import Foundation
import UIKit

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
        let removed = notebook.pages.remove(at: index)
        if notebook.selectedID == id { notebook.selectedID = notebook.pages[min(index, notebook.pages.count - 1)].id }
        guard saveNotebook(notebook) else { return nil }
        // Delete orphaned images only *after* the notebook commit succeeds.
        removed.images.forEach { ScratchpadImageStore.deleteFiles(for: $0.id) }
        return notebook
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


/// Photo files stay outside the lightweight notebook metadata record.
/// Both image sizes are local JPEGs: full image is bounded to 1200 px when
/// imported by the containing app, thumbnails to 180 px for the extension.
enum ScratchpadImageStore {
    enum Failure: Error, LocalizedError {
        case unavailable, noPage, pageFull, oversized, writeFailed

        var errorDescription: String? {
            switch self {
            case .unavailable: "Shared image storage is unavailable. Check App Group signing."
            case .noPage: "This scratchpad page is no longer available."
            case .pageFull: "This page already has twelve images."
            case .oversized: "The selected image is too large to keep in the keyboard."
            case .writeFailed: "The image could not be saved. Your existing photos were not changed."
            }
        }
    }

    private static var folder: URL? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "OrtholinearAppGroup") as? String,
              let root = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: group) else { return nil }
        return root.appendingPathComponent("ScratchpadImages", isDirectory: true)
    }

    static func imageURL(id: String, thumbnail: Bool = false) -> URL? {
        // Stored metadata never becomes an arbitrary path.
        guard UUID(uuidString: id) != nil, let folder else { return nil }
        return folder.appendingPathComponent((thumbnail ? "thumb-" : "") + id + ".jpg")
    }

    /// Import fully processed JPEG bytes supplied by the containing app.
    /// Write thumbnail and full image atomically, then update one page's
    /// metadata. Failed writes roll back without modifying the notebook.
    static func addImage(pageID: String, jpeg: Data, thumbnail: Data) throws -> ScratchpadNotebook {
        guard !jpeg.isEmpty, jpeg.count <= 2_000_000,
              !thumbnail.isEmpty, thumbnail.count <= 160_000 else {
            throw Failure.oversized
        }
        guard var notebook = ScratchpadStore.loadNotebook(),
              let index = notebook.pages.firstIndex(where: { $0.id == pageID }) else {
            throw Failure.noPage
        }
        guard notebook.pages[index].images.count < ScratchpadNotebook.maximumImagesPerPage
        else { throw Failure.pageFull }
        guard let folder else { throw Failure.unavailable }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let image = ScratchpadImage()
        guard let fullURL = imageURL(id: image.id),
              let smallURL = imageURL(id: image.id, thumbnail: true) else { throw Failure.unavailable }
        do {
            try jpeg.write(to: fullURL, options: .atomic)
            try thumbnail.write(to: smallURL, options: .atomic)
            notebook.pages[index].images.append(image)
            guard ScratchpadStore.saveNotebook(notebook) else { throw Failure.writeFailed }
            return notebook
        } catch {
            try? FileManager.default.removeItem(at: fullURL)
            try? FileManager.default.removeItem(at: smallURL)
            throw error
        }
    }

    /// Accept a picture the user explicitly copied in Photos, Safari,
    /// Files, etc. Keep it separate from note text, just like imports.
    /// The clipboard-provided UIImage is scaled to bounded JPEG bytes before
    /// any persistent write; originals on the clipboard are not modified.
    @MainActor
    static func addImage(pageID: String, from image: UIImage) throws -> ScratchpadNotebook {
        guard let full = makeJPEG(image, maxDimension: 1200, quality: 0.76),
              let thumbnail = makeJPEG(image, maxDimension: 180, quality: 0.66)
        else { throw Failure.writeFailed }

        // JPEG compression ratios vary widely; keep both files under the
        // same limits as PhotosPicker import without holding full-size files.
        let bounded: Data
        if full.count <= 2_000_000 {
            bounded = full
        } else if let fallback = makeJPEG(image, maxDimension: 960, quality: 0.60),
                  fallback.count <= 2_000_000 {
            bounded = fallback
        } else { throw Failure.oversized }
        guard thumbnail.count <= 160_000 else { throw Failure.oversized }
        return try addImage(pageID: pageID, jpeg: bounded, thumbnail: thumbnail)
    }

    @MainActor
    private static func makeJPEG(_ image: UIImage, maxDimension: CGFloat,
                                 quality: CGFloat) -> Data? {
        let size = image.size
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return nil }
        let ratio = min(1, maxDimension / max(size.width, size.height))
        let bounds = CGSize(width: max(1, (size.width * ratio).rounded()),
                            height: max(1, (size.height * ratio).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // never accidentally render at 2×/3× screen scale
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: bounds, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: bounds))
            image.draw(in: CGRect(origin: .zero, size: bounds))
        }
        return rendered.jpegData(compressionQuality: quality)
    }

    @discardableResult
    static func removeImage(pageID: String, id: String) -> ScratchpadNotebook? {
        guard var book = ScratchpadStore.loadNotebook(),
              let index = book.pages.firstIndex(where: { $0.id == pageID }),
              book.pages[index].images.contains(where: { $0.id == id }) else { return nil }
        book.pages[index].images.removeAll { $0.id == id }
        guard ScratchpadStore.saveNotebook(book) else { return nil }
        deleteFiles(for: id)
        return book
    }

    static func deleteFiles(for id: String) {
        for thumbnail in [true, false] {
            if let url = imageURL(id: id, thumbnail: thumbnail) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}

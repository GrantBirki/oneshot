import AppKit

final class PreviewDragPayload {
    private enum Defaults {
        static let cleanupDelay: TimeInterval = 20 * 60
        static let directoryName = "preview"
    }

    private let image: NSImage
    private let pngData: Data
    private let filename: String
    private let fileManager: FileManager
    private let workingDirectory: URL
    private let cleanupDelay: TimeInterval
    private var preparedFileURL: URL?
    private var cleanupWorkItem: DispatchWorkItem?

    init(
        image: NSImage,
        pngData: Data,
        filenamePrefix: String,
        fileManager: FileManager = .default,
        baseDirectory: URL? = nil,
        cleanupDelay: TimeInterval = Defaults.cleanupDelay,
        dateProvider: @escaping () -> Date = Date.init,
        uuidProvider: @escaping () -> UUID = UUID.init
    ) {
        self.image = image
        self.pngData = pngData
        self.fileManager = fileManager
        self.cleanupDelay = cleanupDelay
        let base = baseDirectory ?? PreviewDragPayload.defaultBaseDirectory(fileManager: fileManager)
        workingDirectory = base.appendingPathComponent(uuidProvider().uuidString, isDirectory: true)
        filename = FilenameFormatter.makeFilename(prefix: filenamePrefix, date: dateProvider())
    }

    func makeDraggingItem(dragFrame: NSRect) -> NSDraggingItem? {
        guard let pasteboardItem = makePasteboardItem() else { return nil }
        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(dragFrame, contents: image)
        return draggingItem
    }

    func makePasteboardItem() -> NSPasteboardItem? {
        guard let fileURL = ensureFileURL() else { return nil }

        let item = NSPasteboardItem()
        // Provide file URL + image data for broad drag-and-drop compatibility.
        item.setString(fileURL.absoluteString, forType: .fileURL)
        item.setData(pngData, forType: .png)
        if let tiffData = image.tiffRepresentation {
            item.setData(tiffData, forType: .tiff)
        }
        return item
    }

    func rescheduleCleanup() {
        guard preparedFileURL != nil else { return }
        scheduleCleanup()
    }

    private func ensureFileURL() -> URL? {
        if let preparedFileURL {
            if fileManager.fileExists(atPath: preparedFileURL.path) {
                return preparedFileURL
            }
            self.preparedFileURL = nil
        }

        do {
            let url = try FileSaveService.save(pngData: pngData, to: workingDirectory, filename: filename)
            preparedFileURL = url
            scheduleCleanup()
            return url
        } catch {
            NSLog("Failed to write drag preview file: \(error)")
            return nil
        }
    }

    private func scheduleCleanup() {
        cleanupWorkItem?.cancel()
        let fileURL = preparedFileURL
        let directoryURL = workingDirectory
        let manager = fileManager
        let workItem = DispatchWorkItem { [weak self] in
            if let fileURL {
                try? manager.removeItem(at: fileURL)
            }
            try? manager.removeItem(at: directoryURL)
            self?.preparedFileURL = nil
        }
        cleanupWorkItem = workItem
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + cleanupDelay, execute: workItem)
    }

    private static func defaultBaseDirectory(fileManager: FileManager) -> URL {
        let bundleID = Bundle.main.bundleIdentifier ?? "oneshot"
        return fileManager.temporaryDirectory
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(Defaults.directoryName, isDirectory: true)
    }
}

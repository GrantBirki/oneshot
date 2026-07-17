import AppKit
import UniformTypeIdentifiers

final class PreviewDragPayload: NSObject, NSFilePromiseProviderDelegate {
    private let image: NSImage
    private let pngData: Data
    private let filename: String
    private let writeQueue: OperationQueue

    init(
        image: NSImage,
        pngData: Data,
        filenamePrefix: String,
        dateProvider: @escaping () -> Date = Date.init,
    ) {
        self.image = image
        self.pngData = pngData
        filename = FilenameFormatter.makeFilename(prefix: filenamePrefix, date: dateProvider())
        writeQueue = OperationQueue()
        writeQueue.name = "com.grantbirki.oneshot.preview-file-promise"
        writeQueue.qualityOfService = .userInitiated
        writeQueue.maxConcurrentOperationCount = 1
        super.init()
    }

    func makeDraggingItem(dragFrame: NSRect) -> NSDraggingItem {
        let provider = NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: self)
        let draggingItem = NSDraggingItem(pasteboardWriter: provider)
        draggingItem.setDraggingFrame(dragFrame, contents: image)
        return draggingItem
    }

    func filePromiseProvider(_: NSFilePromiseProvider, fileNameForType _: String) -> String {
        filename
    }

    func filePromiseProvider(
        _: NSFilePromiseProvider,
        writePromiseTo destinationDirectory: URL,
        completionHandler: @escaping (Error?) -> Void,
    ) {
        do {
            let promisedURL = destinationDirectory.appendingPathComponent(filename)
            _ = try FileSaveService.save(pngData: pngData, toFile: promisedURL)
            completionHandler(nil)
        } catch {
            AppLog.preview.error("Failed to write promised preview file: \(String(describing: error), privacy: .private)")
            completionHandler(error)
        }
    }

    func operationQueue(for _: NSFilePromiseProvider) -> OperationQueue {
        writeQueue
    }
}

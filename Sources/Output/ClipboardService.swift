import AppKit

enum ClipboardService {
    static func copy(pngData: Data, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let tiffData = NSImage(data: pngData)?.tiffRepresentation
        var types: [NSPasteboard.PasteboardType] = [.png]
        if tiffData != nil {
            types.append(.tiff)
        }
        pasteboard.declareTypes(types, owner: nil)
        pasteboard.setData(pngData, forType: .png)
        if let tiffData = tiffData {
            pasteboard.setData(tiffData, forType: .tiff)
        }
    }
}

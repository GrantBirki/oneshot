import AppKit

@MainActor
enum UserErrorPresenter {
    static func show(
        title: String,
        message: String,
        primaryAction: (title: String, handler: () -> Void)? = nil,
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        if let primaryAction {
            alert.addButton(withTitle: primaryAction.title)
        }
        alert.addButton(withTitle: "OK")
        let response = alert.runModal()
        if primaryAction != nil, response == .alertFirstButtonReturn {
            primaryAction?.handler()
        }
        AccessibilityAnnouncer.announce("\(title). \(message)")
    }

    static func showCaptureFailure(_ message: String) {
        show(title: "Screenshot Failed", message: message)
    }
}

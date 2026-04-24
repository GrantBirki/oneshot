import AppKit

@MainActor
enum AccessibilityAnnouncer {
    static func announce(_ message: String) {
        NSAccessibility.post(
            element: NSApp ?? NSApplication.shared,
            notification: .announcementRequested,
            userInfo: [
                .announcement: message,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ],
        )
    }
}

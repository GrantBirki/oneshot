import AppKit

@MainActor
enum ScreenCapturePermission {
    static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
    )!

    static func ensureAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        let granted = CGRequestScreenCaptureAccess()
        if !granted {
            showPermissionAlert()
        }
        return granted
    }

    private static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Permission Required"
        alert.informativeText = "Enable screen recording access for OneShot in System Settings > " +
            "Privacy & Security > Screen Recording."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(screenRecordingSettingsURL)
        }
    }
}

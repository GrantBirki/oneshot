import Cocoa

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appController: AppController?
    private var terminationInProgress = false
    private var previousTerminationFailed = false

    func applicationDidFinishLaunching(_: Notification) {
        AppLog.app.info("OneShot did finish launching")
        appController = AppController(launchContext: .current())
        appController?.start()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        appController?.showSettings()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let appController else { return .terminateNow }
        guard !terminationInProgress else { return .terminateLater }

        if previousTerminationFailed, appController.hasPendingTerminationWork {
            let alert = NSAlert()
            alert.messageText = "Quit and discard the unsaved screenshot?"
            alert.informativeText = "OneShot could not safely finish the pending screenshot. Quitting now may discard it."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Quit Anyway")
            if alert.runModal() == .alertSecondButtonReturn {
                appController.stop()
                return .terminateNow
            }
            return .terminateCancel
        }
        previousTerminationFailed = false

        terminationInProgress = true
        Task { @MainActor [weak self, weak sender] in
            guard let self else { return }
            let safeToTerminate = await appController.prepareForTermination()
            terminationInProgress = false
            previousTerminationFailed = !safeToTerminate
            sender?.reply(toApplicationShouldTerminate: safeToTerminate)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_: Notification) {
        appController?.stop()
    }
}

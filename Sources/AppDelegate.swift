import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appController: AppController?

    func applicationDidFinishLaunching(_: Notification) {
        NSLog("OneShot did finish launching")
        appController = AppController()
        appController?.start()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        appController?.showSettings()
        return false
    }
}

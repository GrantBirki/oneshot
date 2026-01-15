import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appController: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("OneShot did finish launching")
        appController = AppController()
        appController?.start()
    }
}

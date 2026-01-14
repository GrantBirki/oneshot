import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appController: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("OpenShot did finish launching")
        appController = AppController()
        appController?.start()
    }
}

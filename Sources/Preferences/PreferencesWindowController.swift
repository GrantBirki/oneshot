import Cocoa
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    init(settings: SettingsStore) {
        let view = PreferencesView(settings: settings)
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "OneShot Preferences"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 560, height: 480))
        window.isReleasedWhenClosed = false
        super.init(window: window)
    }

    required init?(coder _: NSCoder) {
        return nil
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(nil)
        }
    }
}

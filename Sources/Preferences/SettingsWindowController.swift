import Cocoa
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private static let frameAutosaveName = "OneShotSettingsWindow"

    private let navigation: SettingsNavigation
    private var shouldCenterOnFirstShow: Bool

    init(
        settings: SettingsStore,
        openLoginItems: @escaping () -> Void = LaunchAtLoginManager.openSystemSettingsLoginItems,
        launchAtLoginStatusProvider: @escaping () -> LaunchAtLoginStatus = { LaunchAtLoginManager().status },
    ) {
        let navigation = SettingsNavigation()
        let view = SettingsView(
            settings: settings,
            navigation: navigation,
            openLoginItems: openLoginItems,
            launchAtLoginStatusProvider: launchAtLoginStatusProvider,
        )
        let hosting = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: hosting)
        window.title = "OneShot Settings"
        window.styleMask = [.titled, .closable, .resizable]
        window.contentMinSize = NSSize(width: 620, height: 460)
        window.setContentSize(NSSize(width: 680, height: 520))
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName(Self.frameAutosaveName)
        self.navigation = navigation
        shouldCenterOnFirstShow = !window.setFrameUsingName(Self.frameAutosaveName)
        super.init(window: window)
    }

    required init?(coder _: NSCoder) {
        nil
    }

    func show(tab: SettingsTab? = nil) {
        if let tab {
            navigation.selectedTab = tab
        }
        if shouldCenterOnFirstShow {
            window?.center()
            shouldCenterOnFirstShow = false
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(nil)
        }
    }

    func showAbout() {
        show(tab: .about)
    }
}

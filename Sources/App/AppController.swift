import Cocoa
import Combine

@MainActor
final class AppController {
    private let settings: SettingsStore
    private let hotkeyManager: HotkeyManager
    private let captureManager: CaptureManager
    private let menuBarController: MenuBarController
    private let settingsWindowController: SettingsWindowController
    private let aboutWindowController: AboutWindowController
    private let launchAtLoginManager: LaunchAtLoginManager
    private var cancellables = Set<AnyCancellable>()

    init() {
        settings = SettingsStore()
        hotkeyManager = HotkeyManager()
        captureManager = CaptureManager(settings: settings)
        settingsWindowController = SettingsWindowController(settings: settings)
        aboutWindowController = AboutWindowController()
        launchAtLoginManager = LaunchAtLoginManager()

        menuBarController = MenuBarController(
            onCaptureSelection: { [weak captureManager] in captureManager?.captureSelection() },
            onCaptureFullScreen: { [weak captureManager] in captureManager?.captureFullScreen() },
            onCaptureWindow: { [weak captureManager] in captureManager?.captureWindow() },
            onCaptureScrolling: { [weak captureManager] in captureManager?.captureScrolling() },
            onAbout: { [weak aboutWindowController] in aboutWindowController?.show() },
            onSettings: { [weak settingsWindowController] in settingsWindowController?.show() },
            onQuit: { NSApp.terminate(nil) },
            hotkeyProvider: { [weak settings] in
                MenuBarController.HotkeyBindings(
                    selection: settings?.hotkeySelection,
                    fullScreen: settings?.hotkeyFullScreen,
                    window: settings?.hotkeyWindow,
                    scrolling: settings?.hotkeyScrolling,
                )
            },
        )

        captureManager.onScrollingCaptureStateChange = { [weak menuBarController] isActive in
            menuBarController?.setScrollingCaptureActive(isActive)
        }
    }

    func start() {
        AppLog.app.info("OneShot AppController start")
        menuBarController.start()
        menuBarController.setVisible(!settings.menuBarIconHidden)
        registerHotkeys()
        observeSettings()
        launchAtLoginManager.setEnabled(settings.autoLaunchEnabled)
        maybeShowSettingsOnLaunch()
    }

    func showSettings() {
        settingsWindowController.show()
    }

    private func observeSettings() {
        settings.$autoLaunchEnabled
            .sink { [weak self] enabled in
                self?.launchAtLoginManager.setEnabled(enabled)
            }
            .store(in: &cancellables)

        settings.$menuBarIconHidden
            .sink { [weak self] hidden in
                self?.menuBarController.setVisible(!hidden)
            }
            .store(in: &cancellables)

        settings.$hotkeySelection
            .sink { [weak self] _ in self?.registerHotkeys() }
            .store(in: &cancellables)
        settings.$hotkeyFullScreen
            .sink { [weak self] _ in self?.registerHotkeys() }
            .store(in: &cancellables)
        settings.$hotkeyWindow
            .sink { [weak self] _ in self?.registerHotkeys() }
            .store(in: &cancellables)
        settings.$hotkeyScrolling
            .sink { [weak self] _ in self?.registerHotkeys() }
            .store(in: &cancellables)
    }

    private func maybeShowSettingsOnLaunch() {
        if settings.menuBarIconHidden {
            settingsWindowController.show()
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if NSApp.isActive {
                settingsWindowController.show()
            }
        }
    }

    private func registerHotkeys() {
        hotkeyManager.unregisterAll()

        if let selectionHotkey = settings.hotkeySelection, selectionHotkey.isValid {
            AppLog.hotkeys.debug("Registering selection hotkey: \(selectionHotkey.displayString, privacy: .public)")
            hotkeyManager.register(hotkey: selectionHotkey) { [weak self] in
                self?.captureManager.captureSelection()
            }
        } else {
            AppLog.hotkeys.debug("Selection hotkey not set or invalid")
        }

        if let fullScreenHotkey = settings.hotkeyFullScreen, fullScreenHotkey.isValid {
            AppLog.hotkeys.debug("Registering full screen hotkey: \(fullScreenHotkey.displayString, privacy: .public)")
            hotkeyManager.register(hotkey: fullScreenHotkey) { [weak self] in
                self?.captureManager.captureFullScreen()
            }
        } else {
            AppLog.hotkeys.debug("Full screen hotkey not set or invalid")
        }

        if let windowHotkey = settings.hotkeyWindow, windowHotkey.isValid {
            AppLog.hotkeys.debug("Registering window hotkey: \(windowHotkey.displayString, privacy: .public)")
            hotkeyManager.register(hotkey: windowHotkey) { [weak self] in
                self?.captureManager.captureWindow()
            }
        } else {
            AppLog.hotkeys.debug("Window hotkey not set or invalid")
        }

        if let scrollingHotkey = settings.hotkeyScrolling, scrollingHotkey.isValid {
            AppLog.hotkeys.debug("Registering scrolling hotkey: \(scrollingHotkey.displayString, privacy: .public)")
            hotkeyManager.register(hotkey: scrollingHotkey) { [weak self] in
                self?.captureManager.captureScrolling()
            }
        } else {
            AppLog.hotkeys.debug("Scrolling hotkey not set or invalid")
        }

        menuBarController.refreshHotkeys()
    }
}

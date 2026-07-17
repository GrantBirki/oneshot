import Cocoa
import Combine

enum LaunchContext: Equatable, Sendable {
    case foreground
    case loginItem

    static func current(event: NSAppleEventDescriptor? = NSAppleEventManager.shared().currentAppleEvent) -> LaunchContext {
        let descriptor = event?.paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem))
        return descriptor?.booleanValue == true ? .loginItem : .foreground
    }
}

@MainActor
final class AppController {
    private let settings: SettingsStore
    private let hotkeyManager: HotkeyManager
    private let captureManager: CaptureManager
    private let menuBarController: MenuBarController
    private let settingsWindowController: SettingsWindowController
    private let launchAtLoginManager: LaunchAtLoginManager
    private let launchContext: LaunchContext
    private var cancellables = Set<AnyCancellable>()

    init(launchContext: LaunchContext = .current()) {
        self.launchContext = launchContext
        settings = SettingsStore()
        hotkeyManager = HotkeyManager()
        captureManager = CaptureManager(settings: settings)
        settingsWindowController = SettingsWindowController(settings: settings)
        launchAtLoginManager = LaunchAtLoginManager()

        menuBarController = MenuBarController(
            onCaptureSelection: { [weak captureManager] in captureManager?.captureSelection() },
            onCaptureFullScreen: { [weak captureManager] in captureManager?.captureFullScreen() },
            onCaptureWindow: { [weak captureManager] in captureManager?.captureWindow() },
            onCaptureScrolling: { [weak captureManager] in captureManager?.captureScrolling() },
            onAbout: { [weak settingsWindowController] in settingsWindowController?.showAbout() },
            onSettings: { [weak settingsWindowController] in settingsWindowController?.show() },
            onQuit: { NSApp.terminate(nil) },
            hotkeyProvider: { [weak settings] in
                guard let settings else {
                    return MenuBarController.HotkeyBindings(
                        selection: nil,
                        fullScreen: nil,
                        window: nil,
                        scrolling: nil,
                    )
                }
                return MenuBarController.HotkeyBindings(
                    selection: settings.hotkeyRegistrationStatuses[.selection] == .registered
                        ? settings.hotkeySelection : nil,
                    fullScreen: settings.hotkeyRegistrationStatuses[.fullScreen] == .registered
                        ? settings.hotkeyFullScreen : nil,
                    window: settings.hotkeyRegistrationStatuses[.window] == .registered
                        ? settings.hotkeyWindow : nil,
                    scrolling: settings.hotkeyRegistrationStatuses[.scrolling] == .registered
                        ? settings.hotkeyScrolling : nil,
                )
            },
        )

        captureManager.onScrollingCaptureStateChange = { [weak menuBarController] isActive in
            menuBarController?.setScrollingCaptureActive(isActive)
        }
    }

    func start() {
        AppLog.app.info("OneShot AppController start")
        menuBarController.setVisible(!settings.menuBarIconHidden)
        menuBarController.start()
        observeSettings()
        maybeShowSettingsOnLaunch()
    }

    func showSettings() {
        settingsWindowController.show()
    }

    func prepareForTermination() async -> Bool {
        await captureManager.prepareForTermination()
    }

    var hasPendingTerminationWork: Bool {
        captureManager.hasPendingTerminationWork
    }

    func stop() {
        cancellables.removeAll()
        captureManager.cleanup()
        hotkeyManager.shutdown()
    }

    private func observeSettings() {
        settings.$autoLaunchEnabled
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                let result = launchAtLoginManager.setEnabled(enabled)
                settings.applyLaunchAtLoginResult(result)
            }
            .store(in: &cancellables)

        settings.$menuBarIconHidden
            .removeDuplicates()
            .sink { [weak self] hidden in
                self?.menuBarController.setVisible(!hidden)
            }
            .store(in: &cancellables)

        settings.hotkeyConfigurationPublisher
            .sink { [weak self] configuration in
                self?.registerHotkeys(configuration)
            }
            .store(in: &cancellables)
    }

    private func maybeShowSettingsOnLaunch() {
        guard launchContext == .foreground else { return }
        settingsWindowController.show()
    }

    private func registerHotkeys(_ configuration: HotkeyConfiguration) {
        let handlers = HotkeyHandlers(
            selection: { [weak self] in self?.captureManager.captureSelection() },
            scrolling: { [weak self] in self?.captureManager.captureScrolling() },
            window: { [weak self] in self?.captureManager.captureWindow() },
            fullScreen: { [weak self] in self?.captureManager.captureFullScreen() },
        )
        let statuses = hotkeyManager.replaceRegistrations(configuration: configuration, handlers: handlers)
        settings.updateHotkeyRegistrationStatuses(statuses)
        menuBarController.refreshHotkeys()
    }
}

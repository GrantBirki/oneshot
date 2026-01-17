import Cocoa

final class MenuBarController: NSObject, NSMenuDelegate {
    struct HotkeyBindings {
        let selection: Hotkey?
        let fullScreen: Hotkey?
        let window: Hotkey?
    }

    private let statusItem: NSStatusItem
    private let onCaptureSelection: () -> Void
    private let onCaptureFullScreen: () -> Void
    private let onCaptureWindow: () -> Void
    private let onAbout: () -> Void
    private let onSettings: () -> Void
    private let onQuit: () -> Void
    private let hotkeyProvider: () -> HotkeyBindings
    private var menu: NSMenu?
    private let selectionItem: NSMenuItem
    private let windowItem: NSMenuItem
    private let fullScreenItem: NSMenuItem
    private let aboutItem: NSMenuItem

    init(
        onCaptureSelection: @escaping () -> Void,
        onCaptureFullScreen: @escaping () -> Void,
        onCaptureWindow: @escaping () -> Void,
        onAbout: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        hotkeyProvider: @escaping () -> HotkeyBindings,
    ) {
        self.onCaptureSelection = onCaptureSelection
        self.onCaptureFullScreen = onCaptureFullScreen
        self.onCaptureWindow = onCaptureWindow
        self.onAbout = onAbout
        self.onSettings = onSettings
        self.onQuit = onQuit
        self.hotkeyProvider = hotkeyProvider
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        selectionItem = NSMenuItem(
            title: "Capture Selection",
            action: #selector(captureSelection),
            keyEquivalent: "",
        )
        windowItem = NSMenuItem(
            title: "Capture Window",
            action: #selector(captureWindow),
            keyEquivalent: "",
        )
        fullScreenItem = NSMenuItem(
            title: "Capture Full Screen",
            action: #selector(captureFullScreen),
            keyEquivalent: "",
        )
        aboutItem = NSMenuItem(
            title: "About OneShot",
            action: #selector(openAbout),
            keyEquivalent: "",
        )
        super.init()

        selectionItem.target = self
        windowItem.target = self
        fullScreenItem.target = self
        aboutItem.target = self
    }

    func start() {
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "OneShot") {
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "OneShot"
            }
        } else {
            NSLog("Status item button unavailable")
        }
        let menu = buildMenu()
        menu.delegate = self
        statusItem.menu = menu
        self.menu = menu
        refreshHotkeys()
        NSLog("Menu bar item started")
    }

    func setVisible(_ isVisible: Bool) {
        statusItem.isVisible = isVisible
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(selectionItem)

        menu.addItem(windowItem)

        menu.addItem(fullScreenItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: "",
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit OneShot",
            action: #selector(quit),
            keyEquivalent: "q",
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    func refreshHotkeys() {
        let values = hotkeyProvider()
        updateHotkeys(
            selection: values.selection,
            fullScreen: values.fullScreen,
            window: values.window,
        )
    }

    func menuNeedsUpdate(_: NSMenu) {
        refreshHotkeys()
    }

    private func updateHotkeys(selection: Hotkey?, fullScreen: Hotkey?, window: Hotkey?) {
        applyHotkey(selection, to: selectionItem)
        applyHotkey(fullScreen, to: fullScreenItem)
        applyHotkey(window, to: windowItem)
    }

    private func applyHotkey(_ value: Hotkey?, to item: NSMenuItem) {
        guard let hotkey = value,
              let keyEquivalent = HotkeyFormatter.keyEquivalent(for: hotkey.keyCode)
        else {
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
            return
        }
        item.keyEquivalent = keyEquivalent
        item.keyEquivalentModifierMask = hotkey.modifiers
    }

    @objc private func captureSelection() {
        onCaptureSelection()
    }

    @objc private func captureWindow() {
        onCaptureWindow()
    }

    @objc private func captureFullScreen() {
        onCaptureFullScreen()
    }

    @objc private func openSettings() {
        onSettings()
    }

    @objc private func openAbout() {
        onAbout()
    }

    @objc private func quit() {
        onQuit()
    }
}

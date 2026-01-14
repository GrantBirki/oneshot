import Cocoa

final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let onCaptureSelection: () -> Void
    private let onCaptureFullScreen: () -> Void
    private let onCaptureWindow: () -> Void
    private let onPreferences: () -> Void
    private let onQuit: () -> Void
    private let hotkeyProvider: () -> (selection: String, fullScreen: String, window: String)
    private var menu: NSMenu?
    private let selectionItem: NSMenuItem
    private let windowItem: NSMenuItem
    private let fullScreenItem: NSMenuItem

    init(
        onCaptureSelection: @escaping () -> Void,
        onCaptureFullScreen: @escaping () -> Void,
        onCaptureWindow: @escaping () -> Void,
        onPreferences: @escaping () -> Void,
        onQuit: @escaping () -> Void,
        hotkeyProvider: @escaping () -> (selection: String, fullScreen: String, window: String)
    ) {
        self.onCaptureSelection = onCaptureSelection
        self.onCaptureFullScreen = onCaptureFullScreen
        self.onCaptureWindow = onCaptureWindow
        self.onPreferences = onPreferences
        self.onQuit = onQuit
        self.hotkeyProvider = hotkeyProvider
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        selectionItem = NSMenuItem(title: "Capture Selection", action: #selector(captureSelection), keyEquivalent: "")
        windowItem = NSMenuItem(title: "Capture Window", action: #selector(captureWindow), keyEquivalent: "")
        fullScreenItem = NSMenuItem(title: "Capture Full Screen", action: #selector(captureFullScreen), keyEquivalent: "")
        super.init()

        selectionItem.target = self
        windowItem.target = self
        fullScreenItem.target = self
    }

    func start() {
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "OpenShot") {
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "OpenShot"
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

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        menu.addItem(selectionItem)

        menu.addItem(windowItem)

        menu.addItem(fullScreenItem)

        menu.addItem(.separator())

        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit OpenShot",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    func refreshHotkeys() {
        let values = hotkeyProvider()
        updateHotkeys(selection: values.selection, fullScreen: values.fullScreen, window: values.window)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshHotkeys()
    }

    private func updateHotkeys(selection: String, fullScreen: String, window: String) {
        applyHotkey(selection, to: selectionItem)
        applyHotkey(fullScreen, to: fullScreenItem)
        applyHotkey(window, to: windowItem)
        menu?.update()
    }

    private func applyHotkey(_ value: String, to item: NSMenuItem) {
        guard let shortcut = MenuBarController.menuShortcut(from: value) else {
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
            return
        }
        item.keyEquivalent = shortcut.key
        item.keyEquivalentModifierMask = shortcut.modifiers
    }

    private static func menuShortcut(from value: String) -> (key: String, modifiers: NSEvent.ModifierFlags)? {
        let cleaned = value
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        if cleaned.isEmpty {
            return nil
        }

        let parts = cleaned.split(separator: "+").map(String.init)
        var modifiers: NSEvent.ModifierFlags = []
        var key: String?

        for part in parts {
            switch part {
            case "ctrl", "control":
                modifiers.insert(.control)
            case "shift":
                modifiers.insert(.shift)
            case "alt", "option":
                modifiers.insert(.option)
            case "cmd", "command":
                modifiers.insert(.command)
            default:
                key = part
            }
        }

        guard let key = key, KeyCodeMapper.keyCode(for: key) != nil else {
            return nil
        }
        return (key: key, modifiers: modifiers)
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

    @objc private func openPreferences() {
        onPreferences()
    }

    @objc private func quit() {
        onQuit()
    }
}

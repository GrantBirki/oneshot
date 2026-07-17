import Carbon.HIToolbox
import Foundation

final class HotkeyManager {
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 100
    private var eventHandlerRef: EventHandlerRef?
    private var eventHandlerInstallStatus: OSStatus = noErr

    init() {
        installHandlerIfNeeded()
    }

    deinit {
        shutdown()
    }

    @discardableResult
    func register(hotkey: Hotkey, handler: @escaping () -> Void) -> HotkeyRegistrationStatus {
        let id = nextID
        nextID += 1

        return register(hotkey: hotkey, id: id, handler: handler)
    }

    func replaceRegistrations(
        configuration: HotkeyConfiguration,
        handlers: HotkeyHandlers,
    ) -> [HotkeyAction: HotkeyRegistrationStatus] {
        unregisterAll()

        var statuses: [HotkeyAction: HotkeyRegistrationStatus] = [:]
        let duplicateActions = duplicateActions(in: configuration)

        for action in HotkeyAction.registrationOrder {
            guard let hotkey = configuration[action] else {
                statuses[action] = .notConfigured
                continue
            }
            guard hotkey.isValid else {
                statuses[action] = .invalid
                continue
            }
            if let duplicate = duplicateActions[action] {
                statuses[action] = .duplicate(duplicate)
                continue
            }

            statuses[action] = register(
                hotkey: hotkey,
                id: action.registrationID,
                handler: handlers[action],
            )
        }

        return statuses
    }

    func shutdown() {
        unregisterAll()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    static func status(forRegistrationResult status: OSStatus, hasReference: Bool) -> HotkeyRegistrationStatus {
        status == noErr && hasReference ? .registered : .unavailable(status)
    }

    private func register(
        hotkey: Hotkey,
        id: UInt32,
        handler: @escaping () -> Void,
    ) -> HotkeyRegistrationStatus {
        guard hotkey.isValid else {
            return .invalid
        }
        guard eventHandlerRef != nil else {
            return .unavailable(eventHandlerInstallStatus)
        }

        let hotKeyID = EventHotKeyID(signature: HotkeyManager.signature, id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            hotkey.carbonKeyCode,
            hotkey.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef,
        )

        let registrationStatus = Self.status(forRegistrationResult: status, hasReference: hotKeyRef != nil)
        guard case .registered = registrationStatus, let ref = hotKeyRef else {
            AppLog.hotkeys.error(
                "Hotkey register failed (\(status, privacy: .public)) for \(hotkey.displayString, privacy: .public)",
            )
            return registrationStatus
        }

        hotKeyRefs[id] = ref
        handlers[id] = handler
        AppLog.hotkeys.info("Hotkey registered: \(hotkey.displayString, privacy: .public)")
        return .registered
    }

    func unregisterAll() {
        for ref in hotKeyRefs.values {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        handlers.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            HotkeyManager.eventHandler,
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef,
        )

        if status != noErr {
            eventHandlerInstallStatus = status
            eventHandlerRef = nil
        }
    }

    private func duplicateActions(in configuration: HotkeyConfiguration) -> [HotkeyAction: HotkeyAction] {
        var firstActionForHotkey: [Hotkey: HotkeyAction] = [:]
        var duplicates: [HotkeyAction: HotkeyAction] = [:]

        for action in HotkeyAction.registrationOrder {
            guard let hotkey = configuration[action], hotkey.isValid else { continue }
            if let firstAction = firstActionForHotkey[hotkey] {
                duplicates[firstAction] = action
                duplicates[action] = firstAction
            } else {
                firstActionForHotkey[hotkey] = action
            }
        }

        return duplicates
    }

    private func handleHotKey(id: UInt32) {
        handlers[id]?()
    }

    private static let signature: OSType = 0x4F53_484B // "OSHK"

    private static let eventHandler: EventHandlerUPP = { _, eventRef, userData in
        guard let eventRef, let userData else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            eventRef,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID,
        )

        if status == noErr, hotKeyID.signature == HotkeyManager.signature {
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.handleHotKey(id: hotKeyID.id)
        }

        return noErr
    }
}

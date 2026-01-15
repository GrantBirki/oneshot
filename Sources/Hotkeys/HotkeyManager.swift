import Carbon.HIToolbox
import Foundation

final class HotkeyManager {
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?

    init() {
        installHandlerIfNeeded()
    }

    func register(hotkey: Hotkey, handler: @escaping () -> Void) {
        let id = nextID
        nextID += 1

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

        guard status == noErr, let ref = hotKeyRef else {
            NSLog("Hotkey registration failed (\(status)) for \(hotkey.displayString)")
            return
        }

        hotKeyRefs[id] = ref
        handlers[id] = handler
        NSLog("Hotkey registered: \(hotkey.displayString)")
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
            eventHandlerRef = nil
        }
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

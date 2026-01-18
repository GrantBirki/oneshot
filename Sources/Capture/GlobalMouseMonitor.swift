import AppKit
import os.log

final class GlobalMouseMonitor {
    private let tapFactory: (HandlerWrapper) -> (CFMachPort, CFRunLoopSource)?
    private let addSource: (CFRunLoopSource) -> Void
    private let removeSource: (CFRunLoopSource) -> Void
    private let handler: (CGPoint) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var handlerWrapper: HandlerWrapper?
    #if DEBUG
    private static let log = OSLog(subsystem: "com.grantbirki.oneshot", category: "GlobalMouseMonitor")
    #endif

    final class HandlerWrapper {
        private let handler: (CGPoint) -> Void
        #if DEBUG
        private var eventCount = 0
        #endif

        init(handler: @escaping (CGPoint) -> Void) {
            self.handler = handler
        }

        func handle(event: CGEvent) {
            #if DEBUG
            eventCount += 1
            if eventCount <= 3 {
                os_log("mouse event %{public}@", log: GlobalMouseMonitor.log, type: .debug, "\(event.location)")
            }
            #endif
            if let nsEvent = NSEvent(cgEvent: event) {
                DispatchQueue.main.async {
                    self.handler(nsEvent.locationInWindow)
                }
                return
            }
            DispatchQueue.main.async {
                self.handler(event.location)
            }
        }
    }

    init(
        tapFactory: @escaping (HandlerWrapper) -> (CFMachPort, CFRunLoopSource)? = GlobalMouseMonitor.defaultTapFactory,
        addSource: @escaping (CFRunLoopSource) -> Void = GlobalMouseMonitor.defaultAddSource,
        removeSource: @escaping (CFRunLoopSource) -> Void = GlobalMouseMonitor.defaultRemoveSource,
        handler: @escaping (CGPoint) -> Void
    ) {
        self.tapFactory = tapFactory
        self.addSource = addSource
        self.removeSource = removeSource
        self.handler = handler
    }

    func start() {
        guard tap == nil else { return }
        let wrapper = HandlerWrapper(handler: handler)
        guard let (tap, source) = tapFactory(wrapper) else { return }
        self.tap = tap
        self.source = source
        handlerWrapper = wrapper
        addSource(source)
        CGEvent.tapEnable(tap: tap, enable: true)
        #if DEBUG
        os_log("event tap started", log: GlobalMouseMonitor.log, type: .debug)
        #endif
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            removeSource(source)
        }
        tap = nil
        source = nil
        handlerWrapper = nil
        #if DEBUG
        os_log("event tap stopped", log: GlobalMouseMonitor.log, type: .debug)
        #endif
    }

    private static func defaultTapFactory(_ wrapper: HandlerWrapper) -> (CFMachPort, CFRunLoopSource)? {
        let mask = CGEventMask(
            (1 << CGEventType.mouseMoved.rawValue)
                | (1 << CGEventType.leftMouseDragged.rawValue)
        )
        let callback: CGEventTapCallBack = { _, _, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let wrapper = Unmanaged<HandlerWrapper>.fromOpaque(userInfo).takeUnretainedValue()
            wrapper.handle(event: event)
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(wrapper).toOpaque())
        ) else {
            return nil
        }
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return nil
        }
        return (tap, source)
    }

    private static func defaultAddSource(_ source: CFRunLoopSource) {
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    }

    private static func defaultRemoveSource(_ source: CFRunLoopSource) {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
    }
}

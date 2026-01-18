import AppKit
@testable import OneShot
import XCTest

final class GlobalMouseMonitorTests: XCTestCase {
    func testStartRegistersOnce() {
        var factoryCount = 0
        var addCount = 0
        let tap = CFMachPortCreate(kCFAllocatorDefault, { _, _, _, _ in }, nil, nil)
        let source = tap.flatMap { CFMachPortCreateRunLoopSource(kCFAllocatorDefault, $0, 0) }

        let monitor = GlobalMouseMonitor(
            tapFactory: { _ in
                factoryCount += 1
                if let tap, let source {
                    return (tap, source)
                }
                return nil
            },
            addSource: { _ in addCount += 1 },
            removeSource: { _ in },
            handler: { _ in }
        )

        monitor.start()
        monitor.start()

        XCTAssertEqual(factoryCount, 1)
        XCTAssertEqual(addCount, 1)
    }

    func testStopRemovesOnce() {
        var removeCount = 0
        let tap = CFMachPortCreate(kCFAllocatorDefault, { _, _, _, _ in }, nil, nil)
        let source = tap.flatMap { CFMachPortCreateRunLoopSource(kCFAllocatorDefault, $0, 0) }

        let monitor = GlobalMouseMonitor(
            tapFactory: { _ in
                if let tap, let source {
                    return (tap, source)
                }
                return nil
            },
            addSource: { _ in },
            removeSource: { _ in removeCount += 1 },
            handler: { _ in }
        )

        monitor.start()
        monitor.stop()
        monitor.stop()

        XCTAssertEqual(removeCount, 1)
    }
}

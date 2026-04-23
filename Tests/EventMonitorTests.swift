@testable import OneShot
import XCTest

final class EventMonitorTests: XCTestCase {
    func testCancelRemovesMonitorOnce() {
        let token = NSObject()
        var removed: [AnyObject] = []
        let monitor = EventMonitor(token) { removed.append($0 as AnyObject) }

        monitor.cancel()
        monitor.cancel()

        XCTAssertEqual(removed.count, 1)
        XCTAssertTrue(removed[0] === token)
        XCTAssertFalse(monitor.isActive)
    }

    func testDeinitRemovesActiveMonitor() {
        let token = NSObject()
        var removed: [AnyObject] = []
        var monitor: EventMonitor? = EventMonitor(token) { removed.append($0 as AnyObject) }

        XCTAssertEqual(monitor?.isActive, true)
        monitor = nil

        XCTAssertEqual(removed.count, 1)
        XCTAssertTrue(removed[0] === token)
    }
}

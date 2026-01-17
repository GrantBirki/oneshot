@testable import OneShot
import XCTest

final class CursorStackTests: XCTestCase {
    func testPushCrosshairOnlyPushesOnce() {
        var pushCount = 0
        let stack = CursorStack(pushHandler: { pushCount += 1 }, popHandler: {})

        stack.pushCrosshair()
        stack.pushCrosshair()

        XCTAssertEqual(pushCount, 1)
    }

    func testPopDoesNothingWithoutPush() {
        var popCount = 0
        let stack = CursorStack(pushHandler: {}, popHandler: { popCount += 1 })

        stack.pop()

        XCTAssertEqual(popCount, 0)
    }

    func testPushPopSequenceRestoresState() {
        var pushCount = 0
        var popCount = 0
        let stack = CursorStack(
            pushHandler: { pushCount += 1 },
            popHandler: { popCount += 1 },
        )

        stack.pushCrosshair()
        stack.pop()
        stack.pop()
        stack.pushCrosshair()

        XCTAssertEqual(pushCount, 2)
        XCTAssertEqual(popCount, 1)
    }
}

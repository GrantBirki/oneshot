@testable import OneShot
import ServiceManagement
import XCTest

final class LaunchAtLoginManagerTests: XCTestCase {
    func testAlreadyEnabledDoesNotRegisterAgain() {
        let service = FakeLaunchAtLoginService(status: .enabled)
        let manager = LaunchAtLoginManager(service: service)

        XCTAssertEqual(manager.setEnabled(true), .enabled(changed: false))
        XCTAssertEqual(service.registerCount, 0)
    }

    func testRegisterReportsEnabledState() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        service.statusAfterRegister = .enabled
        let manager = LaunchAtLoginManager(service: service)

        XCTAssertEqual(manager.setEnabled(true), .enabled(changed: true))
        XCTAssertEqual(service.registerCount, 1)
    }

    func testRegisterReportsRequiredApproval() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        service.statusAfterRegister = .requiresApproval
        let manager = LaunchAtLoginManager(service: service)

        XCTAssertEqual(manager.setEnabled(true), .requiresApproval)
        XCTAssertEqual(manager.status, .requiresApproval)
    }

    func testRegistrationFailureReportsActualState() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)
        service.registerError = TestError.expected
        let manager = LaunchAtLoginManager(service: service)

        XCTAssertEqual(manager.setEnabled(true), .failed(actualStatus: .disabled))
    }

    func testDisableUnregistersEnabledService() {
        let service = FakeLaunchAtLoginService(status: .enabled)
        service.statusAfterUnregister = .notRegistered
        let manager = LaunchAtLoginManager(service: service)

        XCTAssertEqual(manager.setEnabled(false), .disabled(changed: true))
        XCTAssertEqual(service.unregisterCount, 1)
    }

    func testMissingServiceReportsUnavailableState() {
        let service = FakeLaunchAtLoginService(status: .notFound)
        let manager = LaunchAtLoginManager(service: service)

        XCTAssertEqual(manager.setEnabled(false), .failed(actualStatus: .unavailable))
    }

    func testSystemStatusesMapToPresentationStatuses() {
        XCTAssertEqual(LaunchAtLoginManager.status(for: .notRegistered), .disabled)
        XCTAssertEqual(LaunchAtLoginManager.status(for: .enabled), .enabled)
        XCTAssertEqual(LaunchAtLoginManager.status(for: .requiresApproval), .requiresApproval)
        XCTAssertEqual(LaunchAtLoginManager.status(for: .notFound), .unavailable)
    }
}

private final class FakeLaunchAtLoginService: LaunchAtLoginServicing {
    var status: SMAppService.Status
    var statusAfterRegister: SMAppService.Status?
    var statusAfterUnregister: SMAppService.Status?
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCount += 1
        if let registerError {
            throw registerError
        }
        if let statusAfterRegister {
            status = statusAfterRegister
        }
    }

    func unregister() throws {
        unregisterCount += 1
        if let unregisterError {
            throw unregisterError
        }
        if let statusAfterUnregister {
            status = statusAfterUnregister
        }
    }
}

private enum TestError: Error {
    case expected
}

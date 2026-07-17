import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case unknown
    case disabled
    case enabled
    case requiresApproval
    case unavailable

    var isRequestedEnabled: Bool {
        self == .enabled || self == .requiresApproval
    }
}

enum LaunchAtLoginUpdateResult: Equatable {
    case enabled(changed: Bool)
    case disabled(changed: Bool)
    case requiresApproval
    case failed(actualStatus: LaunchAtLoginStatus)

    var status: LaunchAtLoginStatus {
        switch self {
        case .enabled:
            .enabled
        case .disabled:
            .disabled
        case .requiresApproval:
            .requiresApproval
        case let .failed(actualStatus):
            actualStatus
        }
    }

    var message: String? {
        switch self {
        case .enabled,
             .disabled:
            nil
        case .requiresApproval:
            "Approval is required in System Settings."
        case .failed:
            "OneShot couldn’t update the launch-at-login setting."
        }
    }
}

protocol LaunchAtLoginServicing {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

private struct MainAppLaunchAtLoginService: LaunchAtLoginServicing {
    var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

final class LaunchAtLoginManager {
    private let service: any LaunchAtLoginServicing

    convenience init() {
        self.init(service: MainAppLaunchAtLoginService())
    }

    init(service: any LaunchAtLoginServicing) {
        self.service = service
    }

    var status: LaunchAtLoginStatus {
        Self.status(for: service.status)
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> LaunchAtLoginUpdateResult {
        let initialStatus = service.status

        if enabled {
            switch initialStatus {
            case .enabled:
                return .enabled(changed: false)
            case .requiresApproval:
                return .requiresApproval
            case .notRegistered,
                 .notFound:
                return updateService(register: true)
            @unknown default:
                return .failed(actualStatus: .unavailable)
            }
        }

        switch initialStatus {
        case .notRegistered:
            return .disabled(changed: false)
        case .notFound:
            return .failed(actualStatus: .unavailable)
        case .enabled,
             .requiresApproval:
            return updateService(register: false)
        @unknown default:
            return .failed(actualStatus: .unavailable)
        }
    }

    static func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func status(for status: SMAppService.Status) -> LaunchAtLoginStatus {
        switch status {
        case .notRegistered:
            .disabled
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }

    private func updateService(register: Bool) -> LaunchAtLoginUpdateResult {
        do {
            if register {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            let actualStatus = status
            AppLog.system.error(
                "Launch at login update failed; status is \(String(describing: actualStatus), privacy: .public)",
            )
            return .failed(actualStatus: actualStatus)
        }

        switch status {
        case .enabled:
            return .enabled(changed: true)
        case .disabled:
            return .disabled(changed: true)
        case .requiresApproval:
            return .requiresApproval
        case .unknown,
             .unavailable:
            return .failed(actualStatus: status)
        }
    }
}

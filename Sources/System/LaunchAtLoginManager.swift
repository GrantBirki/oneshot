import Foundation
import ServiceManagement

final class LaunchAtLoginManager {
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLog.system.error("Launch at login update failed: \(String(describing: error), privacy: .public)")
        }
    }
}

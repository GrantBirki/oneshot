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
            NSLog("LaunchAtLogin error: \(error)")
        }
    }
}

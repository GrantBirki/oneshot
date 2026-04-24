import OSLog

enum AppLog {
    private static let subsystem = "com.grantbirki.oneshot"

    static let pointsOfInterest = OSLog(subsystem: subsystem, category: .pointsOfInterest)
    static let app = Logger(subsystem: subsystem, category: "App")
    static let capture = Logger(subsystem: subsystem, category: "Capture")
    static let hotkeys = Logger(subsystem: subsystem, category: "Hotkeys")
    static let output = Logger(subsystem: subsystem, category: "Output")
    static let preview = Logger(subsystem: subsystem, category: "Preview")
    static let system = Logger(subsystem: subsystem, category: "System")
}

enum AppSignpost {
    static func begin(_ name: StaticString) -> OSSignpostID {
        let id = OSSignpostID(log: AppLog.pointsOfInterest)
        os_signpost(.begin, log: AppLog.pointsOfInterest, name: name, signpostID: id)
        return id
    }

    static func end(_ name: StaticString, id: OSSignpostID) {
        os_signpost(.end, log: AppLog.pointsOfInterest, name: name, signpostID: id)
    }

    static func event(_ name: StaticString) {
        os_signpost(.event, log: AppLog.pointsOfInterest, name: name)
    }
}

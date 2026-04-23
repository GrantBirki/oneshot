import OSLog

enum AppLog {
    private static let subsystem = "com.grantbirki.oneshot"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let capture = Logger(subsystem: subsystem, category: "Capture")
    static let hotkeys = Logger(subsystem: subsystem, category: "Hotkeys")
    static let output = Logger(subsystem: subsystem, category: "Output")
    static let preview = Logger(subsystem: subsystem, category: "Preview")
    static let system = Logger(subsystem: subsystem, category: "System")
}

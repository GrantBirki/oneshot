import Foundation

enum FilenameFormatter {
    static func makeFilename(prefix: String, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy_MM_dd'T'HH_mm_ss"

        let timestamp = formatter.string(from: date)
        let offsetSeconds = TimeZone.current.secondsFromGMT(for: date)
        let sign = offsetSeconds >= 0 ? "tz_plus" : "tz_minus"
        let absOffset = abs(offsetSeconds)
        let hours = absOffset / 3600
        let minutes = (absOffset % 3600) / 60
        let tz = String(format: "%02d_%02d", hours, minutes)

        let sanitizedPrefix = prefix.isEmpty ? "screenshot" : prefix
        return "\(sanitizedPrefix)_\(timestamp)_\(sign)_\(tz).png"
    }
}

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
        let timeZoneOffset = String(format: "%02d_%02d", hours, minutes)

        let sanitizedPrefix = sanitizePrefix(prefix)
        return "\(sanitizedPrefix)_\(timestamp)_\(sign)_\(timeZoneOffset).png"
    }

    private static func sanitizePrefix(_ prefix: String) -> String {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "screenshot"
        }

        let withoutTraversal = trimmed.replacingOccurrences(of: "..", with: "")
        let forbidden = CharacterSet(charactersIn: "/:\\")
        let filteredScalars = withoutTraversal.unicodeScalars.filter { !forbidden.contains($0) }
        let sanitized = String(String.UnicodeScalarView(filteredScalars))

        return sanitized.isEmpty ? "screenshot" : sanitized
    }
}

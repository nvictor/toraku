import Foundation

enum DurationFormatting {
    static func clock(_ interval: TimeInterval) -> String {
        let isNegative = interval < 0
        let totalSeconds = Int(abs(interval).rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        let formatted: String
        if hours > 0 {
            formatted = String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            formatted = String(format: "%02d:%02d", minutes, seconds)
        }

        return isNegative ? "+\(formatted)" : formatted
    }

    static func minutes(_ interval: TimeInterval) -> String {
        let totalSeconds = max(1, Int(interval.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            if seconds == 0 {
                return "\(hours) hr \(minutes) min"
            }

            return "\(hours) hr \(minutes) min \(seconds) sec"
        }

        if seconds == 0 {
            return "\(minutes) min"
        }

        if minutes == 0 {
            return "\(seconds) sec"
        }

        return "\(minutes) min \(seconds) sec"
    }

    static func timeRange(
        startDate: Date,
        startOffset: TimeInterval,
        endOffset: TimeInterval,
        calendar: Calendar = .current,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let segmentStartDate = startDate.addingTimeInterval(startOffset)
        let segmentEndDate = startDate.addingTimeInterval(endOffset)
        let includesSeconds = calendar.component(.second, from: segmentStartDate) != 0
            || calendar.component(.second, from: segmentEndDate) != 0

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = includesSeconds ? "h:mm:ss a" : "h:mm a"

        return "\(formatter.string(from: segmentStartDate))-\(formatter.string(from: segmentEndDate))"
    }
}

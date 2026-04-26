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
        let minutes = max(1, Int((interval / 60).rounded()))
        return "\(minutes) min"
    }
}

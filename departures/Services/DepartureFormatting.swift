import Foundation

enum DepartureFormatting {
    static var departureTime: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.timeZone = TimeZone(identifier: "Europe/Prague")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    static var fullDepartureTime: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.timeZone = TimeZone(identifier: "Europe/Prague")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    static var updatedTime: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "cs_CZ")
        formatter.timeZone = TimeZone(identifier: "Europe/Prague")
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }

    static func delayText(seconds: Int?) -> String {
        guard let seconds else {
            return "Delay unknown"
        }

        let minutes = Int((Double(seconds) / 60.0).rounded(.towardZero))

        if minutes > 0 {
            return "+\(minutes) min"
        }

        if minutes < 0 {
            return "\(minutes) min"
        }

        return "On time"
    }

    static func minutesUntilDeparture(_ date: Date, now: Date = Date()) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let minutes = seconds / 60

        if minutes == 0 {
            return "<1 min"
        }

        return "\(minutes) min"
    }

    static func distanceText(meters: Double) -> String {
        if meters < 950 {
            return "\(Int(meters.rounded())) m"
        }

        let kilometers = meters / 1_000
        return String(format: "%.1f km", kilometers)
    }
}

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

    /// Countdown to a departure. `showSeconds == true` renders "M:SS" ("4:35", "0:09");
    /// when dimmed in always-on mode pass `false` for coarse minutes ("5 min"), since
    /// the screen only refreshes about once a minute then. Past the departure time it
    /// returns "Now" and shortly after "Departed".
    static func countdownText(to date: Date, now: Date = Date(), showSeconds: Bool = true) -> String {
        let remaining = Int(date.timeIntervalSince(now).rounded())

        if remaining <= -30 {
            return "Departed"
        }

        if remaining <= 0 {
            return "Now"
        }

        if showSeconds {
            return String(format: "%d:%02d", remaining / 60, remaining % 60)
        }

        return "\(max(1, Int((Double(remaining) / 60.0).rounded(.up)))) min"
    }

    static func distanceText(meters: Double) -> String {
        if meters < 950 {
            return "\(Int(meters.rounded())) m"
        }

        let kilometers = meters / 1_000
        return String(format: "%.1f km", kilometers)
    }
}

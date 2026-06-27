import Foundation

enum QuietHours {
    static func isQuiet(ranges: [QuietHourRange], at date: Date = .now) -> Bool {
        ranges.contains { isInRange($0, at: date) }
    }

    static func isInRange(_ range: QuietHourRange, at date: Date) -> Bool {
        guard let startMinutes = parseHHMM(range.start),
              let endMinutes = parseHHMM(range.end) else {
            return false
        }

        if startMinutes == endMinutes {
            return false
        }

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        if startMinutes < endMinutes {
            return currentMinutes >= startMinutes && currentMinutes < endMinutes
        } else {
            return currentMinutes >= startMinutes || currentMinutes < endMinutes
        }
    }

    private static func parseHHMM(_ str: String) -> Int? {
        let parts = str.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              hours >= 0, hours < 24,
              minutes >= 0, minutes < 60 else {
            return nil
        }
        return hours * 60 + minutes
    }
}

import Foundation

/// A daily window of the clock, used two ways: as the app-wide quiet hours and
/// as a reminder's active hours. Pure math over minutes of the day, so midnight
/// wrap is tested directly.
struct DailyWindow: Equatable, Codable {
    /// Minutes after midnight, 0 to 1439.
    var startMinutes: Int
    var endMinutes: Int

    /// Whether the window covers this moment. A window with equal ends is
    /// empty; callers treat that as "no window" rather than a full day.
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard startMinutes != endMinutes else { return false }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if startMinutes < endMinutes {
            return minutes >= startMinutes && minutes < endMinutes
        }
        // Wraps midnight: covered from the evening start or before the morning end.
        return minutes >= startMinutes || minutes < endMinutes
    }

    /// The next moment the window opens, strictly after the given date.
    func nextStart(after date: Date, calendar: Calendar = .current) -> Date? {
        calendar.nextDate(
            after: date,
            matching: DateComponents(hour: startMinutes / 60, minute: startMinutes % 60),
            matchingPolicy: .nextTime
        )
    }

    /// When the current window ends, for display. Nil outside the window.
    func currentWindowEnd(from date: Date, calendar: Calendar = .current) -> Date? {
        guard contains(date, calendar: calendar) else { return nil }
        return calendar.nextDate(
            after: date,
            matching: DateComponents(hour: endMinutes / 60, minute: endMinutes % 60),
            matchingPolicy: .nextTime
        )
    }
}

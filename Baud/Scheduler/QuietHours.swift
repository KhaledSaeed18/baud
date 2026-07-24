import Foundation

/// A daily window in which reminders are skipped, like a scheduled pause.
/// Pure math over minutes of the day, so midnight wrap is tested directly.
struct QuietHours: Equatable {
    /// Minutes after midnight, 0 to 1439.
    var startMinutes: Int
    var endMinutes: Int

    /// Whether the window covers this moment. A window with equal ends is
    /// empty, never a full day: a full-day silence is what pause is for.
    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard startMinutes != endMinutes else { return false }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        if startMinutes < endMinutes {
            return minutes >= startMinutes && minutes < endMinutes
        }
        // Wraps midnight: quiet from the evening start or before the morning end.
        return minutes >= startMinutes || minutes < endMinutes
    }

    /// When the current quiet window ends, for the menu. Nil outside the window.
    func currentWindowEnd(from date: Date, calendar: Calendar = .current) -> Date? {
        guard contains(date, calendar: calendar) else { return nil }
        let end = calendar.nextDate(
            after: date,
            matching: DateComponents(hour: endMinutes / 60, minute: endMinutes % 60),
            matchingPolicy: .nextTime
        )
        return end
    }
}

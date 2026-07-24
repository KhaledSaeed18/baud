import Foundation

/// Turns one plain sentence into a reminder: "water every 45 minutes",
/// "call Tom in 2 hours", "stretch at 3pm on weekdays". Deterministic rules,
/// no network and no model, so the same sentence always parses the same way
/// and the whole thing is tested headless.
enum QuickAddParser {
    /// Nil when the sentence has no recognisable schedule. The caller shows a
    /// hint rather than guessing at what the user meant.
    static func parse(_ input: String, now: Date = Date(), calendar: Calendar = .current) -> Reminder? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let weekdays = extractWeekdays(from: &text)

        if let (label, interval) = matchEvery(text) {
            return make(label: label, interval: interval, weekdays: weekdays)
        }
        if let (label, delay) = matchIn(text) {
            return make(label: label, fireAt: now.addingTimeInterval(delay))
        }
        if let (label, date) = matchAt(text, now: now, calendar: calendar) {
            return make(label: label, fireAt: date)
        }
        return nil
    }

    // "on weekdays" or "on weekends" at the end of the sentence, removed from
    // the working text so the schedule patterns stay anchored.
    private static func extractWeekdays(from text: inout String) -> Set<Int>? {
        if let range = text.range(of: #"\s+on\s+weekdays\s*$"#, options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(range)
            return [2, 3, 4, 5, 6]
        }
        if let range = text.range(of: #"\s+on\s+weekends\s*$"#, options: [.regularExpression, .caseInsensitive]) {
            text.removeSubrange(range)
            return [1, 7]
        }
        return nil
    }

    // "water every 45 minutes", "stand up every hour"
    private static func matchEvery(_ text: String) -> (label: String, interval: TimeInterval)? {
        let pattern = /^(?<label>.+?)\s+every\s+(?:(?<count>\d+)\s*)?(?<unit>seconds?|secs?|minutes?|mins?|hours?|hrs?)$/
            .ignoresCase()
        guard let match = text.wholeMatch(of: pattern) else { return nil }
        let count = match.count.flatMap { Int($0) } ?? 1
        guard count > 0, let seconds = unitSeconds(String(match.unit)) else { return nil }
        return (String(match.label), TimeInterval(count) * seconds)
    }

    // "grab a coffee in 5 minutes"
    private static func matchIn(_ text: String) -> (label: String, delay: TimeInterval)? {
        let pattern = /^(?<label>.+?)\s+in\s+(?<count>\d+)\s*(?<unit>seconds?|secs?|minutes?|mins?|hours?|hrs?)$/
            .ignoresCase()
        guard let match = text.wholeMatch(of: pattern) else { return nil }
        guard let count = Int(match.count), count > 0, let seconds = unitSeconds(String(match.unit)) else { return nil }
        return (String(match.label), TimeInterval(count) * seconds)
    }

    // "meeting at 3pm", "call Tom at 15:30". A bare hour reads as 24-hour
    // time; the moment lands on the next occurrence, today or tomorrow.
    private static func matchAt(_ text: String, now: Date, calendar: Calendar) -> (label: String, date: Date)? {
        let pattern = /^(?<label>.+?)\s+at\s+(?<hour>\d{1,2})(?::(?<minute>\d{2}))?\s*(?<meridiem>am|pm)?$/
            .ignoresCase()
        guard let match = text.wholeMatch(of: pattern) else { return nil }
        guard var hour = Int(match.hour), hour <= 23 else { return nil }
        let minute = match.minute.flatMap { Int($0) } ?? 0
        guard minute <= 59 else { return nil }

        if let meridiem = match.meridiem?.lowercased() {
            guard hour >= 1, hour <= 12 else { return nil }
            if meridiem == "pm", hour < 12 { hour += 12 }
            if meridiem == "am", hour == 12 { hour = 0 }
        }

        guard let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { return nil }
        let date = today > now ? today : calendar.date(byAdding: .day, value: 1, to: today) ?? today
        return (String(match.label), date)
    }

    private static func unitSeconds(_ unit: String) -> TimeInterval? {
        switch unit.lowercased() {
        case let u where u.hasPrefix("sec"): return 1
        case let u where u.hasPrefix("min"): return 60
        case let u where u.hasPrefix("h"): return 3600
        default: return nil
        }
    }

    private static func make(
        label rawLabel: String,
        interval: TimeInterval = 30 * 60,
        weekdays: Set<Int>? = nil,
        fireAt: Date? = nil
    ) -> Reminder? {
        let label = cleaned(rawLabel)
        guard !label.isEmpty else { return nil }
        return Reminder(
            label: label,
            message: label.hasSuffix(".") ? label : label + ".",
            interval: max(5, interval),
            mood: mood(for: label),
            weekdays: weekdays,
            fireAt: fireAt
        )
    }

    private static func cleaned(_ raw: String) -> String {
        var label = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // "remind me to" and friends are carrier phrases, not the reminder.
        for prefix in ["remind me to ", "remind me ", "reminder to ", "reminder "] {
            if label.lowercased().hasPrefix(prefix) {
                label = String(label.dropFirst(prefix.count))
                break
            }
        }
        guard let first = label.first else { return label }
        return first.uppercased() + label.dropFirst()
    }

    /// A mood guessed from the words, so quick-added reminders get the right
    /// accent without a form. Custom is the honest fallback.
    private static func mood(for label: String) -> CharacterMood {
        let lowered = label.lowercased()
        if lowered.contains("water") || lowered.contains("drink") || lowered.contains("hydrate") { return .water }
        if lowered.contains("eye") || lowered.contains("look away") { return .eyes }
        if lowered.contains("posture") || lowered.contains("straighten") || lowered.contains("sit up") { return .posture }
        if lowered.contains("move") || lowered.contains("stand") || lowered.contains("stretch") || lowered.contains("walk") { return .move }
        return .custom
    }
}

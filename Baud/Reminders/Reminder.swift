import Foundation

/// A reminder as data. A built-in and a user-defined reminder are the same type;
/// nothing downstream special-cases water or movement. Persisted as readable
/// JSON, so this is also the on-disk shape a user can edit.
struct Reminder: Identifiable, Codable, Equatable {
    let id: UUID
    var label: String
    var message: String
    var interval: TimeInterval
    var mood: CharacterMood
    var isEnabled: Bool
    var isBuiltIn: Bool

    /// Seconds a snooze postpones this reminder. Nil means the app-wide snooze
    /// length applies. Optional so files written before the field decode as is.
    var snoozeInterval: TimeInterval?

    /// The part of the day this reminder lives in, like lunch for a snack
    /// reminder. Due outside the window, it waits for the next window start.
    /// Nil means the whole day.
    var activeHours: DailyWindow?

    /// The days this reminder lives on, as Calendar weekday numbers (1 is
    /// Sunday). Due on another day, it waits for the next allowed day. Nil or
    /// empty means every day.
    var weekdays: Set<Int>?

    /// Set, this is a one-time reminder: it fires once at this moment and is
    /// then disabled, and `interval` is ignored. Nil means it repeats.
    var fireAt: Date?

    var isOneTime: Bool { fireAt != nil }

    init(
        id: UUID = UUID(),
        label: String,
        message: String,
        interval: TimeInterval,
        mood: CharacterMood,
        isEnabled: Bool = true,
        isBuiltIn: Bool = false,
        snoozeInterval: TimeInterval? = nil,
        activeHours: DailyWindow? = nil,
        weekdays: Set<Int>? = nil,
        fireAt: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.message = message
        self.interval = interval
        self.mood = mood
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
        self.snoozeInterval = snoozeInterval
        self.activeHours = activeHours
        self.weekdays = weekdays
        self.fireAt = fireAt
    }
}

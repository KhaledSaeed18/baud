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

    init(
        id: UUID = UUID(),
        label: String,
        message: String,
        interval: TimeInterval,
        mood: CharacterMood,
        isEnabled: Bool = true,
        isBuiltIn: Bool = false,
        snoozeInterval: TimeInterval? = nil
    ) {
        self.id = id
        self.label = label
        self.message = message
        self.interval = interval
        self.mood = mood
        self.isEnabled = isEnabled
        self.isBuiltIn = isBuiltIn
        self.snoozeInterval = snoozeInterval
    }
}

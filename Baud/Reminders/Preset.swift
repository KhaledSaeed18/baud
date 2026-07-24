import Foundation

/// A one-click starting point: new intervals and enabled flags for the
/// built-in reminders. Pure data over reminder ids; custom reminders are
/// never touched, and applying is a plain function so it is tested headless.
struct Preset: Identifiable {
    struct Tweak {
        let interval: TimeInterval
        let isEnabled: Bool
    }

    let id: String
    let name: String
    let tweaks: [UUID: Tweak]

    /// The reminder list with this preset applied. Reminders without a tweak,
    /// including every custom one, pass through unchanged.
    func applied(to reminders: [Reminder]) -> [Reminder] {
        reminders.map { reminder in
            guard let tweak = tweaks[reminder.id] else { return reminder }
            var updated = reminder
            updated.interval = tweak.interval
            updated.isEnabled = tweak.isEnabled
            return updated
        }
    }
}

extension Preset {
    static let all: [Preset] = [recommended, deskDay, shortBursts, moreWater, restMyEyes]

    static let recommended = Preset(
        id: "recommended",
        name: "Recommended",
        tweaks: [
            DefaultReminders.move.id: Tweak(interval: 30 * 60, isEnabled: true),
            DefaultReminders.water.id: Tweak(interval: 45 * 60, isEnabled: true),
            DefaultReminders.eyes.id: Tweak(interval: 20 * 60, isEnabled: true),
            DefaultReminders.posture.id: Tweak(interval: 40 * 60, isEnabled: true),
        ]
    )

    static let deskDay = Preset(
        id: "desk-day",
        name: "Desk day",
        tweaks: [
            DefaultReminders.move.id: Tweak(interval: 25 * 60, isEnabled: true),
            DefaultReminders.water.id: Tweak(interval: 45 * 60, isEnabled: true),
            DefaultReminders.eyes.id: Tweak(interval: 20 * 60, isEnabled: true),
            DefaultReminders.posture.id: Tweak(interval: 30 * 60, isEnabled: true),
        ]
    )

    static let shortBursts = Preset(
        id: "short-bursts",
        name: "Short bursts",
        tweaks: [
            DefaultReminders.move.id: Tweak(interval: 20 * 60, isEnabled: true),
            DefaultReminders.water.id: Tweak(interval: 30 * 60, isEnabled: true),
            DefaultReminders.eyes.id: Tweak(interval: 15 * 60, isEnabled: true),
            DefaultReminders.posture.id: Tweak(interval: 25 * 60, isEnabled: true),
        ]
    )

    static let moreWater = Preset(
        id: "more-water",
        name: "More water",
        tweaks: [
            DefaultReminders.water.id: Tweak(interval: 30 * 60, isEnabled: true),
        ]
    )

    static let restMyEyes = Preset(
        id: "rest-my-eyes",
        name: "Rest my eyes",
        tweaks: [
            DefaultReminders.eyes.id: Tweak(interval: 15 * 60, isEnabled: true),
        ]
    )
}

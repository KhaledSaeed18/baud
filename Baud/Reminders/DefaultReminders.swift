import Foundation

/// The reminders a fresh install starts with. Their ids are fixed so a built-in
/// keeps its identity across versions once persisted.
enum DefaultReminders {
    static let all: [Reminder] = [move, water, eyes, posture]

    static let move = Reminder(
        id: fixed("11111111-1111-1111-1111-111111111111"),
        label: "Move",
        message: "Time to stand up.",
        interval: 30 * 60,
        mood: .move,
        isBuiltIn: true
    )

    static let water = Reminder(
        id: fixed("22222222-2222-2222-2222-222222222222"),
        label: "Water",
        message: "Water.",
        interval: 45 * 60,
        mood: .water,
        isBuiltIn: true
    )

    static let eyes = Reminder(
        id: fixed("33333333-3333-3333-3333-333333333333"),
        label: "Rest eyes",
        message: "Look away for twenty seconds.",
        interval: 20 * 60,
        mood: .eyes,
        isBuiltIn: true
    )

    static let posture = Reminder(
        id: fixed("44444444-4444-4444-4444-444444444444"),
        label: "Posture",
        message: "Straighten up.",
        interval: 40 * 60,
        mood: .posture,
        isBuiltIn: true
    )

    private static func fixed(_ string: String) -> UUID {
        UUID(uuidString: string) ?? UUID()
    }
}

import Observation

/// The character's state machine. Views read this and render; they never set
/// state directly. Transitions are validated against CharacterState, so an
/// out-of-order request is ignored rather than producing a wrong appearance.
@MainActor
@Observable
final class CharacterModel {
    private(set) var state: CharacterState = .hidden
    private(set) var mood: CharacterMood = .move
    private(set) var message: String = ""

    /// The value the character is handed: a mood and a line to say. It knows
    /// nothing about reminders beyond this.
    func begin(mood: CharacterMood, message: String) {
        self.mood = mood
        self.message = message
        transition(to: .arriving)
    }

    func speak() { transition(to: .speaking) }
    func settleIdle() { transition(to: .idle) }
    func acknowledge() { transition(to: .acknowledged) }
    func snooze() { transition(to: .snoozed) }
    func leave() { transition(to: .leaving) }
    func finishLeaving() { transition(to: .hidden) }

    private func transition(to next: CharacterState) {
        guard state.canTransition(to: next) else { return }
        state = next
    }
}

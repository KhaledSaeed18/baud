/// Where the character is in its appearance lifecycle. This is a state machine,
/// not a set of boolean flags: a new mood or beat is a case, never an `if` in a
/// view.
enum CharacterState {
    case hidden
    case arriving
    case idle
    case speaking
    case acknowledged
    case snoozed
    case leaving
}

extension CharacterState {
    /// The states reachable from this one. Anything not listed is rejected, so
    /// an out-of-order request is a no-op rather than a wrong appearance.
    var allowedNext: Set<CharacterState> {
        switch self {
        case .hidden: return [.arriving]
        case .arriving: return [.speaking, .leaving]
        case .speaking: return [.idle, .acknowledged, .snoozed, .leaving]
        case .idle: return [.speaking, .acknowledged, .snoozed, .leaving]
        case .acknowledged: return [.leaving]
        case .snoozed: return [.leaving]
        case .leaving: return [.hidden]
        }
    }

    func canTransition(to next: CharacterState) -> Bool {
        allowedNext.contains(next)
    }
}

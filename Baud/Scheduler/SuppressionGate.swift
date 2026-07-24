import Foundation

/// Why a reminder is being held rather than shown. The gate reports the first
/// reason it finds; nil means the moment is clear.
enum SuppressionReason: Equatable {
    case fullScreen
    case cameraOrMicrophoneInUse
    case screenLocked
    case idle
    case calendarEvent
    case doNotDisturb
    case screenShared
}

/// "Is now a good moment." Behind a protocol so the scheduler's hold logic is
/// tested by driving bad-moment states directly, with no real system state.
@MainActor
protocol SuppressionGate {
    func currentReason() -> SuppressionReason?
}

/// A gate that never suppresses: the scheduler's default until the real gate is
/// wired in, and a convenience for tests that want an always-clear context.
struct ClearGate: SuppressionGate {
    func currentReason() -> SuppressionReason? { nil }
}

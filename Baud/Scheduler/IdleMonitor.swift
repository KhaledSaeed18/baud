import Foundation
import CoreGraphics

/// Seconds since the last user input, used to tell whether anyone is there to
/// see a reminder. Taking the minimum across the input event types gives the
/// time since the most recent of any of them.
struct IdleMonitor {
    private let inputEvents: [CGEventType] = [
        .mouseMoved,
        .leftMouseDown,
        .rightMouseDown,
        .otherMouseDown,
        .keyDown,
        .scrollWheel,
    ]

    func secondsSinceInput() -> TimeInterval {
        inputEvents
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? .greatestFiniteMagnitude
    }
}

import SwiftUI
import QuartzCore

/// Every animation constant in one place. CHARACTER.md is the source of truth
/// for these values; nothing else in the app holds a duration or a spring.
enum Motion {
    // Window slide, driven by the Presenter over the window frame.
    static let arriveDuration: TimeInterval = 0.4
    static let leaveDuration: TimeInterval = 0.3
    static let fadeDuration: TimeInterval = 0.25

    /// Arrival overshoots a little then settles. A back-out bezier gives that
    /// on the window frame without running a spring solver.
    static func arriveTiming() -> CAMediaTimingFunction {
        CAMediaTimingFunction(controlPoints: 0.34, 1.3, 0.64, 1)
    }

    static func leaveTiming() -> CAMediaTimingFunction {
        CAMediaTimingFunction(name: .easeIn)
    }

    // Character micro-motion, inside the SwiftUI view.
    static let breatheAmplitude: CGFloat = 1.5
    static let breatheDuration: TimeInterval = 3.2
    static let idleBlinkPeriod: TimeInterval = 4
    static let blinkDuration: TimeInterval = 0.09

    static let blink = Animation.easeInOut(duration: Self.blinkDuration)
    static let breathe = Animation.easeInOut(duration: Self.breatheDuration).repeatForever(autoreverses: true)
    static let speakGesture = Animation.spring(response: 0.32, dampingFraction: 0.5)
    static let reactBeat = Animation.spring(response: 0.3, dampingFraction: 0.62)

    // Reduce Motion: slides become fades and springs are skipped in favour of
    // this plain change.
    static let reducedChange = Animation.easeInOut(duration: Self.fadeDuration)
}

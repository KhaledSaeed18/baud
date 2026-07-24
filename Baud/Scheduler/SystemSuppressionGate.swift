import AppKit
import CoreGraphics

/// The real "is now a good moment" check. Best effort: conditions with no
/// reliable public API (Focus, screen recording) are not reported here, but the
/// signals a call or a presentation do raise (capture devices, full screen) still
/// catch the cases that matter most. When in doubt, it does not interrupt.
@MainActor
struct SystemSuppressionGate: SuppressionGate {
    // A provider, not a value, so a settings change applies on the next check
    // without rebuilding the gate or restarting the scheduler.
    private let idleThreshold: () -> TimeInterval
    private let holdsOverFullScreen: () -> Bool
    private let holdsDuringCapture: () -> Bool

    private let idle = IdleMonitor()
    private let capture = CaptureMonitor()

    init(
        idleThreshold: @escaping () -> TimeInterval = { 120 },
        holdsOverFullScreen: @escaping () -> Bool = { true },
        holdsDuringCapture: @escaping () -> Bool = { true }
    ) {
        self.idleThreshold = idleThreshold
        self.holdsOverFullScreen = holdsOverFullScreen
        self.holdsDuringCapture = holdsDuringCapture
    }

    func currentReason() -> SuppressionReason? {
        if isScreenLocked() { return .screenLocked }
        if holdsDuringCapture(), capture.isMicrophoneActive() || capture.isCameraActive() {
            return .cameraOrMicrophoneInUse
        }
        if holdsOverFullScreen(), isFrontmostFullScreen() { return .fullScreen }
        if idle.secondsSinceInput() >= idleThreshold() { return .idle }
        return nil
    }

    private func isScreenLocked() -> Bool {
        guard let info = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return (info["CGSSessionScreenIsLocked"] as? Int) == 1
    }

    /// Heuristic: a window of the frontmost app that is at least as large as a
    /// whole display covers the menu bar strip too, which a merely maximised
    /// window never does, so it is almost certainly full screen.
    private func isFrontmostFullScreen() -> Bool {
        guard let front = NSWorkspace.shared.frontmostApplication else { return false }
        let pid = front.processIdentifier
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return false }

        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let boundsInfo = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo as CFDictionary)
            else { continue }

            if NSScreen.screens.contains(where: { $0.frame.width <= bounds.width && $0.frame.height <= bounds.height }) {
                return true
            }
        }
        return false
    }
}

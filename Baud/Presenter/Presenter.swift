import AppKit
import SwiftUI

/// How a shown reminder ended.
enum ReminderOutcome {
    case dismissed
    case snoozed
    case autoDismissed
}

/// Owns the overlay window and drives the character through its states. It
/// performs; the only timing it holds is the short beats between states. The
/// scheduler hands it a reminder, and it reports how the reminder ended.
@MainActor
final class Presenter {
    private let character = CharacterModel()
    private var window: BaudWindow?
    private let contentSize = CGSize(width: 210, height: 220)
    private let speakingBeat: TimeInterval = 2.2
    private let autoDismissDelay: TimeInterval = 8
    private var currentOutcome: ((ReminderOutcome) -> Void)?
    private var mouseMonitor: Any?

    func show(reminder: Reminder, onOutcome: @escaping (ReminderOutcome) -> Void) {
        guard character.state == .hidden else { return }

        currentOutcome = onOutcome
        character.begin(mood: reminder.mood, message: reminder.message)
        Task { await arrive() }
    }

    private func dismissByUser() {
        guard character.state == .speaking || character.state == .idle else { return }
        report(.dismissed)
        character.acknowledge()
        Task { await leave(afterBeat: true) }
    }

    private func snoozeByUser() {
        guard character.state == .speaking || character.state == .idle else { return }
        report(.snoozed)
        character.snooze()
        Task { await leave(afterBeat: true) }
    }

    private func arrive() async {
        let window = ensureWindow()
        // With no screen the character can never appear. Report and reset to
        // hidden; staying in .arriving would block every future reminder.
        guard let screen = targetScreen() else {
            report(.autoDismissed)
            character.leave()
            character.finishLeaving()
            return
        }
        let resting = WindowPositioner.restingFrame(size: contentSize, in: screen.visibleFrame)

        if reduceMotion {
            window.setFrame(resting, display: false)
            window.alphaValue = 0
            window.orderFrontRegardless()
            await fade(window, to: 1)
        } else {
            let offscreen = WindowPositioner.offscreenFrame(matching: resting, belowScreenMinY: screen.frame.minY)
            window.alphaValue = 1
            window.setFrame(offscreen, display: false)
            window.orderFrontRegardless()
            await slide(window, to: resting, duration: Motion.arriveDuration, timing: Motion.arriveTiming())
        }

        startTrackingMouse()
        character.speak()
        try? await Task.sleep(for: .seconds(speakingBeat))
        guard character.state == .speaking else { return }
        character.settleIdle()

        // No interaction yet, so the character auto-dismisses. That is a normal
        // outcome, not a failure, and is never tracked as one.
        try? await Task.sleep(for: .seconds(autoDismissDelay))
        guard character.state == .idle else { return }
        report(.autoDismissed)
        character.leave()
        await leave(afterBeat: false)
    }

    private func leave(afterBeat: Bool) async {
        if afterBeat {
            try? await Task.sleep(for: .seconds(0.32))
            character.leave()
        }
        // Losing the window or the screen mid-show must still end in .hidden,
        // or the next reminder would be blocked forever.
        guard let window, let screen = targetScreen() else {
            window?.orderOut(nil)
            stopTrackingMouse()
            character.finishLeaving()
            return
        }
        let resting = WindowPositioner.restingFrame(size: contentSize, in: screen.visibleFrame)

        if reduceMotion {
            await fade(window, to: 0)
        } else {
            let offscreen = WindowPositioner.offscreenFrame(matching: resting, belowScreenMinY: screen.frame.minY)
            await slide(window, to: offscreen, duration: Motion.leaveDuration, timing: Motion.leaveTiming())
        }

        window.orderOut(nil)
        stopTrackingMouse()
        character.finishLeaving()
    }

    private func report(_ outcome: ReminderOutcome) {
        let callback = currentOutcome
        currentOutcome = nil
        callback?(outcome)
    }

    private func ensureWindow() -> BaudWindow {
        if let window { return window }

        let created = BaudWindow(contentRect: CGRect(origin: .zero, size: contentSize))
        let content = InteractiveCharacterView(
            model: character,
            onDismiss: { [weak self] in self?.dismissByUser() },
            onSnooze: { [weak self] in self?.snoozeByUser() }
        )
        created.contentView = InteractiveHostingView(rootView: content)
        window = created
        return created
    }

    /// The screen under the mouse, so the reminder appears where attention is.
    private func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func startTrackingMouse() {
        updateClickThrough()
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateClickThrough()
            }
        }
    }

    private func stopTrackingMouse() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        window?.ignoresMouseEvents = true
    }

    /// The window is click-through except when the cursor is over the bottom
    /// strip where the character and its controls sit. The bubble area above
    /// stays click-through.
    private func updateClickThrough() {
        guard let window else { return }
        let strip = CGRect(x: window.frame.minX, y: window.frame.minY, width: window.frame.width, height: 160)
        window.ignoresMouseEvents = !strip.contains(NSEvent.mouseLocation)
    }

    private func slide(_ window: NSWindow, to frame: CGRect, duration: TimeInterval, timing: CAMediaTimingFunction) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = duration
                context.timingFunction = timing
                window.animator().setFrame(frame, display: true)
            }, completionHandler: {
                continuation.resume()
            })
        }
    }

    private func fade(_ window: NSWindow, to alpha: CGFloat) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = Motion.fadeDuration
                window.animator().alphaValue = alpha
            }, completionHandler: {
                continuation.resume()
            })
        }
    }

}

import AppKit
import SwiftUI

/// Owns the overlay window and drives the character through its states. It
/// performs; the only timing it holds is the short beats between states. Phase 2
/// hands it reminders instead of the menu driving it.
@MainActor
final class Presenter {
    private let character = CharacterModel()
    private var window: BaudWindow?
    private let contentSize = CGSize(width: 210, height: 220)

    func show(mood: CharacterMood, message: String) {
        guard character.state == .hidden else { return }

        character.begin(mood: mood, message: message)
        Task { await arrive() }
    }

    func acknowledge() {
        guard character.state == .idle || character.state == .speaking else { return }
        character.acknowledge()
        Task { await leave(afterBeat: true) }
    }

    func snooze() {
        guard character.state == .idle || character.state == .speaking else { return }
        character.snooze()
        Task { await leave(afterBeat: true) }
    }

    func dismiss() {
        guard character.state != .hidden, character.state != .leaving else { return }
        character.leave()
        Task { await leave(afterBeat: false) }
    }

    private func arrive() async {
        let window = ensureWindow()
        guard let screen = targetScreen() else { return }
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

        character.speak()
        try? await Task.sleep(for: .seconds(2.2))
        if character.state == .speaking { character.settleIdle() }
    }

    private func leave(afterBeat: Bool) async {
        if afterBeat {
            try? await Task.sleep(for: .seconds(0.32))
            character.leave()
        }
        guard let window, let screen = targetScreen() else { return }
        let resting = WindowPositioner.restingFrame(size: contentSize, in: screen.visibleFrame)

        if reduceMotion {
            await fade(window, to: 0)
        } else {
            let offscreen = WindowPositioner.offscreenFrame(matching: resting, belowScreenMinY: screen.frame.minY)
            await slide(window, to: offscreen, duration: Motion.leaveDuration, timing: Motion.leaveTiming())
        }

        window.orderOut(nil)
        character.finishLeaving()
    }

    private func ensureWindow() -> BaudWindow {
        if let window { return window }

        let created = BaudWindow(contentRect: CGRect(origin: .zero, size: contentSize))
        created.contentView = NSHostingView(rootView: CharacterView(model: character))
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

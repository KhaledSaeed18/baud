import AppKit
import SwiftUI

/// Owns the overlay window and drives its appearance. It performs; it does not
/// decide timing. Phase 0 shows a placeholder shape on a manual trigger; later
/// phases hand it a reminder value to present.
@MainActor
final class Presenter {
    private var window: BaudWindow?
    private let contentSize = CGSize(width: 160, height: 160)

    // Local for Phase 0. Phase 1 moves motion constants into Motion.swift.
    private let slideInDuration: TimeInterval = 0.4
    private let slideOutDuration: TimeInterval = 0.3

    func showPlaceholder() {
        let window = ensureWindow()
        guard let screen = targetScreen() else { return }

        let resting = WindowPositioner.restingFrame(size: contentSize, in: screen.visibleFrame)
        let offscreen = WindowPositioner.offscreenFrame(matching: resting, belowScreenMinY: screen.frame.minY)

        window.setFrame(offscreen, display: false)
        window.orderFrontRegardless()
        animate(window, to: resting, duration: slideInDuration)
    }

    func hide() {
        guard let window, let screen = targetScreen() else { return }

        let resting = WindowPositioner.restingFrame(size: contentSize, in: screen.visibleFrame)
        let offscreen = WindowPositioner.offscreenFrame(matching: resting, belowScreenMinY: screen.frame.minY)

        animate(window, to: offscreen, duration: slideOutDuration) {
            window.orderOut(nil)
        }
    }

    private func ensureWindow() -> BaudWindow {
        if let window { return window }

        let created = BaudWindow(contentRect: CGRect(origin: .zero, size: contentSize))
        created.contentView = NSHostingView(rootView: PlaceholderView())
        window = created
        return created
    }

    /// The screen under the mouse, so the reminder appears where attention is.
    private func targetScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    }

    private func animate(_ window: NSWindow, to frame: CGRect, duration: TimeInterval, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(frame, display: true)
        } completionHandler: {
            completion?()
        }
    }
}

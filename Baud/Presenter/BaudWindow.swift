import AppKit

/// Borderless overlay that hosts the character in a screen corner.
///
/// It must never become key or main. Taking focus while the user is typing is
/// the worst failure this app has, so both overrides return false rather than
/// relying on styleMask alone.
final class BaudWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        // The window is reused across appearances, so closing it must not free it.
        isReleasedWhenClosed = false
    }
}

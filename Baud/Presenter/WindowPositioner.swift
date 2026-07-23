import Foundation

/// Corner geometry for the character window. Pure math over screen rectangles:
/// no window access and no side effects, so the positioning can be reasoned
/// about and tested without a screen.
enum WindowPositioner {
    /// Kept clear of the work-area edges so the window never overlaps the Dock
    /// or the menu bar.
    static let edgeInset: CGFloat = 24

    /// Where the character rests: the bottom trailing corner of the work area,
    /// inset from the visible frame.
    static func restingFrame(size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let x = visibleFrame.maxX - size.width - edgeInset
        let y = visibleFrame.minY + edgeInset
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// The window parked fully below the physical screen, used as the slide-in
    /// start and the slide-out end. It shares the resting x so the motion stays
    /// vertical.
    static func offscreenFrame(matching restingFrame: CGRect, belowScreenMinY screenMinY: CGFloat) -> CGRect {
        CGRect(
            x: restingFrame.minX,
            y: screenMinY - restingFrame.height,
            width: restingFrame.width,
            height: restingFrame.height
        )
    }
}

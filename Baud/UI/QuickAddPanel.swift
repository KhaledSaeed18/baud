import AppKit
import SwiftUI

/// A small floating field for one-sentence reminders. Unlike the character
/// window this panel is meant to be typed into, so it may become key; being a
/// nonactivating panel, summoning it still does not activate the app or steal
/// the front app's windows.
final class QuickAddKeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class QuickAddPanelController {
    private var panel: QuickAddKeyPanel?

    func show(model: AppModel) {
        let panel = ensurePanel(model: model)
        position(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    private func close() {
        panel?.orderOut(nil)
    }

    private func ensurePanel(model: AppModel) -> QuickAddKeyPanel {
        if let panel { return panel }

        let created = QuickAddKeyPanel(
            contentRect: CGRect(x: 0, y: 0, width: 440, height: 84),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        created.titleVisibility = .hidden
        created.titlebarAppearsTransparent = true
        created.isMovableByWindowBackground = true
        created.level = .floating
        created.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        created.isReleasedWhenClosed = false
        created.hidesOnDeactivate = false

        let content = QuickAddView(model: model) { [weak self] in
            self?.close()
        }
        created.contentView = NSHostingView(rootView: content)
        panel = created
        return created
    }

    /// Centered in the upper third of the screen under the mouse, where a
    /// summoned command bar is expected.
    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let x = frame.midX - panel.frame.width / 2
        let y = frame.minY + frame.height * 0.72
        panel.setFrameOrigin(CGPoint(x: x, y: y))
    }
}

private struct QuickAddView: View {
    let model: AppModel
    let onDone: () -> Void

    @State private var text = ""
    @State private var showsHint = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Water every 45 minutes, call Tom at 3pm", text: $text)
                .textFieldStyle(.plain)
                .font(.title3)
                .onSubmit(submit)
            Text(feedback)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 440)
        .onExitCommand(perform: dismiss)
    }

    // A live echo of what return will do, so the parse is never a surprise.
    private var feedback: String {
        if showsHint {
            return "Not understood. Try: water every 45 minutes, stretch at 3pm, coffee in 10 minutes."
        }
        guard !text.isEmpty else { return "One sentence, then return. Esc closes." }
        guard let parsed = QuickAddParser.parse(text) else {
            return "Keep typing, no schedule yet."
        }
        if let fireAt = parsed.fireAt {
            return "\(parsed.label), once at \(fireAt.formatted(date: .abbreviated, time: .shortened))"
        }
        let split = IntervalUnit.split(parsed.interval)
        return "\(parsed.label), every \(split.value) \(split.unit.short)"
    }

    private func submit() {
        guard model.quickAdd(text) != nil else {
            showsHint = true
            return
        }
        dismiss()
    }

    private func dismiss() {
        text = ""
        showsHint = false
        onDone()
    }
}

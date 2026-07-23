import SwiftUI
import AppKit

/// The menu bar content: the next reminder, pause controls, a preview, and quit.
struct MenuBarView: View {
    let model: AppModel

    var body: some View {
        nextReminder
        Divider()
        pauseControls
        Divider()
        Button("Show a reminder now") { model.preview() }
        Divider()
        Button("Quit Baud") { NSApp.terminate(nil) }
    }

    @ViewBuilder
    private var nextReminder: some View {
        if model.isPaused {
            Text(pausedText)
        } else if let next = model.nextUp() {
            Text("Next: \(next.reminder.label) at \(next.date.formatted(date: .omitted, time: .shortened))")
        } else {
            Text("No reminders scheduled")
        }
    }

    @ViewBuilder
    private var pauseControls: some View {
        if model.isPaused {
            Button("Resume") { model.resume() }
        } else {
            Menu("Pause") {
                Button("For 30 minutes") { model.pause(for: 30 * 60) }
                Button("For 1 hour") { model.pause(for: 60 * 60) }
                Button("For 3 hours") { model.pause(for: 3 * 60 * 60) }
                Button("Until I resume") { model.pauseIndefinitely() }
            }
        }
    }

    private var pausedText: String {
        guard let until = model.pausedUntil, until != .distantFuture else { return "Paused" }
        return "Paused until \(until.formatted(date: .omitted, time: .shortened))"
    }
}

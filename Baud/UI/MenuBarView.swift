import SwiftUI
import AppKit

/// The menu bar content: the next reminder, pause controls, settings, and quit.
struct MenuBarView: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        nextReminder
        Divider()
        pauseControls
        Divider()
        Button("Settings\u{2026}") {
            NSApp.activate()
            openSettings()
        }
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

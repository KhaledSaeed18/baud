import AppKit

/// Wires the app together: loads reminders, starts the scheduler, routes a due
/// reminder to the presenter, and recomputes when the Mac wakes.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let presenter = Presenter()

    private let store = ReminderStore()
    private var scheduler: ReminderScheduler?
    private var reminders: [Reminder] = []
    private var testIndex = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        reminders = store.load()

        let scheduler = ReminderScheduler(reminders: reminders, gate: SystemSuppressionGate()) { [weak self] reminder in
            self?.presenter.show(mood: reminder.mood, message: reminder.message)
        }
        scheduler.start()
        self.scheduler = scheduler

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }

    @objc private func systemDidWake() {
        scheduler?.handleWake()
    }

    /// Fire the next enabled reminder immediately, so the character can be seen
    /// without waiting out an interval. The scheduler keeps its own timing.
    func showNextForTesting() {
        let enabled = reminders.filter(\.isEnabled)
        guard !enabled.isEmpty else { return }
        let reminder = enabled[testIndex % enabled.count]
        testIndex += 1
        presenter.show(mood: reminder.mood, message: reminder.message)
    }

    func acknowledge() { presenter.acknowledge() }
    func snooze() { presenter.snooze() }
    func dismiss() { presenter.dismiss() }
}

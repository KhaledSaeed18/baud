import AppKit
import Observation
import ServiceManagement

/// The controller the UI talks to. It owns the store, the scheduler, and the
/// presenter, exposes the state the menu and settings read, and turns user
/// intents into scheduler and store calls.
@MainActor
@Observable
final class AppModel {
    private(set) var reminders: [Reminder]

    @ObservationIgnored let presenter = Presenter()
    @ObservationIgnored private let store: ReminderStore
    @ObservationIgnored private var scheduler: ReminderScheduler?

    init(store: ReminderStore = ReminderStore()) {
        self.store = store
        reminders = store.load()
    }

    func start() {
        let scheduler = ReminderScheduler(reminders: reminders, gate: SystemSuppressionGate()) { [weak self] reminder in
            self?.presenter.show(mood: reminder.mood, message: reminder.message)
        }
        scheduler.start()
        self.scheduler = scheduler
    }

    func handleWake() {
        scheduler?.handleWake()
    }

    var isPaused: Bool { scheduler?.isPaused ?? false }
    var pausedUntil: Date? { scheduler?.pausedUntil }

    func nextUp() -> (reminder: Reminder, date: Date)? {
        scheduler?.nextUp()
    }

    func pause(for duration: TimeInterval) { scheduler?.pause(for: duration) }
    func pauseIndefinitely() { scheduler?.pauseIndefinitely() }
    func resume() { scheduler?.resume() }

    var launchesAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled, SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            } else if !enabled, SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration can fail, for example on an unsigned build. Keep the
            // current state rather than surfacing an error the user cannot act on.
        }
    }

    /// Show the first enabled reminder now, without waiting out an interval.
    func preview() {
        guard let reminder = reminders.first(where: \.isEnabled) else { return }
        presenter.show(mood: reminder.mood, message: reminder.message)
    }

    @discardableResult
    func addCustomReminder() -> Reminder {
        let reminder = Reminder(label: "New reminder", message: "Reminder.", interval: 30 * 60, mood: .custom)
        reminders.append(reminder)
        persist()
        return reminder
    }

    func update(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
        persist()
    }

    func delete(_ reminder: Reminder) {
        guard !reminder.isBuiltIn else { return }
        reminders.removeAll { $0.id == reminder.id }
        persist()
    }

    func setEnabled(_ isEnabled: Bool, for reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index].isEnabled = isEnabled
        persist()
    }

    private func persist() {
        try? store.save(reminders)
        scheduler?.update(reminders: reminders)
    }
}

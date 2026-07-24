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
    // Tracked, not ignored: the menu's body can run before start() creates the
    // scheduler, and it must re-evaluate once the scheduler exists or it would
    // show "No reminders scheduled" forever.
    private var scheduler: ReminderScheduler?

    init(store: ReminderStore = ReminderStore()) {
        self.store = store
        reminders = store.load()
    }

    func start() {
        let scheduler = ReminderScheduler(
            reminders: reminders,
            gate: SystemSuppressionGate(idleThreshold: Self.idleThreshold),
            cooldown: Self.cooldown
        ) { [weak self] reminder in
            self?.deliver(reminder)
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

    /// Reminders waiting out a bad moment, oldest due first, for the menu.
    var heldReminders: [Reminder] {
        guard let scheduler else { return [] }
        return scheduler.held.values
            .sorted { $0.originalDue < $1.originalDue }
            .map(\.reminder)
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

    /// UserDefaults key for the snooze length, in minutes. The settings pane
    /// writes it; the scheduler reads it when a snooze is requested.
    static let snoozeMinutesKey = "snoozeMinutes"
    static let defaultSnoozeMinutes = 10

    private var snoozeInterval: TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: Self.snoozeMinutesKey)
        let minutes = stored > 0 ? stored : Self.defaultSnoozeMinutes
        return TimeInterval(minutes * 60)
    }

    /// UserDefaults key for how long the character waits for a click before it
    /// leaves on its own, in seconds.
    static let autoDismissSecondsKey = "autoDismissSeconds"
    static let defaultAutoDismissSeconds = 8

    private var autoDismissDelay: TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: Self.autoDismissSecondsKey)
        return TimeInterval(stored > 0 ? stored : Self.defaultAutoDismissSeconds)
    }

    /// UserDefaults key for how long the Mac sits with no input before
    /// reminders are held, in minutes.
    static let idleMinutesKey = "idleMinutes"
    static let defaultIdleMinutes = 2

    private static func idleThreshold() -> TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: idleMinutesKey)
        return TimeInterval((stored > 0 ? stored : defaultIdleMinutes) * 60)
    }

    /// UserDefaults key for the minimum gap between two appearances, in
    /// seconds, so back-to-back reminders never stack.
    static let cooldownSecondsKey = "cooldownSeconds"
    static let defaultCooldownSeconds = 120

    private static func cooldown() -> TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: cooldownSecondsKey)
        return TimeInterval(stored > 0 ? stored : defaultCooldownSeconds)
    }

    /// Show the first enabled reminder now, without waiting out an interval.
    /// With everything disabled, a sample line keeps the preview working.
    func preview() {
        let reminder = reminders.first(where: \.isEnabled)
            ?? Reminder(label: "Preview", message: "This is how a reminder looks.", interval: 60, mood: .custom)
        presenter.autoDismissDelay = autoDismissDelay
        presenter.show(reminder: reminder) { _ in }
    }

    private func deliver(_ reminder: Reminder) {
        presenter.autoDismissDelay = autoDismissDelay
        presenter.show(reminder: reminder) { [weak self] outcome in
            self?.handle(outcome, for: reminder)
        }
    }

    private func handle(_ outcome: ReminderOutcome, for reminder: Reminder) {
        switch outcome {
        case .snoozed:
            scheduler?.snooze(reminder.id, by: reminder.snoozeInterval ?? snoozeInterval)
        case .dismissed, .autoDismissed:
            break
        }
    }

    /// A fresh custom reminder, not yet added. The editor commits it through
    /// `add` only on save, so cancelling the add sheet leaves nothing behind.
    func newCustomReminder() -> Reminder {
        Reminder(label: "New reminder", message: "Reminder.", interval: 30 * 60, mood: .custom)
    }

    func add(_ reminder: Reminder) {
        reminders.append(reminder)
        persist()
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

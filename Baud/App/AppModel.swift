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
            gate: SystemSuppressionGate(
                idleThreshold: Self.idleThreshold,
                holdsOverFullScreen: Self.holdsOverFullScreen,
                holdsDuringCapture: Self.holdsDuringCapture,
                holdsDuringCalendarEvents: Self.holdsDuringCalendarEvents
            ),
            cooldown: Self.cooldown,
            quiet: Self.isQuietHour,
            idleSeconds: Self.idleSeconds,
            awayResetThreshold: Self.awayResetThreshold
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

    /// UserDefaults key for the arrival sound. Off by default: silence is the
    /// product's default posture, and sound is opt-in.
    static let soundEnabledKey = "soundEnabled"

    private var playsArrivalSound: Bool {
        UserDefaults.standard.bool(forKey: Self.soundEnabledKey)
    }

    /// UserDefaults key for how long the Mac sits with no input before
    /// reminders are held, in minutes.
    static let idleMinutesKey = "idleMinutes"
    static let defaultIdleMinutes = 2

    /// UserDefaults key for whether being away holds reminders at all. On by
    /// default; a missing value reads as enabled.
    static let idleHoldEnabledKey = "idleHoldEnabled"

    /// UserDefaults key for whether a full-screen frontmost app holds
    /// reminders. On by default; a missing value reads as enabled.
    static let fullScreenHoldEnabledKey = "fullScreenHoldEnabled"

    /// UserDefaults key for whether an active camera or microphone holds
    /// reminders. On by default; a missing value reads as enabled.
    static let captureHoldEnabledKey = "captureHoldEnabled"

    /// Reads a hold toggle that defaults to on: a missing value is enabled,
    /// unlike UserDefaults' plain bool(forKey:).
    private static func holdEnabled(_ key: String) -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }

    private static func holdsOverFullScreen() -> Bool {
        holdEnabled(fullScreenHoldEnabledKey)
    }

    private static func holdsDuringCapture() -> Bool {
        holdEnabled(captureHoldEnabledKey)
    }

    /// UserDefaults key for whether a calendar event in progress holds
    /// reminders. Off by default: it needs calendar access the user grants.
    static let calendarHoldEnabledKey = "calendarHoldEnabled"

    private static func holdsDuringCalendarEvents() -> Bool {
        UserDefaults.standard.bool(forKey: calendarHoldEnabledKey)
    }

    @ObservationIgnored private let calendarAccess = CalendarMonitor()

    /// Asks for calendar access when the hold is turned on. Returns whether
    /// access is granted, so the toggle can fall back off after a denial.
    func requestCalendarAccess() async -> Bool {
        await calendarAccess.requestAccess()
    }

    private static func idleThreshold() -> TimeInterval {
        // An infinite threshold turns the idle check off without the gate
        // needing to know the setting exists.
        guard holdEnabled(idleHoldEnabledKey) else { return .infinity }
        let stored = UserDefaults.standard.integer(forKey: idleMinutesKey)
        return TimeInterval((stored > 0 ? stored : defaultIdleMinutes) * 60)
    }

    /// UserDefaults key for whether returning from a real break restarts every
    /// interval. On by default; the break already was the pause.
    static let awayResetEnabledKey = "awayResetEnabled"

    /// The away length that counts as a real break: the same "away for" value
    /// the idle hold uses, so away means one thing everywhere. Nil turns the
    /// reset off.
    private static func awayResetThreshold() -> TimeInterval? {
        guard holdEnabled(awayResetEnabledKey) else { return nil }
        let stored = UserDefaults.standard.integer(forKey: idleMinutesKey)
        return TimeInterval((stored > 0 ? stored : defaultIdleMinutes) * 60)
    }

    private static func idleSeconds() -> TimeInterval {
        IdleMonitor().secondsSinceInput()
    }

    /// UserDefaults key for the minimum gap between two appearances, in
    /// seconds, so back-to-back reminders never stack.
    static let cooldownSecondsKey = "cooldownSeconds"
    static let defaultCooldownSeconds = 120

    private static func cooldown() -> TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: cooldownSecondsKey)
        return TimeInterval(stored > 0 ? stored : defaultCooldownSeconds)
    }

    /// UserDefaults keys for quiet hours: a daily window in which due reminders
    /// are skipped, like a scheduled pause. Off by default.
    static let quietHoursEnabledKey = "quietHoursEnabled"
    static let quietStartMinutesKey = "quietStartMinutes"
    static let quietEndMinutesKey = "quietEndMinutes"
    static let defaultQuietStartMinutes = 21 * 60
    static let defaultQuietEndMinutes = 8 * 60

    private static func quietHours() -> DailyWindow? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: quietHoursEnabledKey) else { return nil }
        let start = defaults.object(forKey: quietStartMinutesKey) as? Int ?? defaultQuietStartMinutes
        let end = defaults.object(forKey: quietEndMinutesKey) as? Int ?? defaultQuietEndMinutes
        return DailyWindow(startMinutes: start, endMinutes: end)
    }

    private static func isQuietHour(_ date: Date) -> Bool {
        quietHours()?.contains(date) ?? false
    }

    /// When the current quiet window ends, for the menu. Nil outside quiet hours.
    var quietUntil: Date? {
        Self.quietHours()?.currentWindowEnd(from: Date())
    }

    /// Show the first enabled reminder now, without waiting out an interval.
    /// With everything disabled, a sample line keeps the preview working.
    func preview() {
        let reminder = reminders.first(where: \.isEnabled)
            ?? Reminder(label: "Preview", message: "This is how a reminder looks.", interval: 60, mood: .custom)
        presenter.autoDismissDelay = autoDismissDelay
        presenter.playsArrivalSound = playsArrivalSound
        presenter.show(reminder: reminder) { _ in }
    }

    private func deliver(_ reminder: Reminder) {
        presenter.autoDismissDelay = autoDismissDelay
        presenter.playsArrivalSound = playsArrivalSound
        presenter.show(reminder: reminder) { [weak self] outcome in
            self?.handle(outcome, for: reminder)
        }
    }

    private func handle(_ outcome: ReminderOutcome, for reminder: Reminder) {
        switch outcome {
        case .snoozed:
            scheduler?.snooze(reminder.id, by: reminder.snoozeInterval ?? snoozeInterval)
        case .dismissed, .autoDismissed:
            // A one-time reminder is done once seen. It stays in the list,
            // disabled, so it can be reused with a new date or deleted.
            if reminder.isOneTime {
                setEnabled(false, for: reminder)
            }
        }
    }

    /// A fresh custom reminder, not yet added. The editor commits it through
    /// `add` only on save, so cancelling the add sheet leaves nothing behind.
    func newCustomReminder() -> Reminder {
        Reminder(label: "New reminder", message: "Reminder.", interval: 30 * 60, mood: .custom)
    }

    /// Apply a one-click preset to the built-ins. Custom reminders and the
    /// existing schedule handling (interval changes reschedule) do the rest.
    func apply(_ preset: Preset) {
        reminders = preset.applied(to: reminders)
        persist()
    }

    @ObservationIgnored private lazy var quickAddPanel = QuickAddPanelController()

    func showQuickAdd() {
        quickAddPanel.show(model: self)
    }

    /// Parse one plain sentence and add the reminder it describes. Nil means
    /// the sentence was not understood and nothing was added.
    @discardableResult
    func quickAdd(_ input: String) -> Reminder? {
        guard let reminder = QuickAddParser.parse(input) else { return nil }
        add(reminder)
        return reminder
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

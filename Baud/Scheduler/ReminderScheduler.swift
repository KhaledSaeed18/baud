import Foundation
import Observation

/// A reminder held back because the moment was bad, with the time it was
/// originally due so the queue can drain oldest first.
struct HeldReminder {
    let reminder: Reminder
    let originalDue: Date
}

/// Decides when reminders fire. It owns each reminder's next fire Date, the held
/// queue, pause state, a single coordinating wait, and wake-from-sleep recovery.
/// No AppKit and no SwiftUI, so it runs and is tested with no window on screen.
/// Observable so the menu can read the next fire and the pause state.
@MainActor
@Observable
final class ReminderScheduler {
    private(set) var reminders: [Reminder]
    private(set) var nextFire: [UUID: Date] = [:]
    private(set) var held: [UUID: HeldReminder] = [:]
    private(set) var pausedUntil: Date?

    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let deliver: (Reminder) -> Void
    @ObservationIgnored private let gate: SuppressionGate
    @ObservationIgnored private let cooldown: TimeInterval
    @ObservationIgnored private let recheckInterval: TimeInterval
    @ObservationIgnored private var lastDelivery: Date?
    @ObservationIgnored private var wait: Task<Void, Never>?

    init(
        reminders: [Reminder],
        gate: SuppressionGate? = nil,
        cooldown: TimeInterval = 120,
        recheckInterval: TimeInterval = 30,
        now: @escaping () -> Date = Date.init,
        deliver: @escaping (Reminder) -> Void
    ) {
        self.reminders = reminders
        self.gate = gate ?? ClearGate()
        self.cooldown = cooldown
        self.recheckInterval = recheckInterval
        self.now = now
        self.deliver = deliver
    }

    func start() {
        seed(reference: now())
        arm()
    }

    func stop() {
        wait?.cancel()
        wait = nil
    }

    /// Recompute after the Mac wakes. A wait that slept through its fire time is
    /// re-evaluated here, so nothing is missed and nothing dumps as a backlog.
    func handleWake() {
        tick()
    }

    // Pause: silence the app without quitting it. Due reminders are skipped, not
    // held, so resuming does not pop a backlog.

    func pause(until date: Date) {
        pausedUntil = date
        arm()
    }

    func pause(for duration: TimeInterval) {
        pause(until: now().addingTimeInterval(duration))
    }

    func pauseIndefinitely() {
        pausedUntil = .distantFuture
        arm()
    }

    func resume() {
        pausedUntil = nil
        arm()
    }

    /// Postpone a reminder so it fires again after a short delay, for a snooze.
    func snooze(_ id: UUID, by delay: TimeInterval) {
        guard reminders.contains(where: { $0.id == id && $0.isEnabled }) else { return }
        nextFire[id] = now().addingTimeInterval(delay)
        arm()
    }

    func isPaused(at current: Date) -> Bool {
        guard let until = pausedUntil else { return false }
        return current < until
    }

    var isPaused: Bool { isPaused(at: now()) }

    /// Replace the reminder set after an edit, keeping the schedule for reminders
    /// that are unchanged and dropping it for those removed or disabled.
    func update(reminders newReminders: [Reminder]) {
        let previousIntervals = Dictionary(uniqueKeysWithValues: reminders.map { ($0.id, $0.interval) })
        reminders = newReminders
        let current = now()
        let enabledIDs = Set(newReminders.filter(\.isEnabled).map(\.id))
        for reminder in newReminders where reminder.isEnabled {
            // A changed interval takes effect now, not after the stale fire date.
            if nextFire[reminder.id] == nil || previousIntervals[reminder.id] != reminder.interval {
                nextFire[reminder.id] = current.addingTimeInterval(reminder.interval)
            }
        }
        for id in nextFire.keys where !enabledIDs.contains(id) { nextFire[id] = nil }
        for id in held.keys where !enabledIDs.contains(id) { held[id] = nil }
        arm()
    }

    /// The soonest enabled reminder and when it next fires, for display.
    func nextUp() -> (reminder: Reminder, date: Date)? {
        reminders
            .compactMap { reminder in nextFire[reminder.id].map { (reminder, $0) } }
            .min(by: { $0.1 < $1.1 })
    }

    /// The next fire for every enabled reminder, measured from a reference time.
    func seed(reference: Date) {
        nextFire = [:]
        for reminder in reminders where reminder.isEnabled {
            nextFire[reminder.id] = reference.addingTimeInterval(reminder.interval)
        }
    }

    /// Deliver each due reminder when the moment is good, otherwise hold it (or
    /// skip it while paused). The schedule advances either way, so a held or
    /// paused reminder does not re-fire every tick, and missed occurrences
    /// collapse to one.
    @discardableResult
    func fireDue(at current: Date) -> [Reminder] {
        var delivered: [Reminder] = []
        let paused = isPaused(at: current)
        for reminder in reminders where reminder.isEnabled {
            guard let due = nextFire[reminder.id], due <= current else { continue }
            nextFire[reminder.id] = Self.nextOccurrence(after: current, anchor: due, interval: reminder.interval)
            guard !paused else { continue }
            if deliverOrHold(reminder, due: due, at: current) {
                delivered.append(reminder)
            }
        }
        return delivered
    }

    /// Deliver at most one held reminder once the moment is good. Never flushes
    /// the queue: nobody wants four characters in a row after a meeting.
    @discardableResult
    func processHeld(at current: Date) -> Reminder? {
        guard canDeliver(at: current) else { return nil }
        guard let next = held.values.min(by: { $0.originalDue < $1.originalDue }) else { return nil }
        held[next.reminder.id] = nil
        record(delivery: next.reminder, at: current)
        return next.reminder
    }

    /// The first occurrence strictly after `current`, stepping by interval from
    /// the anchor. Pure, so the collapse behaviour is tested directly.
    static func nextOccurrence(after current: Date, anchor: Date, interval: TimeInterval) -> Date {
        guard interval > 0 else { return current }
        guard anchor <= current else { return anchor }
        let elapsed = current.timeIntervalSince(anchor)
        let steps = (elapsed / interval).rounded(.down) + 1
        return anchor.addingTimeInterval(steps * interval)
    }

    private func deliverOrHold(_ reminder: Reminder, due: Date, at current: Date) -> Bool {
        if canDeliver(at: current) {
            record(delivery: reminder, at: current)
            return true
        }
        if held[reminder.id] == nil {
            held[reminder.id] = HeldReminder(reminder: reminder, originalDue: due)
        }
        return false
    }

    private func canDeliver(at current: Date) -> Bool {
        !isPaused(at: current) && gate.currentReason() == nil && cooldownElapsed(at: current)
    }

    private func cooldownElapsed(at current: Date) -> Bool {
        guard let last = lastDelivery else { return true }
        return current.timeIntervalSince(last) >= cooldown
    }

    private func record(delivery reminder: Reminder, at current: Date) {
        deliver(reminder)
        lastDelivery = current
    }

    private func tick() {
        let current = now()
        if let until = pausedUntil, until != .distantFuture, current >= until {
            pausedUntil = nil
        }
        fireDue(at: current)
        processHeld(at: current)
        arm()
    }

    /// A single coordinating wait. It wakes for the next fire date, on a recheck
    /// cadence while anything is held, and at the end of a timed pause.
    private func arm() {
        wait?.cancel()
        let current = now()
        var target: Date?
        if let until = pausedUntil {
            target = until == .distantFuture ? nil : until
        } else {
            target = nextFire.values.min()
            if !held.isEmpty {
                let recheck = current.addingTimeInterval(recheckInterval)
                target = min(target ?? recheck, recheck)
            }
        }
        guard let target else {
            wait = nil
            return
        }
        wait = Task { [weak self] in
            guard let self else { return }
            let delay = max(0, target.timeIntervalSince(self.now()))
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self.tick()
        }
    }
}

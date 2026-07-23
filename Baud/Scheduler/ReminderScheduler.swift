import Foundation

/// A reminder held back because the moment was bad, with the time it was
/// originally due so the queue can drain oldest first.
struct HeldReminder {
    let reminder: Reminder
    let originalDue: Date
}

/// Decides when reminders fire. It owns each reminder's next fire Date, the held
/// queue, a single coordinating wait, and wake-from-sleep recovery. No AppKit and
/// no SwiftUI, so it runs and is tested with no window on screen.
@MainActor
final class ReminderScheduler {
    private(set) var reminders: [Reminder]
    private(set) var nextFire: [UUID: Date] = [:]
    private(set) var held: [UUID: HeldReminder] = [:]

    private let now: () -> Date
    private let deliver: (Reminder) -> Void
    private let gate: SuppressionGate
    private let cooldown: TimeInterval
    private let recheckInterval: TimeInterval
    private var lastDelivery: Date?
    private var wait: Task<Void, Never>?

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

    /// The next fire for every enabled reminder, measured from a reference time.
    func seed(reference: Date) {
        nextFire = [:]
        for reminder in reminders where reminder.isEnabled {
            nextFire[reminder.id] = reference.addingTimeInterval(reminder.interval)
        }
    }

    /// Deliver each due reminder when the moment is good, otherwise hold it. The
    /// reminder's own schedule advances either way, so a held reminder does not
    /// re-fire every tick. Occurrences missed while asleep collapse to one.
    @discardableResult
    func fireDue(at current: Date) -> [Reminder] {
        var delivered: [Reminder] = []
        for reminder in reminders where reminder.isEnabled {
            guard let due = nextFire[reminder.id], due <= current else { continue }
            nextFire[reminder.id] = Self.nextOccurrence(after: current, anchor: due, interval: reminder.interval)
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
        gate.currentReason() == nil && cooldownElapsed(at: current)
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
        fireDue(at: current)
        processHeld(at: current)
        arm()
    }

    /// A single coordinating wait. It wakes for the next fire date, and also on a
    /// recheck cadence while anything is held, since there is no fire date for
    /// "the meeting ended".
    private func arm() {
        wait?.cancel()
        var target = nextFire.values.min()
        if !held.isEmpty {
            let recheck = now().addingTimeInterval(recheckInterval)
            target = min(target ?? recheck, recheck)
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

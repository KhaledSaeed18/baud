import Foundation

/// Decides when reminders fire. It owns each reminder's next fire Date, a single
/// coordinating wait, and wake-from-sleep recovery. No AppKit and no SwiftUI, so
/// it runs and is tested with no window on screen.
@MainActor
final class ReminderScheduler {
    private(set) var reminders: [Reminder]
    private(set) var nextFire: [UUID: Date] = [:]

    private let now: () -> Date
    private let deliver: (Reminder) -> Void
    private var wait: Task<Void, Never>?

    init(
        reminders: [Reminder],
        now: @escaping () -> Date = Date.init,
        deliver: @escaping (Reminder) -> Void
    ) {
        self.reminders = reminders
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
        fireDue(at: now())
        arm()
    }

    /// The next fire for every enabled reminder, measured from a reference time.
    func seed(reference: Date) {
        nextFire = [:]
        for reminder in reminders where reminder.isEnabled {
            nextFire[reminder.id] = reference.addingTimeInterval(reminder.interval)
        }
    }

    /// Deliver each reminder due at `current` exactly once, then advance it to
    /// its next occurrence strictly after `current`. Occurrences missed while
    /// asleep collapse to a single delivery.
    @discardableResult
    func fireDue(at current: Date) -> [Reminder] {
        var delivered: [Reminder] = []
        for reminder in reminders where reminder.isEnabled {
            guard let due = nextFire[reminder.id], due <= current else { continue }
            deliver(reminder)
            delivered.append(reminder)
            nextFire[reminder.id] = Self.nextOccurrence(after: current, anchor: due, interval: reminder.interval)
        }
        return delivered
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

    private func arm() {
        wait?.cancel()
        guard let earliest = nextFire.values.min() else {
            wait = nil
            return
        }
        wait = Task { [weak self] in
            guard let self else { return }
            let delay = max(0, earliest.timeIntervalSince(self.now()))
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self.fireDue(at: self.now())
            self.arm()
        }
    }
}

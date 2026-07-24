import Testing
import Foundation
@testable import Baud

@MainActor
struct ReminderSchedulerTests {
    private func reminder(interval: TimeInterval, enabled: Bool = true) -> Reminder {
        Reminder(label: "t", message: "m", interval: interval, mood: .move, isEnabled: enabled)
    }

    @Test func seedComputesNextFireFromReference() {
        let r = reminder(interval: 60)
        let scheduler = ReminderScheduler(reminders: [r], deliver: { _ in })
        let t0 = Date(timeIntervalSince1970: 1000)
        scheduler.seed(reference: t0)
        #expect(scheduler.nextFire[r.id] == t0.addingTimeInterval(60))
    }

    @Test func seedSkipsDisabledReminders() {
        let on = reminder(interval: 60)
        let off = reminder(interval: 60, enabled: false)
        let scheduler = ReminderScheduler(reminders: [on, off], deliver: { _ in })
        scheduler.seed(reference: Date(timeIntervalSince1970: 0))
        #expect(scheduler.nextFire[on.id] != nil)
        #expect(scheduler.nextFire[off.id] == nil)
    }

    @Test func fireDueDeliversOnceAndAdvances() {
        let r = reminder(interval: 60)
        var delivered: [Reminder] = []
        let scheduler = ReminderScheduler(reminders: [r], deliver: { delivered.append($0) })
        let t0 = Date(timeIntervalSince1970: 0)
        scheduler.seed(reference: t0)
        let fired = scheduler.fireDue(at: t0.addingTimeInterval(60))
        #expect(fired.count == 1)
        #expect(delivered.count == 1)
        #expect(scheduler.nextFire[r.id] == t0.addingTimeInterval(120))
    }

    @Test func fireDueDoesNotDeliverBeforeDue() {
        let r = reminder(interval: 60)
        var delivered = 0
        let scheduler = ReminderScheduler(reminders: [r], deliver: { _ in delivered += 1 })
        let t0 = Date(timeIntervalSince1970: 0)
        scheduler.seed(reference: t0)
        _ = scheduler.fireDue(at: t0.addingTimeInterval(59))
        #expect(delivered == 0)
        #expect(scheduler.nextFire[r.id] == t0.addingTimeInterval(60))
    }

    @Test func missedOccurrencesCollapseToOne() {
        let r = reminder(interval: 60)
        var delivered = 0
        let scheduler = ReminderScheduler(reminders: [r], deliver: { _ in delivered += 1 })
        let t0 = Date(timeIntervalSince1970: 0)
        scheduler.seed(reference: t0)
        // Asleep for an hour: sixty occurrences passed.
        let wake = t0.addingTimeInterval(3600)
        let fired = scheduler.fireDue(at: wake)
        #expect(fired.count == 1)
        #expect(delivered == 1)
        if let next = scheduler.nextFire[r.id] {
            #expect(next > wake)
        } else {
            Issue.record("expected a next fire date after collapse")
        }
    }

    @Test func updateReschedulesWhenIntervalChanges() {
        var r = reminder(interval: 3600)
        let t0 = Date(timeIntervalSince1970: 0)
        var current = t0
        let scheduler = ReminderScheduler(reminders: [r], now: { current }, deliver: { _ in })
        scheduler.seed(reference: t0)

        current = t0.addingTimeInterval(300)
        r.interval = 60
        scheduler.update(reminders: [r])
        #expect(scheduler.nextFire[r.id] == current.addingTimeInterval(60))
    }

    @Test func updateKeepsScheduleWhenIntervalUnchanged() {
        var r = reminder(interval: 3600)
        let t0 = Date(timeIntervalSince1970: 0)
        var current = t0
        let scheduler = ReminderScheduler(reminders: [r], now: { current }, deliver: { _ in })
        scheduler.seed(reference: t0)

        current = t0.addingTimeInterval(300)
        r.label = "renamed"
        scheduler.update(reminders: [r])
        #expect(scheduler.nextFire[r.id] == t0.addingTimeInterval(3600))
    }

    @Test func dueOutsideActiveHoursWaitsForTheWindow() {
        let calendar = Calendar.current
        // 16:00 today, with a 12:00 to 14:00 window.
        let afternoon = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: Date()) ?? Date()
        var r = reminder(interval: 3600)
        r.activeHours = DailyWindow(startMinutes: 12 * 60, endMinutes: 14 * 60)
        var delivered = 0
        let scheduler = ReminderScheduler(reminders: [r], deliver: { _ in delivered += 1 })
        scheduler.seed(reference: afternoon.addingTimeInterval(-3600))

        scheduler.fireDue(at: afternoon)
        #expect(delivered == 0)
        #expect(scheduler.held.isEmpty)
        if let next = scheduler.nextFire[r.id] {
            let components = calendar.dateComponents([.hour, .minute], from: next)
            #expect(components.hour == 12)
            #expect(components.minute == 0)
            #expect(next > afternoon)
        } else {
            Issue.record("expected a deferred fire date")
        }
    }

    @Test func dueInsideActiveHoursDeliversNormally() {
        let calendar = Calendar.current
        let lunch = calendar.date(bySettingHour: 13, minute: 0, second: 0, of: Date()) ?? Date()
        var r = reminder(interval: 1800)
        r.activeHours = DailyWindow(startMinutes: 12 * 60, endMinutes: 14 * 60)
        var delivered = 0
        let scheduler = ReminderScheduler(reminders: [r], deliver: { _ in delivered += 1 })
        scheduler.seed(reference: lunch.addingTimeInterval(-1800))

        scheduler.fireDue(at: lunch)
        #expect(delivered == 1)
    }

    @Test func returnFromABreakResetsTheSchedule() {
        let r = reminder(interval: 1800)
        var idle: TimeInterval = 0
        var delivered = 0
        let t0 = Date(timeIntervalSince1970: 0)
        var current = t0
        let scheduler = ReminderScheduler(
            reminders: [r],
            idleSeconds: { idle },
            awayResetThreshold: { 300 },
            now: { current },
            deliver: { _ in delivered += 1 }
        )
        scheduler.seed(reference: t0)

        // Ten minutes away, noticed mid-break.
        current = t0.addingTimeInterval(600)
        idle = 600
        scheduler.noticeActivity(at: current)

        // Back at the desk: every interval restarts from the return.
        current = t0.addingTimeInterval(660)
        idle = 5
        scheduler.noticeActivity(at: current)
        #expect(scheduler.nextFire[r.id] == current.addingTimeInterval(1800))
        #expect(delivered == 0)
    }

    @Test func breakDropsStaleHeldReminders() {
        let r = reminder(interval: 60)
        var idle: TimeInterval = 0
        let t0 = Date(timeIntervalSince1970: 0)
        var current = t0
        let gate = StubGate()
        let scheduler = ReminderScheduler(
            reminders: [r],
            gate: gate,
            idleSeconds: { idle },
            awayResetThreshold: { 300 },
            now: { current },
            deliver: { _ in }
        )
        scheduler.seed(reference: t0)

        // Held during a bad moment, then a long break happens.
        gate.reason = .idle
        current = t0.addingTimeInterval(60)
        scheduler.fireDue(at: current)
        #expect(!scheduler.held.isEmpty)

        current = t0.addingTimeInterval(600)
        idle = 540
        scheduler.noticeActivity(at: current)

        // The return clears the stale hold instead of delivering it.
        gate.reason = nil
        current = t0.addingTimeInterval(660)
        idle = 5
        scheduler.noticeActivity(at: current)
        #expect(scheduler.held.isEmpty)
        #expect(scheduler.processHeld(at: current) == nil)
    }

    @Test func shortAbsenceDoesNotReset() {
        let r = reminder(interval: 1800)
        var idle: TimeInterval = 0
        let t0 = Date(timeIntervalSince1970: 0)
        var current = t0
        let scheduler = ReminderScheduler(
            reminders: [r],
            idleSeconds: { idle },
            awayResetThreshold: { 300 },
            now: { current },
            deliver: { _ in }
        )
        scheduler.seed(reference: t0)

        current = t0.addingTimeInterval(120)
        idle = 100
        scheduler.noticeActivity(at: current)
        current = t0.addingTimeInterval(180)
        idle = 5
        scheduler.noticeActivity(at: current)
        #expect(scheduler.nextFire[r.id] == t0.addingTimeInterval(1800))
    }

    @Test func oneTimeReminderFiresOnceAndOnlyOnce() {
        let t0 = Date(timeIntervalSince1970: 0)
        var r = reminder(interval: 60)
        r.fireAt = t0.addingTimeInterval(300)
        var delivered = 0
        let scheduler = ReminderScheduler(reminders: [r], now: { t0 }, deliver: { _ in delivered += 1 })
        scheduler.seed(reference: t0)
        #expect(scheduler.nextFire[r.id] == r.fireAt)

        scheduler.fireDue(at: t0.addingTimeInterval(300))
        #expect(delivered == 1)
        #expect(scheduler.nextFire[r.id] == nil)

        // Nothing later, and an edit-driven update does not resurrect it.
        scheduler.fireDue(at: t0.addingTimeInterval(600))
        scheduler.update(reminders: [r])
        #expect(delivered == 1)
        #expect(scheduler.nextFire[r.id] == nil)
    }

    @Test func staleOneTimeReminderIsNotScheduled() {
        let t0 = Date(timeIntervalSince1970: 100_000)
        var r = reminder(interval: 60)
        r.fireAt = t0.addingTimeInterval(-ReminderScheduler.oneTimeGrace - 1)
        let scheduler = ReminderScheduler(reminders: [r], now: { t0 }, deliver: { _ in })
        scheduler.seed(reference: t0)
        #expect(scheduler.nextFire[r.id] == nil)
    }

    @Test func recentlyMissedOneTimeReminderStillFires() {
        let t0 = Date(timeIntervalSince1970: 100_000)
        var r = reminder(interval: 60)
        r.fireAt = t0.addingTimeInterval(-300)
        var delivered = 0
        let scheduler = ReminderScheduler(reminders: [r], now: { t0 }, deliver: { _ in delivered += 1 })
        scheduler.seed(reference: t0)
        scheduler.fireDue(at: t0)
        #expect(delivered == 1)
    }

    @Test func snoozedOneTimeReminderComesBackOnce() {
        let t0 = Date(timeIntervalSince1970: 0)
        var current = t0
        var r = reminder(interval: 60)
        r.fireAt = t0.addingTimeInterval(60)
        var delivered = 0
        let scheduler = ReminderScheduler(
            reminders: [r],
            cooldown: { 0 },
            now: { current },
            deliver: { _ in delivered += 1 }
        )
        scheduler.seed(reference: t0)

        current = t0.addingTimeInterval(60)
        scheduler.fireDue(at: current)
        #expect(delivered == 1)

        scheduler.snooze(r.id, by: 600)
        current = t0.addingTimeInterval(660)
        scheduler.fireDue(at: current)
        #expect(delivered == 2)
        #expect(scheduler.nextFire[r.id] == nil)
    }

    @Test func newDateRevivesASpentOneTimeReminder() {
        let t0 = Date(timeIntervalSince1970: 0)
        var current = t0
        var r = reminder(interval: 60)
        r.fireAt = t0.addingTimeInterval(60)
        let scheduler = ReminderScheduler(reminders: [r], now: { current }, deliver: { _ in })
        scheduler.seed(reference: t0)

        current = t0.addingTimeInterval(60)
        scheduler.fireDue(at: current)
        #expect(scheduler.nextFire[r.id] == nil)

        r.fireAt = t0.addingTimeInterval(900)
        scheduler.update(reminders: [r])
        #expect(scheduler.nextFire[r.id] == r.fireAt)
    }

    @Test func dueOnADisallowedDayWaitsForTheNextAllowedOne() {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.component(.weekday, from: now)
        let tomorrow = today % 7 + 1
        let dayAfter = tomorrow % 7 + 1

        var r = reminder(interval: 3600)
        r.weekdays = [dayAfter]
        var delivered = 0
        let scheduler = ReminderScheduler(reminders: [r], deliver: { _ in delivered += 1 })
        scheduler.seed(reference: now.addingTimeInterval(-3600))

        scheduler.fireDue(at: now)
        #expect(delivered == 0)
        #expect(scheduler.held.isEmpty)
        if let next = scheduler.nextFire[r.id] {
            #expect(calendar.component(.weekday, from: next) == dayAfter)
            #expect(next > now)
        } else {
            Issue.record("expected a deferred fire date")
        }
    }

    @Test func nextAllowedDayStartLandsOnTheRightWeekday() {
        let calendar = Calendar.current
        let now = Date()
        for target in 1...7 {
            let next = ReminderScheduler.nextAllowedDayStart(after: now, weekdays: [target])
            #expect(calendar.component(.weekday, from: next) == target)
            #expect(next > now)
        }
    }

    @Test func nextOccurrenceIsStrictlyAfterCurrent() {
        let anchor = Date(timeIntervalSince1970: 0)
        let onBoundary = ReminderScheduler.nextOccurrence(after: anchor.addingTimeInterval(120), anchor: anchor, interval: 60)
        #expect(onBoundary == anchor.addingTimeInterval(180))
        let midInterval = ReminderScheduler.nextOccurrence(after: anchor.addingTimeInterval(90), anchor: anchor, interval: 60)
        #expect(midInterval == anchor.addingTimeInterval(120))
    }
}

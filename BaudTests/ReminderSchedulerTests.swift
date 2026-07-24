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

    @Test func nextOccurrenceIsStrictlyAfterCurrent() {
        let anchor = Date(timeIntervalSince1970: 0)
        let onBoundary = ReminderScheduler.nextOccurrence(after: anchor.addingTimeInterval(120), anchor: anchor, interval: 60)
        #expect(onBoundary == anchor.addingTimeInterval(180))
        let midInterval = ReminderScheduler.nextOccurrence(after: anchor.addingTimeInterval(90), anchor: anchor, interval: 60)
        #expect(midInterval == anchor.addingTimeInterval(120))
    }
}

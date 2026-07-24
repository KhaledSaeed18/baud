import Testing
import Foundation
@testable import Baud

struct QuietHoursTests {
    private let calendar = Calendar.current

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    @Test func sameDayWindowCoversItsHours() {
        let quiet = QuietHours(startMinutes: 13 * 60, endMinutes: 14 * 60)
        #expect(quiet.contains(date(hour: 13, minute: 30)))
        #expect(!quiet.contains(date(hour: 12, minute: 59)))
        #expect(!quiet.contains(date(hour: 14)))
    }

    @Test func midnightWrapCoversEveningAndMorning() {
        let quiet = QuietHours(startMinutes: 21 * 60, endMinutes: 8 * 60)
        #expect(quiet.contains(date(hour: 23)))
        #expect(quiet.contains(date(hour: 3)))
        #expect(quiet.contains(date(hour: 7, minute: 59)))
        #expect(!quiet.contains(date(hour: 8)))
        #expect(!quiet.contains(date(hour: 12)))
        #expect(!quiet.contains(date(hour: 20, minute: 59)))
    }

    @Test func equalEndsAreAnEmptyWindow() {
        let quiet = QuietHours(startMinutes: 9 * 60, endMinutes: 9 * 60)
        #expect(!quiet.contains(date(hour: 9)))
        #expect(!quiet.contains(date(hour: 15)))
    }

    @Test func windowEndIsNilOutsideAndSetInside() {
        let quiet = QuietHours(startMinutes: 21 * 60, endMinutes: 8 * 60)
        #expect(quiet.currentWindowEnd(from: date(hour: 12)) == nil)
        if let end = quiet.currentWindowEnd(from: date(hour: 23)) {
            let components = calendar.dateComponents([.hour, .minute], from: end)
            #expect(components.hour == 8)
            #expect(components.minute == 0)
        } else {
            Issue.record("expected an end inside the window")
        }
    }

    @MainActor
    @Test func quietHoursSkipDueRemindersWithoutHolding() {
        let r = Reminder(label: "t", message: "m", interval: 60, mood: .move)
        var delivered = 0
        var isQuiet = true
        let t0 = Date(timeIntervalSince1970: 0)
        let scheduler = ReminderScheduler(
            reminders: [r],
            quiet: { _ in isQuiet },
            deliver: { _ in delivered += 1 }
        )
        scheduler.seed(reference: t0)

        // Due during quiet hours: skipped, not held, and the schedule advances.
        scheduler.fireDue(at: t0.addingTimeInterval(60))
        #expect(delivered == 0)
        #expect(scheduler.held.isEmpty)
        #expect(scheduler.nextFire[r.id] == t0.addingTimeInterval(120))

        // The morning starts clean: nothing pops when quiet hours end.
        isQuiet = false
        #expect(scheduler.processHeld(at: t0.addingTimeInterval(90)) == nil)
    }
}

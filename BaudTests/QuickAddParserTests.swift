import Testing
import Foundation
@testable import Baud

struct QuickAddParserTests {
    private let noon: Date = {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
    }()

    @Test func parsesEveryWithMinutes() throws {
        let r = try #require(QuickAddParser.parse("drink water every 45 minutes"))
        #expect(r.interval == 45 * 60)
        #expect(r.fireAt == nil)
        #expect(r.mood == .water)
        #expect(r.label == "Drink water")
        #expect(r.message == "Drink water.")
    }

    @Test func parsesBareEveryHourAsOne() throws {
        let r = try #require(QuickAddParser.parse("stand up every hour"))
        #expect(r.interval == 3600)
        #expect(r.mood == .move)
    }

    @Test func parsesInAsOneTime() throws {
        let r = try #require(QuickAddParser.parse("grab a coffee in 5 minutes", now: noon))
        #expect(r.fireAt == noon.addingTimeInterval(5 * 60))
        #expect(r.label == "Grab a coffee")
        #expect(r.mood == .custom)
    }

    @Test func parsesAtWithMeridiem() throws {
        let r = try #require(QuickAddParser.parse("meeting at 3 PM", now: noon))
        let fireAt = try #require(r.fireAt)
        let components = Calendar.current.dateComponents([.hour, .minute], from: fireAt)
        #expect(components.hour == 15)
        #expect(components.minute == 0)
        #expect(fireAt > noon)
    }

    @Test func pastTimeRollsToTomorrow() throws {
        let r = try #require(QuickAddParser.parse("review at 9am", now: noon))
        let fireAt = try #require(r.fireAt)
        #expect(fireAt > noon)
        #expect(Calendar.current.component(.hour, from: fireAt) == 9)
    }

    @Test func parsesTwentyFourHourTimeWithMinutes() throws {
        let r = try #require(QuickAddParser.parse("call Tom at 15:30", now: noon))
        let fireAt = try #require(r.fireAt)
        let components = Calendar.current.dateComponents([.hour, .minute], from: fireAt)
        #expect(components.hour == 15)
        #expect(components.minute == 30)
        #expect(r.label == "Call Tom")
    }

    @Test func parsesWeekdaySuffix() throws {
        let r = try #require(QuickAddParser.parse("stretch every 30 minutes on weekdays"))
        #expect(r.weekdays == [2, 3, 4, 5, 6])
        #expect(r.interval == 30 * 60)
        #expect(r.mood == .move)
    }

    @Test func parsesWeekendSuffix() throws {
        let r = try #require(QuickAddParser.parse("water the plants every 2 hours on weekends"))
        #expect(r.weekdays == [1, 7])
        #expect(r.interval == 2 * 3600)
    }

    @Test func stripsCarrierPhrase() throws {
        let r = try #require(QuickAddParser.parse("remind me to call Tom in 2 hours", now: noon))
        #expect(r.label == "Call Tom")
        #expect(r.fireAt == noon.addingTimeInterval(2 * 3600))
    }

    @Test func rejectsSentencesWithoutASchedule() {
        #expect(QuickAddParser.parse("just some words") == nil)
        #expect(QuickAddParser.parse("") == nil)
        #expect(QuickAddParser.parse("every 10 minutes") == nil)
        #expect(QuickAddParser.parse("water every 0 minutes") == nil)
        #expect(QuickAddParser.parse("meeting at 25") == nil)
        #expect(QuickAddParser.parse("meeting at 13pm") == nil)
    }

    @Test func quickAddedReminderIsCustomAndEnabled() throws {
        let r = try #require(QuickAddParser.parse("stretch every 20 minutes"))
        #expect(!r.isBuiltIn)
        #expect(r.isEnabled)
    }
}

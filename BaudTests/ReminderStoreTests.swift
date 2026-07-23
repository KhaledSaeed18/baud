import Testing
import Foundation
@testable import Baud

struct ReminderStoreTests {
    private func tempDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("BaudTests-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func firstLoadSeedsDefaults() {
        let store = ReminderStore(directory: tempDirectory())
        #expect(store.load() == DefaultReminders.all)
    }

    @Test func saveThenLoadRoundTrips() throws {
        let store = ReminderStore(directory: tempDirectory())
        var reminders = DefaultReminders.all
        reminders.append(Reminder(label: "Tea", message: "Tea.", interval: 900, mood: .custom))
        try store.save(reminders)
        #expect(store.load() == reminders)
    }
}

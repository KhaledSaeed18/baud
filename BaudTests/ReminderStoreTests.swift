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

    @Test func malformedFileFallsBackWithoutOverwriting() throws {
        let directory = tempDirectory()
        let store = ReminderStore(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let broken = Data("not json".utf8)
        try broken.write(to: store.fileURL)

        #expect(store.load() == DefaultReminders.all)
        #expect(try Data(contentsOf: store.fileURL) == broken)
    }

    @Test func saveThenLoadRoundTrips() throws {
        let store = ReminderStore(directory: tempDirectory())
        var reminders = DefaultReminders.all
        reminders.append(Reminder(label: "Tea", message: "Tea.", interval: 900, mood: .custom, snoozeInterval: 300))
        try store.save(reminders)
        #expect(store.load() == reminders)
    }
}

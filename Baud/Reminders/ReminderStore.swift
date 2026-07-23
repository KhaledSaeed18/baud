import Foundation

/// Loads and saves reminders as readable JSON in Application Support. Not
/// UserDefaults: the file is meant to be found, read, and edited by hand.
struct ReminderStore {
    let fileURL: URL

    init(directory: URL? = nil) {
        let base = directory ?? Self.defaultDirectory()
        fileURL = base.appendingPathComponent("reminders.json")
    }

    /// Reads the stored reminders, seeding the file with the built-ins on first
    /// run. A missing or unreadable file falls back to the built-ins so the user
    /// is never left with nothing.
    func load() -> [Reminder] {
        guard let data = try? Data(contentsOf: fileURL),
              let reminders = try? JSONDecoder().decode([Reminder].self, from: data)
        else {
            let defaults = DefaultReminders.all
            try? save(defaults)
            return defaults
        }
        return reminders
    }

    func save(_ reminders: [Reminder]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(reminders)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func defaultDirectory() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return support.appendingPathComponent("Baud", isDirectory: true)
    }
}

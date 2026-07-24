import EventKit

/// Whether a calendar event is in progress right now, read from the local
/// event store. Read-only, on-device, no account and nothing to sync: the
/// calendar is only consulted, never stored or sent anywhere.
@MainActor
final class CalendarMonitor {
    private let store = EKEventStore()

    /// True while a non-all-day event is on, in any calendar. Without calendar
    /// access this is always false, so the check is safe to leave wired in.
    func isEventInProgress() -> Bool {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return false }
        let now = Date()
        let predicate = store.predicateForEvents(
            withStart: now,
            end: now.addingTimeInterval(60),
            calendars: nil
        )
        return store.events(matching: predicate)
            .contains { !$0.isAllDay && $0.startDate <= now && $0.endDate > now }
    }

    /// Asks the system for read access to calendar events. Returns whether
    /// access is granted; a denial is a normal answer, not an error.
    func requestAccess() async -> Bool {
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess { return true }
        return (try? await store.requestFullAccessToEvents()) ?? false
    }
}

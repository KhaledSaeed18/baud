import Testing
import Foundation
@testable import Baud

@MainActor
final class StubGate: SuppressionGate {
    var reason: SuppressionReason?
    func currentReason() -> SuppressionReason? { reason }
}

@MainActor
struct SuppressionTests {
    private func reminder(interval: TimeInterval = 60) -> Reminder {
        Reminder(label: "t", message: "m", interval: interval, mood: .move)
    }

    @Test func suppressedReminderIsHeldNotDropped() {
        let gate = StubGate()
        gate.reason = .idle
        let r = reminder()
        var delivered = 0
        let scheduler = ReminderScheduler(reminders: [r], gate: gate, deliver: { _ in delivered += 1 })
        let t0 = Date(timeIntervalSince1970: 0)
        scheduler.seed(reference: t0)

        _ = scheduler.fireDue(at: t0.addingTimeInterval(60))

        #expect(delivered == 0)
        #expect(scheduler.held[r.id] != nil)
        // The schedule still advances, so it does not re-fire every tick.
        #expect(scheduler.nextFire[r.id] == t0.addingTimeInterval(120))
    }

    @Test func heldReminderDeliversWhenContextClears() {
        let gate = StubGate()
        gate.reason = .fullScreen
        let r = reminder()
        var delivered = 0
        let scheduler = ReminderScheduler(reminders: [r], gate: gate, deliver: { _ in delivered += 1 })
        let t0 = Date(timeIntervalSince1970: 0)
        scheduler.seed(reference: t0)
        _ = scheduler.fireDue(at: t0.addingTimeInterval(60))
        #expect(delivered == 0)

        gate.reason = nil
        let out = scheduler.processHeld(at: t0.addingTimeInterval(120))

        #expect(out?.id == r.id)
        #expect(delivered == 1)
        #expect(scheduler.held.isEmpty)
    }

    @Test func heldQueueDeliversOneAtATime() {
        let gate = StubGate()
        gate.reason = .cameraOrMicrophoneInUse
        let a = reminder()
        let b = reminder()
        var delivered: [UUID] = []
        let scheduler = ReminderScheduler(reminders: [a, b], gate: gate, cooldown: 100, deliver: { delivered.append($0.id) })
        let t0 = Date(timeIntervalSince1970: 0)
        scheduler.seed(reference: t0)
        _ = scheduler.fireDue(at: t0.addingTimeInterval(60))
        #expect(scheduler.held.count == 2)

        gate.reason = nil
        // Context clears: exactly one is delivered.
        _ = scheduler.processHeld(at: t0.addingTimeInterval(60))
        #expect(delivered.count == 1)
        #expect(scheduler.held.count == 1)

        // Immediately after, the cooldown blocks a second appearance.
        _ = scheduler.processHeld(at: t0.addingTimeInterval(70))
        #expect(delivered.count == 1)

        // Once the cooldown passes, the second is delivered.
        _ = scheduler.processHeld(at: t0.addingTimeInterval(200))
        #expect(delivered.count == 2)
        #expect(scheduler.held.isEmpty)
    }

    @Test func cooldownHoldsBackToBackDeliveries() {
        let a = reminder()
        let b = reminder()
        var delivered = 0
        let scheduler = ReminderScheduler(reminders: [a, b], cooldown: 100, deliver: { _ in delivered += 1 })
        let t0 = Date(timeIntervalSince1970: 0)
        scheduler.seed(reference: t0)

        // Both due at once: one shows, the other is held until the cooldown ends.
        _ = scheduler.fireDue(at: t0.addingTimeInterval(60))

        #expect(delivered == 1)
        #expect(scheduler.held.count == 1)
    }
}

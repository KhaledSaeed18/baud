import Testing
import Foundation
@testable import Baud

struct PresetTests {
    @Test func presetRewritesOnlyTweakedBuiltIns() throws {
        var reminders = DefaultReminders.all
        let custom = Reminder(label: "Tea", message: "Tea.", interval: 900, mood: .custom)
        reminders.append(custom)

        let applied = Preset.moreWater.applied(to: reminders)

        let water = try #require(applied.first { $0.id == DefaultReminders.water.id })
        #expect(water.interval == TimeInterval(30 * 60))
        #expect(water.isEnabled)
        // Everything without a tweak passes through unchanged.
        #expect(applied.first { $0.id == DefaultReminders.move.id } == DefaultReminders.move)
        #expect(applied.first { $0.id == custom.id } == custom)
        #expect(applied.count == reminders.count)
    }

    @Test func recommendedRestoresTheDefaults() {
        var changed = DefaultReminders.all
        for index in changed.indices {
            changed[index].interval = 5 * 60
            changed[index].isEnabled = false
        }
        let applied = Preset.recommended.applied(to: changed)
        #expect(applied == DefaultReminders.all)
    }

    @Test func everyPresetTweaksOnlyBuiltInIds() {
        let builtInIDs = Set(DefaultReminders.all.map(\.id))
        for preset in Preset.all {
            #expect(Set(preset.tweaks.keys).isSubset(of: builtInIDs))
        }
    }
}

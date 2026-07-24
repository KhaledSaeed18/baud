import SwiftUI

/// Lists reminders with an enable toggle each. Every reminder can be edited,
/// built-in and custom alike, since they are the same type. Only adding and
/// deleting are restricted to custom ones; a built-in keeps its place.
struct ReminderEditorView: View {
    let model: AppModel
    @State private var editing: EditingReminder?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(model.reminders) { reminder in
                    ReminderRow(reminder: reminder, model: model) {
                        editing = EditingReminder(reminder: reminder, isNew: false)
                    }
                }
            }
            Divider()
            HStack {
                Button("Add reminder") {
                    editing = EditingReminder(reminder: model.newCustomReminder(), isNew: true)
                }
                Spacer()
                Menu("Presets") {
                    ForEach(Preset.all) { preset in
                        Button(preset.name) { model.apply(preset) }
                    }
                }
                .fixedSize()
                .help("A starting point for the built-in reminders. Your own reminders are not touched.")
            }
            .padding(8)
        }
        .sheet(item: $editing) { target in
            ReminderDetailView(
                reminder: target.reminder,
                onSave: { saved in
                    if target.isNew { model.add(saved) } else { model.update(saved) }
                },
                onDelete: target.isNew || target.reminder.isBuiltIn ? nil : { model.delete(target.reminder) }
            )
        }
    }
}

// Tells the add flow from the edit flow, so a new reminder is committed only on
// save and cancelling the add sheet leaves nothing behind.
private struct EditingReminder: Identifiable {
    let reminder: Reminder
    let isNew: Bool
    var id: UUID { reminder.id }
}

private struct ReminderRow: View {
    let reminder: Reminder
    let model: AppModel
    let onEdit: () -> Void
    @AppStorage(AppModel.cooldownSecondsKey) private var cooldownSeconds = AppModel.defaultCooldownSeconds

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { reminder.isEnabled },
                set: { model.setEnabled($0, for: reminder) }
            ))
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.label)
                Text(intervalText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Edit", action: onEdit)
        }
        .padding(.vertical, 2)
    }

    // Show the interval in the same unit the editor would, so a 2 hr reminder does
    // not read as "Every 120 min" and a short one does not round to "Every 0 min".
    private var intervalText: String {
        if let fireAt = reminder.fireAt {
            return "Once at \(fireAt.formatted(date: .abbreviated, time: .shortened))"
        }
        let split = IntervalUnit.split(reminder.interval)
        var base = "Every \(split.value) \(split.unit.short)"
        if let window = reminder.activeHours {
            base += ", \(TimeOfDay.label(window.startMinutes)) to \(TimeOfDay.label(window.endMinutes))"
        }
        if let days = reminder.weekdays, !days.isEmpty, days.count < 7 {
            let symbols = Calendar.current.veryShortWeekdaySymbols
            base += ", " + days.sorted().map { symbols[$0 - 1] }.joined(separator: " ")
        }
        // An interval under the gap is not an error: the reminder is held and
        // paced by the gap instead. Say so quietly rather than warn.
        guard reminder.interval < TimeInterval(cooldownSeconds) else { return base }
        return "\(base), paced by the \(IntervalUnit.shortLabel(seconds: cooldownSeconds)) gap"
    }
}

private struct ReminderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Reminder
    @State private var value: Int
    @State private var unit: IntervalUnit
    @State private var snoozeMinutes: Int?
    @State private var hasActiveHours: Bool
    @State private var activeStartMinutes: Int
    @State private var activeEndMinutes: Int
    @State private var isOneTime: Bool
    @State private var fireAt: Date
    @State private var selectedWeekdays: Set<Int>
    private let onSave: (Reminder) -> Void
    private let onDelete: (() -> Void)?
    @AppStorage(AppModel.cooldownSecondsKey) private var cooldownSeconds = AppModel.defaultCooldownSeconds

    private static let minutePresets = [15, 20, 30, 45, 60]
    private static let snoozePresets = [5, 10, 15, 30]

    // A hand-edited file can hold a snooze outside the presets; keep it
    // selectable rather than snapping it to the nearest choice.
    private var snoozeChoices: [Int] {
        guard let current = snoozeMinutes, !Self.snoozePresets.contains(current) else {
            return Self.snoozePresets
        }
        return (Self.snoozePresets + [current]).sorted()
    }

    init(reminder: Reminder, onSave: @escaping (Reminder) -> Void, onDelete: (() -> Void)?) {
        _draft = State(initialValue: reminder)
        let split = IntervalUnit.split(reminder.interval)
        _value = State(initialValue: split.value)
        _unit = State(initialValue: split.unit)
        _snoozeMinutes = State(initialValue: reminder.snoozeInterval.map { Int($0 / 60) })
        _hasActiveHours = State(initialValue: reminder.activeHours != nil)
        _activeStartMinutes = State(initialValue: reminder.activeHours?.startMinutes ?? 9 * 60)
        _activeEndMinutes = State(initialValue: reminder.activeHours?.endMinutes ?? 17 * 60)
        _isOneTime = State(initialValue: reminder.isOneTime)
        _fireAt = State(initialValue: reminder.fireAt ?? Date().addingTimeInterval(3600))
        _selectedWeekdays = State(initialValue: reminder.weekdays ?? Set(1...7))
        self.onSave = onSave
        self.onDelete = onDelete
    }

    private var intervalSeconds: TimeInterval {
        TimeInterval(clamped(value)) * unit.secondsPerUnit
    }

    private func clamped(_ raw: Int) -> Int {
        min(max(raw, unit.range.lowerBound), unit.range.upperBound)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                TextField("Label", text: $draft.label)
                TextField("Message", text: $draft.message)
                Picker("Mood", selection: $draft.mood) {
                    ForEach(CharacterMood.allCases, id: \.self) { mood in
                        Text(name(for: mood)).tag(mood)
                    }
                }

                Section("Schedule") {
                    Picker("Fires", selection: $isOneTime) {
                        Text("Repeating").tag(false)
                        Text("Once").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if isOneTime {
                        DatePicker("At", selection: $fireAt, in: Date()...)
                        Text("It appears once at this time, then turns itself off.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !isOneTime {
                    Section("Interval") {
                        presets
                        LabeledContent("Every") {
                            HStack(spacing: 8) {
                                TextField("", value: $value, format: .number)
                                    .labelsHidden()
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 56)
                                    .multilineTextAlignment(.trailing)
                                Stepper("Interval", value: $value, in: unit.range, step: unit.step)
                                    .labelsHidden()
                                Picker("Unit", selection: $unit) {
                                    ForEach(IntervalUnit.allCases) { option in
                                        Text(option.short).tag(option)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .fixedSize()
                            }
                        }
                        if intervalSeconds < TimeInterval(cooldownSeconds) {
                            Text("Shorter than the \(IntervalUnit.shortLabel(seconds: cooldownSeconds)) gap between reminders. It appears about that often instead, and nothing is dropped.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Active hours") {
                        Toggle("Only during part of the day", isOn: $hasActiveHours)
                        DatePicker("From", selection: TimeOfDay.binding($activeStartMinutes), displayedComponents: .hourAndMinute)
                            .disabled(!hasActiveHours)
                        DatePicker("Until", selection: TimeOfDay.binding($activeEndMinutes), displayedComponents: .hourAndMinute)
                            .disabled(!hasActiveHours)
                        if hasActiveHours {
                            Text("Due outside these hours, it waits for the window to open.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Days") {
                        weekdayChips
                        if selectedWeekdays.count < 7, !selectedWeekdays.isEmpty {
                            Text("Due on another day, it waits for the next of these.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Snooze") {
                    Picker("Length", selection: $snoozeMinutes) {
                        Text("App setting").tag(Int?.none)
                        ForEach(snoozeChoices, id: \.self) { minutes in
                            Text("\(minutes) minutes").tag(Int?.some(minutes))
                        }
                    }
                }
            }
            .formStyle(.grouped)
            // Switching units can leave the value out of the new range; typing can
            // exceed it. Re-clamp on both so the shown value is always valid.
            .onChange(of: unit) { _, _ in value = clamped(value) }
            .onChange(of: value) { _, entered in
                let capped = clamped(entered)
                if capped != entered { value = capped }
            }

            HStack {
                if let onDelete {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    draft.interval = intervalSeconds
                    draft.snoozeInterval = snoozeMinutes.map { TimeInterval($0 * 60) }
                    draft.fireAt = isOneTime ? fireAt : nil
                    // All days or none both mean no restriction; an empty set
                    // would be a reminder that never fires.
                    draft.weekdays = !isOneTime && selectedWeekdays.count < 7 && !selectedWeekdays.isEmpty
                        ? selectedWeekdays
                        : nil
                    // Equal ends would be an empty window, a reminder that can
                    // never appear; treat it as no restriction instead. A
                    // one-time reminder has a moment, not hours.
                    draft.activeHours = !isOneTime && hasActiveHours && activeStartMinutes != activeEndMinutes
                        ? DailyWindow(startMinutes: activeStartMinutes, endMinutes: activeEndMinutes)
                        : nil
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
    }

    // Sunday first, matching Calendar weekday numbering; the symbols come from
    // the user's locale.
    private var weekdayChips: some View {
        HStack(spacing: 6) {
            let symbols = Calendar.current.veryShortWeekdaySymbols
            ForEach(1...7, id: \.self) { day in
                let isOn = selectedWeekdays.contains(day)
                Button(symbols[day - 1]) {
                    if isOn { selectedWeekdays.remove(day) } else { selectedWeekdays.insert(day) }
                }
                .buttonStyle(.bordered)
                .tint(isOn ? Color.accentColor : nil)
            }
        }
    }

    // Minute quick-picks. Each sets the value and the unit; the matching one reads
    // as selected while the interval equals it.
    private var presets: some View {
        HStack(spacing: 8) {
            ForEach(Self.minutePresets, id: \.self) { preset in
                let isSelected = unit == .minutes && clamped(value) == preset
                Button("\(preset)m") {
                    unit = .minutes
                    value = preset
                }
                .buttonStyle(.bordered)
                .tint(isSelected ? .accentColor : nil)
            }
        }
    }

    private func name(for mood: CharacterMood) -> String {
        switch mood {
        case .move: return "Move"
        case .water: return "Water"
        case .eyes: return "Eyes"
        case .posture: return "Posture"
        case .custom: return "Custom"
        }
    }
}

// Seconds, minutes, or hours for the interval editor. The model always stores
// seconds; the unit only shapes how a value is entered and shown. Internal:
// the quick add panel formats its preview with the same units.
enum IntervalUnit: CaseIterable, Identifiable {
    case seconds, minutes, hours

    var id: Self { self }

    var short: String {
        switch self {
        case .seconds: return "sec"
        case .minutes: return "min"
        case .hours: return "hr"
        }
    }

    var secondsPerUnit: TimeInterval {
        switch self {
        case .seconds: return 1
        case .minutes: return 60
        case .hours: return 3600
        }
    }

    var range: ClosedRange<Int> {
        switch self {
        case .seconds: return 5...3600
        case .minutes: return 1...600
        case .hours: return 1...24
        }
    }

    var step: Int {
        switch self {
        case .seconds: return 5
        case .minutes: return 5
        case .hours: return 1
        }
    }

    /// A compact "2 min" style label for a whole number of seconds.
    static func shortLabel(seconds: Int) -> String {
        let split = split(TimeInterval(seconds))
        return "\(split.value) \(split.unit.short)"
    }

    // Read a stored interval back as the largest unit that divides it evenly, so
    // 7200s shows as 2 hr and 90s stays 90 sec rather than a rounded minute.
    static func split(_ interval: TimeInterval) -> (value: Int, unit: IntervalUnit) {
        let total = max(1, Int(interval.rounded()))
        if total % 3600 == 0 { return (total / 3600, .hours) }
        if total % 60 == 0 { return (total / 60, .minutes) }
        return (total, .seconds)
    }
}

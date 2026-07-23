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
        let split = IntervalUnit.split(reminder.interval)
        return "Every \(split.value) \(split.unit.short)"
    }
}

private struct ReminderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Reminder
    @State private var value: Int
    @State private var unit: IntervalUnit
    @State private var snoozeMinutes: Int?
    private let onSave: (Reminder) -> Void
    private let onDelete: (() -> Void)?

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
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
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
// seconds; the unit only shapes how a value is entered and shown.
private enum IntervalUnit: CaseIterable, Identifiable {
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

    // Read a stored interval back as the largest unit that divides it evenly, so
    // 7200s shows as 2 hr and 90s stays 90 sec rather than a rounded minute.
    static func split(_ interval: TimeInterval) -> (value: Int, unit: IntervalUnit) {
        let total = max(1, Int(interval.rounded()))
        if total % 3600 == 0 { return (total / 3600, .hours) }
        if total % 60 == 0 { return (total / 60, .minutes) }
        return (total, .seconds)
    }
}

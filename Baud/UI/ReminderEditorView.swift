import SwiftUI

/// Lists reminders with an enable toggle each, and lets custom reminders be
/// added, edited, and deleted. Built-in and custom are the same type; only
/// delete and field editing are restricted to custom ones.
struct ReminderEditorView: View {
    let model: AppModel
    @State private var editing: Reminder?

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(model.reminders) { reminder in
                    ReminderRow(reminder: reminder, model: model) { editing = reminder }
                }
            }
            Divider()
            HStack {
                Button("Add reminder") { editing = model.addCustomReminder() }
                Spacer()
            }
            .padding(8)
        }
        .sheet(item: $editing) { reminder in
            ReminderDetailView(
                reminder: reminder,
                onSave: { model.update($0) },
                onDelete: reminder.isBuiltIn ? nil : { model.delete(reminder) }
            )
        }
    }
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
            if !reminder.isBuiltIn {
                Button("Edit", action: onEdit)
            }
        }
        .padding(.vertical, 2)
    }

    // An interval under a minute would round to "Every 0 min"; show seconds instead.
    private var intervalText: String {
        let seconds = Int(reminder.interval)
        if seconds < 60 { return "Every \(seconds) sec" }
        return "Every \(seconds / 60) min"
    }
}

private struct ReminderDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Reminder
    private let onSave: (Reminder) -> Void
    private let onDelete: (() -> Void)?

    init(reminder: Reminder, onSave: @escaping (Reminder) -> Void, onDelete: (() -> Void)?) {
        _draft = State(initialValue: reminder)
        self.onSave = onSave
        self.onDelete = onDelete
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
                Stepper("Every \(Int(draft.interval / 60)) min", value: minutes, in: 1...600)
            }
            .formStyle(.grouped)

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
                    onSave(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 380)
    }

    private var minutes: Binding<Double> {
        Binding(get: { draft.interval / 60 }, set: { draft.interval = $0 * 60 })
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

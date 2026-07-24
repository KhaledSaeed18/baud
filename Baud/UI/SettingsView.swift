import AppKit
import SwiftUI

/// The settings window: general options, the reminder editor, and an about pane.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            ReminderEditorView(model: model)
                .tabItem { Label("Reminders", systemImage: "bell") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 460, height: 420)
    }
}

private struct GeneralSettingsView: View {
    let model: AppModel
    @State private var launchAtLogin: Bool

    init(model: AppModel) {
        self.model = model
        _launchAtLogin = State(initialValue: model.launchesAtLogin)
    }

    @AppStorage(AppModel.snoozeMinutesKey) private var snoozeMinutes = AppModel.defaultSnoozeMinutes
    @AppStorage(AppModel.autoDismissSecondsKey) private var autoDismissSeconds = AppModel.defaultAutoDismissSeconds
    @AppStorage(AppModel.idleMinutesKey) private var idleMinutes = AppModel.defaultIdleMinutes
    @AppStorage(AppModel.cooldownSecondsKey) private var cooldownSeconds = AppModel.defaultCooldownSeconds

    private static let snoozeChoices = [5, 10, 15, 30]
    private static let autoDismissChoices = [5, 8, 15, 30]
    private static let idleChoices = [1, 2, 5, 10]
    private static let cooldownChoices = [30, 60, 120, 300]

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        model.setLaunchAtLogin(newValue)
                    }
            } footer: {
                Text("Baud starts with your Mac and waits in the menu bar. It has no Dock icon.")
            }

            Section {
                Picker("Snooze length", selection: $snoozeMinutes) {
                    ForEach(Self.snoozeChoices, id: \.self) { minutes in
                        Text("\(minutes) minutes").tag(minutes)
                    }
                }
            } footer: {
                Text("How long a snoozed reminder waits before it returns.")
            }

            Section {
                Picker("Leave on its own after", selection: $autoDismissSeconds) {
                    ForEach(Self.autoDismissChoices, id: \.self) { seconds in
                        Text("\(seconds) seconds").tag(seconds)
                    }
                }
            } footer: {
                Text("With no click, the character waits this long and then leaves. That counts as a normal outcome, not a miss.")
            }

            Section {
                Picker("Hold when away for", selection: $idleMinutes) {
                    ForEach(Self.idleChoices, id: \.self) { minutes in
                        if minutes == 1 {
                            Text("1 minute").tag(minutes)
                        } else {
                            Text("\(minutes) minutes").tag(minutes)
                        }
                    }
                }
            } footer: {
                Text("After this long with no input, reminders are held and delivered when you return.")
            }

            Section {
                Picker("Gap between reminders", selection: $cooldownSeconds) {
                    ForEach(Self.cooldownChoices, id: \.self) { seconds in
                        Text(cooldownLabel(seconds)).tag(seconds)
                    }
                }
            } footer: {
                Text("The least time between two appearances. Reminders due sooner wait their turn.")
            }

            Section {
                LabeledContent("Character") {
                    Button("Show a preview") { model.preview() }
                }
            } footer: {
                Text("The character slides in from the corner, delivers one line, and leaves.")
            }
        }
        .formStyle(.grouped)
    }

    private func cooldownLabel(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) seconds" }
        let minutes = seconds / 60
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}

/// Version and a link to the source. A pure read: no state, no model.
private struct AboutSettingsView: View {
    private var versionNumber: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            Text(verbatim: "Baud").font(.title2)
            if let versionNumber {
                Text("Version \(versionNumber)").foregroundStyle(.secondary)
            }
            if let url = URL(string: "https://github.com/KhaledSaeed18/baud") {
                Link("github.com/KhaledSaeed18/baud", destination: url)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

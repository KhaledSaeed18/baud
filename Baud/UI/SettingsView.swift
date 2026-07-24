import AppKit
import SwiftUI

/// The settings window: general options, timing, the reminder editor, and an
/// about pane.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            TimingSettingsView(model: model)
                .tabItem { Label("Timing", systemImage: "clock") }
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
    @AppStorage(AppModel.soundEnabledKey) private var soundEnabled = false
    @AppStorage(AppModel.quickAddHotKeyEnabledKey) private var quickAddHotKeyEnabled = true

    init(model: AppModel) {
        self.model = model
        _launchAtLogin = State(initialValue: model.launchesAtLogin)
    }

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
                Toggle("Quick add from anywhere", isOn: $quickAddHotKeyEnabled)
                    .onChange(of: quickAddHotKeyEnabled) { _, isOn in
                        model.setQuickAddHotKey(enabled: isOn)
                    }
            } footer: {
                Text(quickAddHotKeyEnabled
                    ? "Command Shift B opens a one-line field in any app: water every 45 minutes, call Tom at 3pm."
                    : "Quick add stays available from the menu bar.")
            }

            Section {
                Toggle("Play a sound on arrival", isOn: $soundEnabled)
                LabeledContent("Character") {
                    Button("Show a preview") { model.preview() }
                }
            } footer: {
                Text(soundEnabled
                    ? "One quiet cue when the character arrives. The character slides in, delivers one line, and leaves."
                    : "Baud is silent by default. The character slides in, delivers one line, and leaves.")
            }
        }
        .formStyle(.grouped)
    }
}

/// Every duration the app exposes, in one place: snooze, auto-dismiss, the idle
/// hold, and the gap between appearances. Reads and writes UserDefaults; the
/// scheduler and presenter pick changes up on their next check.
private struct TimingSettingsView: View {
    let model: AppModel
    @AppStorage(AppModel.snoozeMinutesKey) private var snoozeMinutes = AppModel.defaultSnoozeMinutes
    @AppStorage(AppModel.autoDismissSecondsKey) private var autoDismissSeconds = AppModel.defaultAutoDismissSeconds
    @AppStorage(AppModel.idleMinutesKey) private var idleMinutes = AppModel.defaultIdleMinutes
    @AppStorage(AppModel.idleHoldEnabledKey) private var idleHoldEnabled = true
    @AppStorage(AppModel.awayResetEnabledKey) private var awayResetEnabled = true
    @AppStorage(AppModel.fullScreenHoldEnabledKey) private var fullScreenHoldEnabled = true
    @AppStorage(AppModel.captureHoldEnabledKey) private var captureHoldEnabled = true
    @AppStorage(AppModel.cooldownSecondsKey) private var cooldownSeconds = AppModel.defaultCooldownSeconds
    @AppStorage(AppModel.quietHoursEnabledKey) private var quietHoursEnabled = false
    @AppStorage(AppModel.calendarHoldEnabledKey) private var calendarHoldEnabled = false
    @AppStorage(AppModel.quietStartMinutesKey) private var quietStartMinutes = AppModel.defaultQuietStartMinutes
    @AppStorage(AppModel.quietEndMinutesKey) private var quietEndMinutes = AppModel.defaultQuietEndMinutes

    private static let snoozeChoices = [5, 10, 15, 30]
    private static let autoDismissChoices = [5, 8, 15, 30]
    private static let idleChoices = [1, 2, 5, 10]
    private static let cooldownChoices = [30, 60, 120, 300]

    var body: some View {
        Form {
            Section {
                Picker("Snooze length", selection: $snoozeMinutes) {
                    ForEach(Self.snoozeChoices, id: \.self) { minutes in
                        Text(minutesLabel(minutes)).tag(minutes)
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
                Toggle("Hold reminders when away", isOn: $idleHoldEnabled)
                Picker("Hold when away for", selection: $idleMinutes) {
                    ForEach(Self.idleChoices, id: \.self) { minutes in
                        Text(minutesLabel(minutes)).tag(minutes)
                    }
                }
                .disabled(!idleHoldEnabled)
                Toggle("Start fresh after a break", isOn: $awayResetEnabled)
            } footer: {
                Text(awayResetFooter)
            }

            Section {
                Toggle("Hold during full screen", isOn: $fullScreenHoldEnabled)
            } footer: {
                Text(fullScreenHoldEnabled
                    ? "A full-screen app, video, or presentation holds reminders until you leave it."
                    : "Reminders appear over full-screen apps. Calls and the locked screen still hold them.")
            }

            Section {
                Toggle("Hold during calls", isOn: $captureHoldEnabled)
            } footer: {
                Text(captureHoldEnabled
                    ? "An active camera or microphone holds reminders; a call is likely in progress."
                    : "Reminders appear even while the camera or microphone is in use. They can interrupt a call or a recording.")
            }

            Section {
                Picker("Gap between reminders", selection: $cooldownSeconds) {
                    ForEach(Self.cooldownChoices, id: \.self) { seconds in
                        Text(secondsLabel(seconds)).tag(seconds)
                    }
                }
            } footer: {
                Text("The least time between two appearances. Reminders due sooner wait their turn.")
            }

            Section {
                Toggle("Hold during calendar events", isOn: $calendarHoldEnabled)
                    .onChange(of: calendarHoldEnabled) { _, isOn in
                        guard isOn else { return }
                        // The hold is useless without read access, so a denial
                        // turns the toggle back off rather than pretending.
                        Task {
                            if await !model.requestCalendarAccess() {
                                calendarHoldEnabled = false
                            }
                        }
                    }
            } footer: {
                Text(calendarHoldEnabled
                    ? "While an event is on, reminders are held and delivered after. The calendar is read on this Mac only."
                    : "Baud can stay quiet while a calendar event is on. Turning this on asks for read access to your calendar.")
            }

            Section {
                Toggle("Quiet hours", isOn: $quietHoursEnabled)
                DatePicker("From", selection: TimeOfDay.binding($quietStartMinutes), displayedComponents: .hourAndMinute)
                    .disabled(!quietHoursEnabled)
                DatePicker("Until", selection: TimeOfDay.binding($quietEndMinutes), displayedComponents: .hourAndMinute)
                    .disabled(!quietHoursEnabled)
            } footer: {
                Text(quietHoursEnabled
                    ? "Reminders due in this window are skipped, like a pause, so the morning does not start with a backlog."
                    : "A daily window with no reminders, for evenings and nights.")
            }
        }
        .formStyle(.grouped)
    }


    private var awayResetFooter: String {
        var lines: [String] = []
        lines.append(idleHoldEnabled
            ? "After this long with no input, reminders are held and delivered when you return."
            : "Reminders appear on schedule even when you are away from the Mac.")
        if awayResetEnabled {
            lines.append("A break longer than that restarts every interval from your return, so nothing fires the moment you sit down.")
        }
        return lines.joined(separator: " ")
    }

    private func minutesLabel(_ minutes: Int) -> String {
        minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private func secondsLabel(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds) seconds" : minutesLabel(seconds / 60)
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

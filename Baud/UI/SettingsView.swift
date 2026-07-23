import SwiftUI

/// The settings window: general options and the reminder editor.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            GeneralSettingsView(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            ReminderEditorView(model: model)
                .tabItem { Label("Reminders", systemImage: "bell") }
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

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    model.setLaunchAtLogin(newValue)
                }
        }
        .formStyle(.grouped)
        .padding()
    }
}

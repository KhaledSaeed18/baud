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
        }
        .formStyle(.grouped)
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

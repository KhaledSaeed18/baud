import SwiftUI

@main
struct BaudApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Baud", image: "MenuBarIcon") {
            MenuBarView(model: appDelegate.model)
        }
        Settings {
            SettingsView(model: appDelegate.model)
        }
    }
}

import SwiftUI
import AppKit

@main
struct BaudApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Baud", systemImage: "circle.dashed") {
            Button("Show a reminder now") {
                appDelegate.showNextForTesting()
            }
            Button("Acknowledge") {
                appDelegate.acknowledge()
            }
            Button("Snooze") {
                appDelegate.snooze()
            }
            Button("Dismiss") {
                appDelegate.dismiss()
            }
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
    }
}

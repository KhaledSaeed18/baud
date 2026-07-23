import SwiftUI
import AppKit

@main
struct BaudApp: App {
    @State private var presenter = Presenter()

    var body: some Scene {
        MenuBarExtra("Baud", systemImage: "circle.dashed") {
            Button("Show reminder") {
                presenter.show()
            }
            Button("Acknowledge") {
                presenter.acknowledge()
            }
            Button("Snooze") {
                presenter.snooze()
            }
            Button("Dismiss") {
                presenter.dismiss()
            }
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
    }
}

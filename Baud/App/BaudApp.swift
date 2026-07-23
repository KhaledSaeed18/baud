import SwiftUI
import AppKit

@main
struct BaudApp: App {
    @State private var presenter = Presenter()

    var body: some Scene {
        MenuBarExtra("Baud", systemImage: "circle.dashed") {
            Button("Show test reminder") {
                presenter.showPlaceholder()
            }
            Button("Hide") {
                presenter.hide()
            }
            Divider()
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
    }
}

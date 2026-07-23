import SwiftUI
import AppKit

/// Wraps the character with dismiss and snooze controls that appear while it is
/// present. The character rendering stays in CharacterView; the interaction
/// lives here, in the presenter layer.
struct InteractiveCharacterView: View {
    let model: CharacterModel
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CharacterView(model: model)
            if isPresent {
                actions
                    .padding(12)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.state)
    }

    private var isPresent: Bool {
        model.state == .speaking || model.state == .idle
    }

    private var actions: some View {
        HStack(spacing: 8) {
            ActionButton(symbol: "checkmark", help: "Dismiss", action: onDismiss)
            ActionButton(symbol: "clock", help: "Snooze 10 minutes", action: onSnooze)
        }
    }
}

private struct ActionButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(Circle().strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(help)
    }
}

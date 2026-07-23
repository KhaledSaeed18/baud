import SwiftUI
import AppKit

/// The code-drawn character: geometric primitives whose personality comes from
/// motion, not detail. It reads CharacterModel and renders; it never sets state.
struct CharacterView: View {
    let model: CharacterModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var breathing = false
    @State private var isBlinking = false
    @State private var lift: CGFloat = 0
    @State private var tiltDegrees: Double = 0
    @State private var stretch: CGFloat = 1

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Spacer(minLength: 0)
            speechBubble
            figure
        }
        .frame(width: 210, height: 220, alignment: .bottomTrailing)
        .onChange(of: model.state) { _, newState in react(to: newState) }
        .onAppear { startBreathing() }
        .task(id: model.state) { await runIdleBlink() }
    }

    private var figure: some View {
        VStack(spacing: -1) {
            antenna
            bodyWithEyes
        }
        .frame(width: 120, height: 132, alignment: .bottom)
        .offset(y: (breathing ? -Motion.breatheAmplitude : 0) + lift)
        .rotationEffect(.degrees(tiltDegrees), anchor: .bottom)
        .scaleEffect(x: 1, y: stretch, anchor: .bottom)
    }

    private var antenna: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(accent)
                .frame(width: 10, height: 10)
            Capsule()
                .fill(bodyColor)
                .frame(width: 4, height: 12)
        }
    }

    private var bodyWithEyes: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(bodyColor)
                .frame(width: 108, height: 108)
            HStack(spacing: 24) {
                eye
                eye
            }
            .offset(y: -6)
        }
    }

    private var eye: some View {
        Capsule()
            .fill(eyeColor)
            .frame(width: 15, height: 15)
            .scaleEffect(x: 1, y: isBlinking ? 0.12 : 1, anchor: .center)
    }

    private var speechBubble: some View {
        Text(model.message)
            .font(.callout)
            .multilineTextAlignment(.trailing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 180, alignment: .trailing)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(bubbleFill))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(bubbleStroke, lineWidth: 1))
            .opacity(model.state == .speaking ? 1 : 0)
            .scaleEffect(model.state == .speaking ? 1 : 0.97, anchor: .bottomTrailing)
            .animation(reduceMotion ? Motion.reducedChange : Motion.speakGesture, value: model.state)
    }
}

private extension CharacterView {
    var bodyColor: Color {
        colorScheme == .dark ? Color(white: 0.82) : Color(white: 0.28)
    }

    var eyeColor: Color {
        colorScheme == .dark ? Color(white: 0.16) : Color(white: 0.96)
    }

    var bubbleFill: Color { Color(nsColor: .textBackgroundColor) }
    var bubbleStroke: Color { Color(nsColor: .separatorColor) }

    var accent: Color {
        switch model.mood {
        case .move: return .green
        case .water: return .blue
        case .eyes: return .teal
        case .posture: return .orange
        case .custom: return .purple
        }
    }
}

private extension CharacterView {
    func react(to state: CharacterState) {
        switch state {
        case .speaking: playSpeakGesture()
        case .acknowledged: pulse { lift = -8 }
        case .snoozed: pulse { tiltDegrees = 7 }
        default: break
        }
    }

    /// One small gesture tied to mood. The skeleton is shared; only the accent
    /// motion differs, so a new mood is one case here.
    func playSpeakGesture() {
        switch model.mood {
        case .move: pulse { lift = -10 }
        case .water: pulse { tiltDegrees = 8 }
        case .eyes: longBlink()
        case .posture: pulse { stretch = 1.06 }
        case .custom: pulse { lift = -6 }
        }
    }

    /// Move to a transient pose, then settle back. Skipped under Reduce Motion.
    func pulse(_ apply: () -> Void) {
        guard !reduceMotion else { return }
        withAnimation(Motion.reactBeat, apply)
        Task {
            try? await Task.sleep(for: .seconds(0.26))
            withAnimation(Motion.reactBeat) {
                lift = 0
                tiltDegrees = 0
                stretch = 1
            }
        }
    }

    func longBlink() {
        Task {
            withAnimation(Motion.blink) { isBlinking = true }
            try? await Task.sleep(for: .seconds(0.45))
            withAnimation(Motion.blink) { isBlinking = false }
        }
    }

    func startBreathing() {
        guard !reduceMotion else { return }
        withAnimation(Motion.breathe) { breathing = true }
    }

    /// A slow blink every few seconds while idle. The task is cancelled the
    /// moment the state leaves idle, so nothing blinks off-screen.
    func runIdleBlink() async {
        guard model.state == .idle else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Motion.idleBlinkPeriod))
            guard !Task.isCancelled, model.state == .idle else { break }
            withAnimation(Motion.blink) { isBlinking = true }
            try? await Task.sleep(for: .seconds(Motion.blinkDuration))
            withAnimation(Motion.blink) { isBlinking = false }
        }
    }
}

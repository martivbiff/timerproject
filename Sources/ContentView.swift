import SwiftUI

struct ContentView: View {
    @StateObject private var model: TimerModel
    private let presets: [Int] = [1, 5, 10, 25]

    init(model: TimerModel = TimerModel()) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        // 30fps is plenty for drifting water, and half the work of the display refresh.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let phase = timeline.date.timeIntervalSinceReferenceDate

            ZStack {
                Sky()
                Waves(
                    phase: phase,
                    energy: model.pulse,
                    lift: model.progress
                )
                .frame(maxHeight: .infinity, alignment: .bottom)

                // A whole-window bloom when a milestone lands.
                Color.white
                    .opacity(model.pulse * 0.06)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Spacer(minLength: 34)
                    ring
                    Spacer(minLength: 20)
                    controls
                    Spacer(minLength: 26)
                }
                .padding(.horizontal, 40)
            }
            .ignoresSafeArea()
        }
        .background(hotkeys)
    }

    // MARK: - Ring

    private var ring: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height, 248)
            ProgressRing(
                progress: model.progress,
                setFraction: model.duration / 3600,
                phase: model.phase,
                pulse: model.pulse
            )
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard model.phase == .idle || model.phase == .done else { return }
                        let center = CGPoint(x: side / 2, y: side / 2)
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y
                        // Screen y grows downward; negate so 12 o'clock is zero.
                        var degrees = atan2(dx, -dy) * 180 / .pi
                        if degrees < 0 { degrees += 360 }
                        // One full turn spans the hour.
                        let minutes = max(1, (degrees / 360 * 60).rounded())
                        if minutes * 60 != model.duration {
                            model.setDuration(minutes * 60)
                        }
                    }
            )
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 18) {
            if model.phase == .idle {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { minutes in
                        PresetPill(
                            minutes: minutes,
                            selected: Int(model.duration / 60) == minutes
                        ) {
                            model.setDuration(Double(minutes) * 60)
                        }
                    }
                }
                .transition(.opacity)
            }

            PrimaryButton(phase: model.phase) {
                if model.phase == .done {
                    model.reset()
                } else {
                    model.toggle()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.phase == .idle)
    }

    // MARK: - Keyboard

    private var hotkeys: some View {
        ZStack {
            Button("") { model.toggle() }
                .keyboardShortcut(.space, modifiers: [])
            Button("") { model.reset() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }
}

private struct PresetPill: View {
    let minutes: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(minutes)")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(selected ? Color.white : Palette.ink.opacity(0.65))
                .frame(width: 34, height: 26)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(selected ? 0.16 : 0.06))
                )
                .overlay(
                    Capsule()
                        .stroke(Palette.accent.opacity(selected ? 0.55 : 0), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryButton: View {
    let phase: Phase
    let action: () -> Void

    private var symbol: String {
        switch phase {
        case .running: return "pause.fill"
        case .done: return "checkmark"
        case .idle, .paused: return "play.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .frame(width: 132, height: 40)
                .background(
                    Capsule().fill(Color.white.opacity(0.10))
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

enum Palette {
    static let skyTop    = Color(red: 0.043, green: 0.086, blue: 0.153)
    static let skyMid    = Color(red: 0.075, green: 0.145, blue: 0.239)
    static let skyLow    = Color(red: 0.114, green: 0.204, blue: 0.318)
    static let accent    = Color(red: 0.408, green: 0.812, blue: 1.0)
    static let accentSoft = Color(red: 0.596, green: 0.878, blue: 1.0)
    static let ink       = Color(red: 0.784, green: 0.867, blue: 0.949)
}

/// The night sky the whole app sits on: a vertical wash plus one soft moon.
struct Sky: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.skyTop, Palette.skyMid, Palette.skyLow],
                startPoint: .top,
                endPoint: .bottom
            )
            GeometryReader { geo in
                RadialGradient(
                    colors: [Color.white.opacity(0.16), Color.white.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.42
                )
                .frame(width: geo.size.width * 0.9, height: geo.size.width * 0.9)
                .position(x: geo.size.width * 0.78, y: geo.size.height * 0.12)
            }
        }
    }
}

/// Layered sine ridges. `energy` swells the crests when a milestone lands, and
/// `lift` raises the whole waterline as the session fills up.
struct Waves: View {
    var phase: Double
    var energy: Double
    var lift: Double

    private struct Layer {
        let baseline: Double      // fraction of height
        let amplitude: Double     // points
        let wavelength: Double    // points
        let speed: Double
        let opacity: Double
    }

    private let layers: [Layer] = [
        Layer(baseline: 0.70, amplitude: 13, wavelength: 195, speed: 0.35, opacity: 0.20),
        Layer(baseline: 0.80, amplitude: 17, wavelength: 138, speed: 0.55, opacity: 0.26),
        Layer(baseline: 0.89, amplitude: 11, wavelength: 102, speed: 0.80, opacity: 0.32),
    ]

    var body: some View {
        Canvas { context, size in
            for (index, layer) in layers.enumerated() {
                let swell = 1 + energy * 0.55
                let amp = layer.amplitude * swell
                let baseY = size.height * (layer.baseline - lift * 0.06)

                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))

                var x = 0.0
                while x <= size.width {
                    let a = sin(x / layer.wavelength + phase * layer.speed)
                    let b = sin(x / (layer.wavelength * 0.47) + phase * layer.speed * 1.7 + 1.2)
                    let y = baseY + a * amp + b * amp * 0.35
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 3
                }

                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()

                let tint = Color(
                    red: 0.20 + Double(index) * 0.04,
                    green: 0.42 + Double(index) * 0.06,
                    blue: 0.62 + Double(index) * 0.08
                )

                context.fill(
                    path,
                    with: .linearGradient(
                        Gradient(colors: [
                            tint.opacity(layer.opacity + energy * 0.10),
                            tint.opacity(layer.opacity * 0.25),
                        ]),
                        startPoint: CGPoint(x: 0, y: size.height * 0.5),
                        endPoint: CGPoint(x: 0, y: size.height)
                    )
                )

                // A hairline crest catches the light on the front-most ridge.
                if index == layers.count - 1 {
                    context.stroke(
                        path,
                        with: .color(Palette.accentSoft.opacity(0.10 + energy * 0.35)),
                        lineWidth: 1
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// The whole readout: a faint track, the arc that fills it, and a head that
/// rides the leading edge. No digits anywhere — position is the only readout.
struct ProgressRing: View {
    var progress: Double
    var setFraction: Double
    var phase: Phase
    var pulse: Double

    private var glow: Double {
        switch phase {
        case .done: return 0.55 + pulse * 0.45
        default: return 0.18 + pulse * 0.7
        }
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let lineWidth = max(3.0, side * 0.018)
            let radius = (side - lineWidth) / 2
            let angle = Angle(degrees: -90 + 360 * (phase == .done ? 1 : progress))

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.09), lineWidth: lineWidth * 0.7)

                // Idle: a dim arc previews how long the session will be.
                if phase == .idle {
                    Circle()
                        .trim(from: 0, to: max(0.004, setFraction))
                        .stroke(
                            Palette.accent.opacity(0.35),
                            style: StrokeStyle(lineWidth: lineWidth * 0.7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }

                Circle()
                    .trim(from: 0, to: phase == .done ? 1 : max(0.0001, progress))
                    .stroke(
                        AngularGradient(
                            colors: [
                                Palette.accent,
                                Palette.accentSoft,
                                Color.white,
                                Palette.accentSoft,
                                Palette.accent,
                            ],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Palette.accent.opacity(glow), radius: side * 0.045)
                    .shadow(color: Palette.accent.opacity(glow * 0.6), radius: side * 0.12)
                    .opacity(phase == .idle ? 0 : 1)

                if phase != .idle && phase != .done {
                    Circle()
                        .fill(Color.white)
                        .frame(width: lineWidth * 2.1, height: lineWidth * 2.1)
                        .shadow(color: Palette.accentSoft.opacity(0.7 + pulse * 0.3),
                                radius: side * 0.05)
                        .offset(
                            x: radius * cos(angle.radians),
                            y: radius * sin(angle.radians)
                        )
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

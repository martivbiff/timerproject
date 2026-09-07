import SwiftUI
import AVFoundation

enum Phase {
    case idle, running, paused, done
}

/// Drives the countdown. Time is derived from a wall-clock deadline rather than
/// accumulated ticks, so the ring stays honest if the machine sleeps or stutters.
final class TimerModel: ObservableObject {

    @Published fileprivate(set) var phase: Phase = .idle
    @Published var duration: TimeInterval = 5 * 60
    @Published fileprivate(set) var remaining: TimeInterval = 5 * 60

    /// 0…1 pulse used by the ring and the waves when a milestone lands.
    @Published fileprivate(set) var pulse: Double = 0

    private var deadline: Date?
    private var ticker: Timer?
    private var pulseStart: Date?
    private var glowFired = false
    private let chime = Chime()

    /// Fraction of the session that has elapsed.
    var progress: Double {
        guard duration > 0 else { return 0 }
        switch phase {
        case .done: return 1
        case .idle: return 0
        default: return min(1, max(0, 1 - remaining / duration))
        }
    }

    /// Where the "you're nearly there" glow happens: five minutes out, or the
    /// last fifth of the session when it is shorter than five minutes.
    var glowThreshold: TimeInterval {
        duration > 300 ? 300 : duration * 0.2
    }

    // MARK: - Controls

    func setDuration(_ seconds: TimeInterval) {
        let clamped = min(60 * 60, max(60, seconds.rounded()))
        duration = clamped
        remaining = clamped
        phase = .idle
        glowFired = false
        pulse = 0
        pulseStart = nil
        stopTicker()
    }

    func start() {
        if phase == .done { setDuration(duration) }
        deadline = Date().addingTimeInterval(remaining)
        phase = .running
        startTicker()
    }

    func pause() {
        guard phase == .running else { return }
        remaining = max(0, deadline?.timeIntervalSinceNow ?? remaining)
        phase = .paused
        stopTicker()
    }

    func toggle() {
        switch phase {
        case .running: pause()
        case .idle, .paused, .done: start()
        }
    }

    func reset() {
        setDuration(duration)
    }

    // MARK: - Ticking

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common keeps the ring moving while the window is being dragged.
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        if let start = pulseStart {
            let elapsed = Date().timeIntervalSince(start)
            let p = max(0, 1 - elapsed / 2.6)
            pulse = p * p
            if p <= 0 { pulseStart = nil }
        }

        guard phase == .running, let deadline else { return }
        let left = deadline.timeIntervalSinceNow

        if !glowFired, left <= glowThreshold, left > 0 {
            glowFired = true
            pulseStart = Date()
        }

        if left <= 0 {
            remaining = 0
            phase = .done
            pulseStart = Date()
            stopTicker()
            // Keep ticking briefly so the completion pulse can decay.
            startDecayOnly()
            chime.play()
        } else {
            remaining = left
        }
    }

    private func startDecayOnly() {
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.pulseStart else { self?.stopTicker(); return }
            let p = max(0, 1 - Date().timeIntervalSince(start) / 2.6)
            self.pulse = p * p
            if p <= 0 { self.pulseStart = nil; self.stopTicker() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }
}

/// A soft two-partial bell, synthesised once and replayed. Gentler than any of
/// the stock system alerts, and it needs no bundled audio file.
final class Chime {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?
    private var prepared = false

    private func prepare() {
        guard !prepared else { return }
        prepared = true

        let sampleRate = 44_100.0
        let seconds = 2.6
        let release = 0.3
        let frames = AVAudioFrameCount(sampleRate * seconds)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2),
              let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channels = buf.floatChannelData else { return }
        buf.frameLength = frames

        // Fundamental plus a quiet fifth and octave; each partial decays at its
        // own rate so the tail settles into a pure tone the way a bell does.
        let partials: [(freq: Double, gain: Double, decay: Double)] = [
            (587.33, 0.55, 1.15),
            (880.00, 0.22, 0.80),
            (1174.66, 0.10, 0.55),
        ]

        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let attack = min(1, t / 0.012)
            // Taper the last moments to true silence; without it the buffer
            // ends while the tone is still ringing and you hear the cut.
            let fade = min(1, max(0, (seconds - t) / release))
            var sample = 0.0
            for p in partials {
                sample += p.gain * sin(2 * .pi * p.freq * t) * exp(-t / p.decay)
            }
            let value = Float(sample * attack * fade * 0.32)
            channels[0][i] = value
            channels[1][i] = value
        }

        buffer = buf
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func play() {
        prepare()
        guard let buffer else { return }
        do {
            if !engine.isRunning { try engine.start() }
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
        } catch {
            NSSound(named: "Glass")?.play()
        }
    }
}

extension TimerModel {
    /// Poses the model in a fixed state for previews and snapshot checks.
    static func posed(phase: Phase, elapsed: Double, pulse: Double = 0,
                      minutes: Double = 25) -> TimerModel {
        let m = TimerModel()
        m.duration = minutes * 60
        m.remaining = m.duration * (1 - elapsed)
        m.phase = phase
        m.pulse = pulse
        return m
    }
}

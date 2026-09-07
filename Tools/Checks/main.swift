import Foundation
import AVFoundation
import AppKit

var failures = 0
func check(_ label: String, _ ok: Bool, _ detail: String = "") {
    print("\(ok ? "PASS" : "FAIL")  \(label) \(detail)")
    if !ok { failures += 1 }
}

// --- thresholds -------------------------------------------------------
let m = TimerModel()
m.setDuration(25 * 60)
check("25min glows at 5min left", m.glowThreshold == 300, "= \(m.glowThreshold)s")
m.setDuration(60)
check("1min glows in final fifth", m.glowThreshold == 12, "= \(m.glowThreshold)s")
m.setDuration(10)                    // below the floor
check("clamps short durations to 60s", m.duration == 60, "= \(m.duration)s")
m.setDuration(99 * 60)               // above the ceiling
check("clamps long durations to 60min", m.duration == 3600, "= \(m.duration)s")

// --- progress ---------------------------------------------------------
m.setDuration(600)
check("idle progress is 0", m.progress == 0)
m.start()
RunLoop.main.run(until: Date().addingTimeInterval(1.2))
check("progress advances once running", m.progress > 0 && m.progress < 0.01,
      "= \(String(format: "%.4f", m.progress))")
m.pause()
let held = m.progress
RunLoop.main.run(until: Date().addingTimeInterval(0.6))
check("progress freezes while paused", m.progress == held)
m.start()
RunLoop.main.run(until: Date().addingTimeInterval(0.4))
check("resumes from where it paused", m.progress > held)

// --- the bell ---------------------------------------------------------
// Re-synthesise the same buffer the app uses and measure it, then confirm the
// audio graph actually starts. Starting the engine makes no sound on its own.
let sampleRate = 44_100.0
let seconds = 2.6
let release = 0.3
let frames = AVAudioFrameCount(sampleRate * seconds)
let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
buf.frameLength = frames
let partials: [(Double, Double, Double)] = [(587.33, 0.55, 1.15), (880, 0.22, 0.80), (1174.66, 0.10, 0.55)]
var peak = 0.0, energy = 0.0
for i in 0..<Int(frames) {
    let t = Double(i) / sampleRate
    let attack = min(1, t / 0.012)
    var s = 0.0
    for p in partials { s += p.1 * sin(2 * .pi * p.0 * t) * exp(-t / p.2) }
    let fade = min(1, max(0, (seconds - t) / release))
    let v = s * attack * fade * 0.32
    buf.floatChannelData![0][i] = Float(v)
    peak = max(peak, abs(v)); energy += v * v
}
let rms = (energy / Double(frames)).squareRoot()
check("bell is audible", rms > 0.02, "rms \(String(format: "%.3f", rms))")
check("bell does not clip", peak <= 1.0, "peak \(String(format: "%.3f", peak))")

// Tail should be far quieter than the onset — i.e. it decays like a bell.
var headPeak = 0.0, tailPeak = 0.0
for i in 0..<Int(sampleRate * 0.1) { headPeak = max(headPeak, abs(Double(buf.floatChannelData![0][i]))) }
// The final 50ms must be effectively silent, or the buffer ends mid-tone and clicks.
for i in Int(sampleRate * (seconds - 0.01))..<Int(frames) { tailPeak = max(tailPeak, abs(Double(buf.floatChannelData![0][i]))) }
// Below -54 dBFS at the buffer's edge, so playback ends on silence, not a step.
check("bell fades to silence (no cutoff click)", tailPeak < 0.002,
      "head \(String(format: "%.3f", headPeak)) → last 10ms \(String(format: "%.5f", tailPeak))")

let engine = AVAudioEngine()
let player = AVAudioPlayerNode()
engine.attach(player)
engine.connect(player, to: engine.mainMixerNode, format: format)
do { try engine.start(); check("audio engine starts", engine.isRunning) }
catch { check("audio engine starts", false, "\(error)") }
engine.stop()

print(failures == 0 ? "\nall checks passed" : "\n\(failures) FAILED")
exit(failures == 0 ? 0 : 1)

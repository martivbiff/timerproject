// Dev-only: renders ContentView in each state to PNGs so the visuals can be
// eyeballed without launching the app. Not part of the shipped bundle.
import SwiftUI
import AppKit

@main
struct Snapshot {
    static func main() {
        let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
        let states: [(String, TimerModel)] = [
            ("1-idle",    .posed(phase: .idle,    elapsed: 0)),
            ("2-running", .posed(phase: .running, elapsed: 0.42)),
            ("3-glow",    .posed(phase: .running, elapsed: 0.80, pulse: 0.95)),
            ("4-done",    .posed(phase: .done,    elapsed: 1.0,  pulse: 0.7)),
        ]
        for (name, model) in states {
            let view = ContentView(model: model).frame(width: 380, height: 520)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) else {
                print("failed: \(name)"); continue
            }
            try? png.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
            print("wrote \(name).png")
        }
    }
}

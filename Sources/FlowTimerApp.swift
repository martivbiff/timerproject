import SwiftUI
import AppKit

@main
struct FlowTimerApp: App {
    var body: some Scene {
        WindowGroup("Flow Timer") {
            ContentView()
                .frame(width: 380, height: 520)
                .background(WindowConfigurator())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

/// Makes the window itself dark and chrome-free so the sky runs edge to edge.
private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titlebarAppearsTransparent = true
            window.backgroundColor = NSColor(red: 0.043, green: 0.086, blue: 0.153, alpha: 1)
            window.isMovableByWindowBackground = true
            window.appearance = NSAppearance(named: .darkAqua)
            NSApp.activate(ignoringOtherApps: true)
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

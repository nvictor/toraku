import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            window.minSize = NSSize(width: 360, height: 560)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
    }
}

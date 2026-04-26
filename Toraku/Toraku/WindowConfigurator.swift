import SwiftUI

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            let size = NSSize(width: 1280, height: 720)
            window.minSize = NSSize(width: 1024, height: 576)
            window.contentAspectRatio = NSSize(width: 16, height: 9)

            if window.frame.width < size.width || window.frame.height < size.height {
                window.setContentSize(size)
                window.center()
            }
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.contentAspectRatio = NSSize(width: 16, height: 9)
        }
    }
}

import SwiftUI

struct ControlsView: View {
    @ObservedObject var model: TrackTimerViewModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.playPause()
            } label: {
                Label(playPauseTitle, systemImage: playPauseImage)
            }
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(.borderedProminent)

            Button {
                model.skip()
            } label: {
                Label("Skip", systemImage: "forward.end")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])

            Button(role: .destructive) {
                model.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .keyboardShortcut("r", modifiers: [])
        }
        .controlSize(.large)
        .labelStyle(.titleAndIcon)
    }

    private var playPauseTitle: String {
        model.playbackState == .playing ? "Pause" : "Play"
    }

    private var playPauseImage: String {
        model.playbackState == .playing ? "pause.fill" : "play.fill"
    }
}

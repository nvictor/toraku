import SwiftUI

struct ControlsView: View {
    @ObservedObject var model: TrackTimerViewModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.playPause()
            } label: {
                Label(playPauseTitle, systemImage: playPauseImage)
            }
            .keyboardShortcut(.space, modifiers: [])
            .buttonStyle(.borderedProminent)
            .labelStyle(.titleAndIcon)
            .frame(minWidth: 92)

            Button {
                model.skipBack()
            } label: {
                Label("Back", systemImage: "backward.end")
            }
            .keyboardShortcut(.leftArrow, modifiers: [])
            .labelStyle(.iconOnly)
            .help("Back")

            Button {
                model.skip()
            } label: {
                Label("Skip", systemImage: "forward.end")
            }
            .keyboardShortcut(.rightArrow, modifiers: [])
            .labelStyle(.iconOnly)
            .help("Skip")

            Button(role: .destructive) {
                model.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .keyboardShortcut("r", modifiers: [])
            .labelStyle(.iconOnly)
            .help("Reset")
        }
        .controlSize(.large)
    }

    private var playPauseTitle: String {
        model.playbackState == .playing ? "Pause" : "Play"
    }

    private var playPauseImage: String {
        model.playbackState == .playing ? "pause.fill" : "play.fill"
    }
}

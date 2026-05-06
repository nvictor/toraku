import SwiftUI

struct ControlsView: View {
    @ObservedObject var model: TrackTimerViewModel

    var body: some View {
        Button {
            model.playPause()
        } label: {
            Label(playPauseTitle, systemImage: playPauseImage)
        }
        .keyboardShortcut(.space, modifiers: [])
        .buttonStyle(.borderedProminent)
        .labelStyle(.titleAndIcon)
        .controlSize(.large)
        .frame(minWidth: 92)
    }

    private var playPauseTitle: String {
        model.playbackState == .playing ? "Pause" : "Play"
    }

    private var playPauseImage: String {
        model.playbackState == .playing ? "pause.fill" : "play.fill"
    }
}

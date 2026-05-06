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
            .labelStyle(.titleAndIcon)
            .controlSize(.large)
            .frame(minWidth: 92)

            Button {
                model.toggleMusicMuted()
            } label: {
                Label(muteTitle, systemImage: muteImage)
            }
            .buttonStyle(.bordered)
            .labelStyle(.iconOnly)
            .controlSize(.large)
            .disabled(!model.isMusicControlAvailable)
            .help(muteTitle)
        }
    }

    private var playPauseTitle: String {
        model.playbackState == .playing ? "Pause" : "Play"
    }

    private var playPauseImage: String {
        model.playbackState == .playing ? "pause.fill" : "play.fill"
    }

    private var muteTitle: String {
        model.isMusicMuted ? "Unmute Music" : "Mute Music"
    }

    private var muteImage: String {
        model.isMusicMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
    }
}

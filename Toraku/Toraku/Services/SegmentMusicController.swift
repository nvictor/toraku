import AVFoundation
import Foundation

nonisolated protocol SegmentMusicControlling: AnyObject {
    func play(
        url: URL,
        fadeInDuration: TimeInterval,
        fadeOutDuration: TimeInterval,
        maximumPlaybackDuration: TimeInterval
    ) throws
    func stop(fadeOutDuration: TimeInterval)
}

nonisolated final class SegmentMusicController: SegmentMusicControlling, @unchecked Sendable {
    private var player: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var stopTimer: Timer?

    func play(
        url: URL,
        fadeInDuration: TimeInterval,
        fadeOutDuration: TimeInterval,
        maximumPlaybackDuration: TimeInterval
    ) throws {
        stop(fadeOutDuration: 0)

        guard maximumPlaybackDuration > 0 else {
            return
        }

        let player = try AVAudioPlayer(contentsOf: url)
        player.volume = 0
        player.prepareToPlay()
        player.play()
        self.player = player

        fadeVolume(to: 1, duration: fadeInDuration)

        let playbackDuration = min(player.duration, maximumPlaybackDuration)
        let fadeOutDelay = max(0, playbackDuration - fadeOutDuration)
        stopTimer = Timer.scheduledTimer(withTimeInterval: fadeOutDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.stop(fadeOutDuration: min(fadeOutDuration, playbackDuration))
            }
        }
    }

    func stop(fadeOutDuration: TimeInterval) {
        stopTimer?.invalidate()
        stopTimer = nil

        guard let player else {
            fadeTimer?.invalidate()
            fadeTimer = nil
            return
        }

        guard fadeOutDuration > 0, player.isPlaying, player.volume > 0 else {
            stopImmediately()
            return
        }

        fadeVolume(to: 0, duration: fadeOutDuration) { [weak self] in
            self?.stopImmediately()
        }
    }

    private func stopImmediately() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        stopTimer?.invalidate()
        stopTimer = nil
        player?.stop()
        player = nil
    }

    private func fadeVolume(
        to targetVolume: Float,
        duration: TimeInterval,
        completion: (() -> Void)? = nil
    ) {
        fadeTimer?.invalidate()

        guard let player, duration > 0 else {
            player?.volume = targetVolume
            completion?()
            return
        }

        let startingVolume = player.volume
        let startedAt = Date()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            guard let self, let player = self.player else {
                timer.invalidate()
                return
            }

            let progress = min(1, Date().timeIntervalSince(startedAt) / duration)
            player.volume = startingVolume + Float(progress) * (targetVolume - startingVolume)

            if progress >= 1 {
                timer.invalidate()
                self.fadeTimer = nil
                completion?()
            }
        }
    }
}

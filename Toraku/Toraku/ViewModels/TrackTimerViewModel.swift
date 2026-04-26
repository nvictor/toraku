import Combine
import Foundation

@MainActor
final class TrackTimerViewModel: ObservableObject {
    @Published private(set) var segments: [TrackSegment] = []
    @Published private(set) var timeline: [ScheduledSegment] = []
    @Published private(set) var playbackState: PlaybackState = .stopped
    @Published private(set) var pausedElapsed: TimeInterval = 0
    @Published private(set) var scheduleError: String?
    @Published var isImporting = false
    @Published var eventStartDate: Date {
        didSet {
            refreshPausedElapsedFromEventStart()
            tickDate = now()
        }
    }

    @Published private var tickDate = Date()

    private var timerCancellable: AnyCancellable?
    private let now: () -> Date

    init(loadSample: Bool = true, startTimer: Bool = true, now: @escaping () -> Date = Date.init) {
        self.now = now
        let initialDate = now()
        eventStartDate = initialDate
        tickDate = initialDate

        if startTimer {
            startTimerLoop()
        }

        if loadSample {
            loadSampleSchedule()
        }
    }

    deinit {
        timerCancellable?.cancel()
    }

    var elapsed: TimeInterval {
        switch playbackState {
        case .playing:
            _ = tickDate
            return now().timeIntervalSince(eventStartDate)
        case .paused, .stopped:
            return pausedElapsed
        }
    }

    var totalDuration: TimeInterval {
        timeline.last?.endOffset ?? 0
    }

    var clampedElapsed: TimeInterval {
        min(max(0, elapsed), totalDuration)
    }

    var progress: Double {
        guard totalDuration > 0 else {
            return 0
        }

        return clampedElapsed / totalDuration
    }

    var currentSegment: ScheduledSegment? {
        segment(at: elapsed)
    }

    var currentIndex: Int? {
        guard let currentSegment else {
            return nil
        }

        return timeline.firstIndex(where: { $0.id == currentSegment.id })
    }

    var nextSegment: ScheduledSegment? {
        guard let currentIndex else {
            return timeline.first
        }

        let nextIndex = timeline.index(after: currentIndex)
        guard timeline.indices.contains(nextIndex) else {
            return nil
        }

        return timeline[nextIndex]
    }

    var remainingInCurrentSegment: TimeInterval {
        guard let currentSegment else {
            return 0
        }

        return currentSegment.endOffset - elapsed
    }

    var totalRemaining: TimeInterval {
        max(0, totalDuration - elapsed)
    }

    var isWarning: Bool {
        remainingInCurrentSegment > 0 && remainingInCurrentSegment <= 60
    }

    var isOvertime: Bool {
        remainingInCurrentSegment < 0
    }

    func loadSampleSchedule() {
        do {
            let loadedSegments = try ScheduleLoader.loadSampleSchedule()
            try replaceSchedule(with: loadedSegments)
        } catch {
            scheduleError = error.localizedDescription
        }
    }

    func importSchedule(from url: URL) {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let loadedSegments = try ScheduleLoader.decodeSchedule(from: data)
            try replaceSchedule(with: loadedSegments)
        } catch let error as ScheduleError {
            scheduleError = error.localizedDescription
        } catch {
            scheduleError = ScheduleError.unreadableFile.localizedDescription
        }
    }

    func replaceSchedule(with segments: [TrackSegment]) throws {
        let builtTimeline = try ScheduleLoader.buildTimeline(from: segments)
        self.segments = segments
        timeline = builtTimeline
        scheduleError = nil
        reset()
    }

    func playPause() {
        switch playbackState {
        case .stopped, .paused:
            play()
        case .playing:
            pause()
        }
    }

    func play() {
        guard !timeline.isEmpty else {
            return
        }

        if playbackState == .stopped {
            pausedElapsed = now().timeIntervalSince(eventStartDate)
        }

        tickDate = now()
        playbackState = .playing
    }

    func pause() {
        guard playbackState == .playing else {
            return
        }

        pausedElapsed = elapsed
        playbackState = .paused
    }

    func reset() {
        let currentDate = now()
        pausedElapsed = 0
        playbackState = .stopped
        eventStartDate = currentDate
        pausedElapsed = 0
        tickDate = currentDate
    }

    func skip() {
        guard !timeline.isEmpty else {
            return
        }

        if let nextSegment {
            setElapsed(nextSegment.startOffset)
        } else {
            setElapsed(totalDuration)
            playbackState = .stopped
        }
    }

    func seek(to offset: TimeInterval) {
        setElapsed(offset)
    }

    func clearError() {
        scheduleError = nil
    }

    func showError(_ message: String) {
        scheduleError = message
    }

    func segment(at offset: TimeInterval) -> ScheduledSegment? {
        guard !timeline.isEmpty else {
            return nil
        }

        if offset >= totalDuration {
            return timeline.last
        }

        if offset < 0 {
            return timeline.first
        }

        return timeline.first { offset >= $0.startOffset && offset < $0.endOffset }
    }

    private func setElapsed(_ offset: TimeInterval) {
        pausedElapsed = min(max(0, offset), totalDuration)

        if playbackState == .playing {
            eventStartDate = now().addingTimeInterval(-pausedElapsed)
        }

        tickDate = now()
    }

    private func refreshPausedElapsedFromEventStart() {
        guard playbackState != .playing else {
            return
        }

        pausedElapsed = min(max(0, now().timeIntervalSince(eventStartDate)), totalDuration)
    }

    private func startTimerLoop() {
        timerCancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.tickDate = date
            }
    }
}

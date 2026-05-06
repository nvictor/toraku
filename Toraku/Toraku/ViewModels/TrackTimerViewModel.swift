import Combine
import Foundation

@MainActor
final class TrackTimerViewModel: ObservableObject {
    enum EventPhase: Equatable {
        case noSchedule
        case beforeStart(TimeInterval)
        case running
        case ended(TimeInterval)
    }

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
    private let persistedScheduleURL: URL

    init(
        loadSample: Bool = true,
        startTimer: Bool = true,
        persistedScheduleURL: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.now = now
        self.persistedScheduleURL = persistedScheduleURL ?? Self.defaultPersistedScheduleURL()
        let initialDate = now()
        eventStartDate = initialDate
        tickDate = initialDate

        if startTimer {
            startTimerLoop()
        }

        if loadSample {
            loadStartupSchedule()
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
        case .stopped where pausedElapsed < 0:
            _ = tickDate
            return now().timeIntervalSince(eventStartDate)
        case .paused, .stopped:
            return pausedElapsed
        }
    }

    var eventPhase: EventPhase {
        guard totalDuration > 0 else {
            return .noSchedule
        }

        let elapsed = elapsed
        if elapsed < 0 {
            return .beforeStart(abs(elapsed))
        }

        if elapsed >= totalDuration {
            return .ended(elapsed - totalDuration)
        }

        return .running
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
            try persistSchedule(loadedSegments)
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
        resetForNewSchedule()
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

    private func resetForNewSchedule() {
        let currentDate = now()
        pausedElapsed = 0
        playbackState = .stopped
        eventStartDate = currentDate
        pausedElapsed = 0
        tickDate = currentDate
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

        pausedElapsed = min(now().timeIntervalSince(eventStartDate), totalDuration)
    }

    private func startTimerLoop() {
        timerCancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.tickDate = date
            }
    }

    private func loadStartupSchedule() {
        do {
            if let persistedSegments = try loadPersistedSchedule() {
                try replaceSchedule(with: persistedSegments)
            } else {
                loadSampleSchedule()
            }
        } catch {
            loadSampleSchedule()
            scheduleError = "Could not load the saved schedule. \(error.localizedDescription)"
        }
    }

    private func loadPersistedSchedule() throws -> [TrackSegment]? {
        guard FileManager.default.fileExists(atPath: persistedScheduleURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: persistedScheduleURL)
        return try ScheduleLoader.decodeSchedule(from: data)
    }

    private func persistSchedule(_ segments: [TrackSegment]) throws {
        let directory = persistedScheduleURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(segments)
        try data.write(to: persistedScheduleURL, options: .atomic)
    }

    private static func defaultPersistedScheduleURL() -> URL {
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        return applicationSupportURL
            .appendingPathComponent("Toraku", isDirectory: true)
            .appendingPathComponent("Schedule.json")
    }
}

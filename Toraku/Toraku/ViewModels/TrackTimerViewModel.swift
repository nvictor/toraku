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
    @Published private(set) var isMusicMuted = false
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
    private let persistedScheduleSourceDirectoryURL: URL
    private let musicController: SegmentMusicControlling
    private var scheduleSourceDirectory: URL?
    private var currentMusicSegmentID: UUID?
    private let musicFadeDuration: TimeInterval = 2

    init(
        loadSample: Bool = true,
        startTimer: Bool = true,
        persistedScheduleURL: URL? = nil,
        musicController: SegmentMusicControlling? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.now = now
        self.persistedScheduleURL = persistedScheduleURL ?? Self.defaultPersistedScheduleURL()
        persistedScheduleSourceDirectoryURL = self.persistedScheduleURL
            .deletingLastPathComponent()
            .appendingPathComponent("ScheduleSourceDirectory.txt")
        self.musicController = musicController ?? SegmentMusicController()
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

    var isMusicControlAvailable: Bool {
        let relevantSegments: ArraySlice<ScheduledSegment>
        if let currentIndex {
            relevantSegments = timeline[currentIndex...]
        } else {
            relevantSegments = timeline[...]
        }

        return relevantSegments.contains { scheduledSegment in
            guard let music = scheduledSegment.segment.music else {
                return false
            }

            return !music.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func loadSampleSchedule() {
        do {
            let loadedSegments = try ScheduleLoader.loadSampleSchedule()
            scheduleSourceDirectory = Bundle.main.resourceURL
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
            scheduleSourceDirectory = url.deletingLastPathComponent()
            try replaceSchedule(with: loadedSegments)
            try persistSchedule(loadedSegments)
            try persistScheduleSourceDirectory(url.deletingLastPathComponent())
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
        stopMusic(fadeOutDuration: 0)
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
        synchronizeMusicWithCurrentSegment()
    }

    func pause() {
        guard playbackState == .playing else {
            return
        }

        pausedElapsed = elapsed
        playbackState = .paused
        stopMusic(fadeOutDuration: musicFadeDuration)
    }

    func seek(to offset: TimeInterval) {
        stopMusic(fadeOutDuration: musicFadeDuration)
        setElapsed(offset)
        synchronizeMusicWithCurrentSegment()
    }

    func toggleMusicMuted() {
        isMusicMuted.toggle()

        if isMusicMuted {
            stopMusic(fadeOutDuration: musicFadeDuration)
        } else {
            synchronizeMusicWithCurrentSegment()
        }
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
        stopMusic(fadeOutDuration: 0)
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
                self?.synchronizeMusicWithCurrentSegment()
            }
    }

    private func loadStartupSchedule() {
        do {
            if let persistedSegments = try loadPersistedSchedule() {
                scheduleSourceDirectory = try loadPersistedScheduleSourceDirectory()
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

    func resolvedMusicURL(for musicPath: String) -> URL? {
        let trimmedPath = musicPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return nil
        }

        if trimmedPath.hasPrefix("/") {
            return URL(fileURLWithPath: trimmedPath)
        }

        return scheduleSourceDirectory?.appendingPathComponent(trimmedPath)
    }

    private func synchronizeMusicWithCurrentSegment() {
        guard playbackState == .playing, case .running = eventPhase else {
            stopMusic(fadeOutDuration: musicFadeDuration)
            return
        }

        guard !isMusicMuted, let currentSegment else {
            stopMusic(fadeOutDuration: musicFadeDuration)
            return
        }

        guard currentMusicSegmentID != currentSegment.id else {
            return
        }

        guard
            let musicPath = currentSegment.segment.music,
            let musicURL = resolvedMusicURL(for: musicPath)
        else {
            stopMusic(fadeOutDuration: musicFadeDuration)
            return
        }

        let maximumPlaybackDuration = max(0, currentSegment.endOffset - elapsed)
        guard maximumPlaybackDuration > 0 else {
            stopMusic(fadeOutDuration: musicFadeDuration)
            return
        }

        do {
            currentMusicSegmentID = currentSegment.id
            try musicController.play(
                url: musicURL,
                fadeInDuration: musicFadeDuration,
                fadeOutDuration: musicFadeDuration,
                maximumPlaybackDuration: maximumPlaybackDuration
            )
        } catch {
            stopMusic(fadeOutDuration: 0)
            scheduleError = "Toraku could not play music for \"\(currentSegment.segment.title)\". \(error.localizedDescription)"
        }
    }

    private func stopMusic(fadeOutDuration: TimeInterval) {
        currentMusicSegmentID = nil
        musicController.stop(fadeOutDuration: fadeOutDuration)
    }

    private func persistScheduleSourceDirectory(_ url: URL) throws {
        let directory = persistedScheduleSourceDirectoryURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try url.path.write(to: persistedScheduleSourceDirectoryURL, atomically: true, encoding: .utf8)
    }

    private func loadPersistedScheduleSourceDirectory() throws -> URL? {
        guard FileManager.default.fileExists(atPath: persistedScheduleSourceDirectoryURL.path) else {
            return nil
        }

        let path = try String(contentsOf: persistedScheduleSourceDirectoryURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path, isDirectory: true)
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

import XCTest
@testable import Toraku

@MainActor
final class TorakuTests: XCTestCase {
    func testDecodesSimpleScheduleAndBreakType() throws {
        let data = Data(
            """
            [
              { "title": "Welcome", "durationMinutes": 5, "type": "intro" },
              { "title": "Break", "durationMinutes": 10, "type": "break" }
            ]
            """.utf8
        )

        let segments = try ScheduleLoader.decodeSchedule(from: data)

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].title, "Welcome")
        XCTAssertNil(segments[0].speaker)
        XCTAssertEqual(segments[1].type, .breakTime)
    }

    func testDecodesOptionalSpeaker() throws {
        let data = Data(
            """
            [
              {
                "title": "Scaling SwiftUI",
                "speaker": "Jane Doe",
                "durationMinutes": 25,
                "type": "talk"
              }
            ]
            """.utf8
        )

        let segments = try ScheduleLoader.decodeSchedule(from: data)

        XCTAssertEqual(segments.first?.speaker, "Jane Doe")
    }

    func testDecodesFractionalDurationMinutes() throws {
        let data = Data(
            """
            [
              { "title": "Lightning", "durationMinutes": 0.75, "type": "intro" },
              { "title": "Short Talk", "durationMinutes": 1.25, "type": "talk" }
            ]
            """.utf8
        )

        let segments = try ScheduleLoader.decodeSchedule(from: data)
        let timeline = try ScheduleLoader.buildTimeline(from: segments)

        XCTAssertEqual(segments[0].durationMinutes, 0.75, accuracy: 0.001)
        XCTAssertEqual(timeline[0].endOffset, 45, accuracy: 0.001)
        XCTAssertEqual(timeline[1].startOffset, 45, accuracy: 0.001)
        XCTAssertEqual(timeline[1].endOffset, 120, accuracy: 0.001)
    }

    func testDecodesScheduleWithCommentedOutSegment() throws {
        let data = Data(
            """
            [
              { "title": "Welcome", "durationMinutes": 5, "type": "intro" },
              // {
              //   "title": "Commented Out",
              //   "durationMinutes": 10,
              //   "type": "talk"
              // },
              { "title": "Q&A", "durationMinutes": 5, "type": "qa" }
            ]
            """.utf8
        )

        let segments = try ScheduleLoader.decodeSchedule(from: data)

        XCTAssertEqual(segments.map(\.title), ["Welcome", "Q&A"])
    }

    func testDecodesScheduleWithCommentedOutFinalSegmentAndTrailingComma() throws {
        let data = Data(
            """
            [
              { "title": "Welcome", "durationMinutes": 5, "type": "intro" },
              // { "title": "Skipped", "durationMinutes": 10, "type": "talk" },
            ]
            """.utf8
        )

        let segments = try ScheduleLoader.decodeSchedule(from: data)

        XCTAssertEqual(segments.map(\.title), ["Welcome"])
    }

    func testRejectsEmptySchedule() {
        XCTAssertThrowsError(try ScheduleLoader.decodeSchedule(from: Data("[]".utf8))) { error in
            XCTAssertEqual(error as? ScheduleError, .emptySchedule)
        }
    }

    func testRejectsBlankTitle() {
        let data = Data(
            """
            [
              { "title": "   ", "durationMinutes": 5, "type": "intro" }
            ]
            """.utf8
        )

        XCTAssertThrowsError(try ScheduleLoader.decodeSchedule(from: data)) { error in
            XCTAssertEqual(error as? ScheduleError, .blankTitle(index: 0))
        }
    }

    func testRejectsNonPositiveDuration() {
        let data = Data(
            """
            [
              { "title": "Welcome", "durationMinutes": 0, "type": "intro" }
            ]
            """.utf8
        )

        XCTAssertThrowsError(try ScheduleLoader.decodeSchedule(from: data)) { error in
            XCTAssertEqual(error as? ScheduleError, .invalidDuration(title: "Welcome"))
        }
    }

    func testRejectsInvalidSegmentType() {
        let data = Data(
            """
            [
              { "title": "Welcome", "durationMinutes": 5, "type": "panel" }
            ]
            """.utf8
        )

        XCTAssertThrowsError(try ScheduleLoader.decodeSchedule(from: data)) { error in
            guard case .decodingFailed = error as? ScheduleError else {
                return XCTFail("Expected decoding failure, got \(error)")
            }
        }
    }

    func testBuildTimelineUsesCumulativeOffsets() throws {
        let segments = [
            TrackSegment(id: UUID(), title: "A", durationMinutes: 5, type: .intro),
            TrackSegment(id: UUID(), title: "B", durationMinutes: 10, type: .talk),
            TrackSegment(id: UUID(), title: "C", durationMinutes: 2, type: .qa)
        ]

        let timeline = try ScheduleLoader.buildTimeline(from: segments)

        XCTAssertEqual(timeline[0].startOffset, 0)
        XCTAssertEqual(timeline[0].endOffset, 300)
        XCTAssertEqual(timeline[1].startOffset, 300)
        XCTAssertEqual(timeline[1].endOffset, 900)
        XCTAssertEqual(timeline[2].startOffset, 900)
        XCTAssertEqual(timeline[2].endOffset, 1020)
    }

    func testFormatsFractionalMinuteDurations() {
        XCTAssertEqual(DurationFormatting.minutes(45), "45 sec")
        XCTAssertEqual(DurationFormatting.minutes(75), "1 min 15 sec")
        XCTAssertEqual(DurationFormatting.minutes(120), "2 min")
    }

    func testFormatsTimelineTimeRange() {
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.timeZone = timeZone
        let startDate = DateComponents(
            calendar: calendar,
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 27,
            hour: 9,
            minute: 30
        ).date!

        XCTAssertEqual(
            DurationFormatting.timeRange(
                startDate: startDate,
                startOffset: 0,
                endOffset: 300,
                calendar: calendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: timeZone
            ),
            "9:30 AM-9:35 AM"
        )

        XCTAssertEqual(
            DurationFormatting.timeRange(
                startDate: startDate,
                startOffset: 45,
                endOffset: 120,
                calendar: calendar,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: timeZone
            ),
            "9:30:45 AM-9:32:00 AM"
        )
    }

    func testCurrentAndNextSegmentBoundaryLookup() throws {
        let model = TrackTimerViewModel(loadSample: false, startTimer: false)
        try model.replaceSchedule(with: [
            TrackSegment(title: "A", durationMinutes: 5, type: .intro),
            TrackSegment(title: "B", durationMinutes: 10, type: .talk)
        ])

        model.seek(to: 299)
        XCTAssertEqual(model.currentSegment?.segment.title, "A")
        XCTAssertEqual(model.nextSegment?.segment.title, "B")

        model.seek(to: 300)
        XCTAssertEqual(model.currentSegment?.segment.title, "B")
        XCTAssertNil(model.nextSegment)
    }

    func testPlaybackTransitions() throws {
        let model = TrackTimerViewModel(loadSample: false, startTimer: false)
        try model.replaceSchedule(with: [
            TrackSegment(title: "A", durationMinutes: 5, type: .intro),
            TrackSegment(title: "B", durationMinutes: 10, type: .talk)
        ])

        XCTAssertEqual(model.playbackState, .stopped)

        model.play()
        XCTAssertEqual(model.playbackState, .playing)

        model.pause()
        XCTAssertEqual(model.playbackState, .paused)

        model.play()
        XCTAssertEqual(model.playbackState, .playing)
    }

    func testElapsedUsesEventStartTimeInsteadOfPlayTime() throws {
        var currentDate = Date(timeIntervalSinceReferenceDate: 10 * 60 * 60)
        let model = TrackTimerViewModel(loadSample: false, startTimer: false) {
            currentDate
        }
        try model.replaceSchedule(with: [
            TrackSegment(title: "A", durationMinutes: 30, type: .intro),
            TrackSegment(title: "B", durationMinutes: 10, type: .talk)
        ])

        model.eventStartDate = currentDate.addingTimeInterval(-15 * 60)
        model.play()

        XCTAssertEqual(model.elapsed, 15 * 60, accuracy: 0.001)
        XCTAssertEqual(model.clampedElapsed, 15 * 60, accuracy: 0.001)
        XCTAssertEqual(model.currentSegment?.segment.title, "A")

        currentDate = currentDate.addingTimeInterval(5 * 60)

        XCTAssertEqual(model.elapsed, 20 * 60, accuracy: 0.001)
    }

    func testFutureStartShowsCountdown() throws {
        let currentDate = Date(timeIntervalSinceReferenceDate: 10 * 60 * 60)
        let model = TrackTimerViewModel(loadSample: false, startTimer: false) {
            currentDate
        }
        try model.replaceSchedule(with: [
            TrackSegment(title: "A", durationMinutes: 20, type: .intro)
        ])

        model.eventStartDate = currentDate.addingTimeInterval(5 * 60)

        XCTAssertEqual(model.eventPhase, .beforeStart(5 * 60))
        XCTAssertEqual(model.elapsed, -5 * 60, accuracy: 0.001)
    }

    func testFutureStartAdvancesThroughRunningAndEndedWhileStopped() throws {
        var currentDate = Date(timeIntervalSinceReferenceDate: 10 * 60 * 60)
        let model = TrackTimerViewModel(loadSample: false, startTimer: false) {
            currentDate
        }
        try model.replaceSchedule(with: [
            TrackSegment(title: "A", durationMinutes: 1, type: .intro)
        ])

        model.eventStartDate = currentDate.addingTimeInterval(30)

        XCTAssertEqual(model.eventPhase, .beforeStart(30))

        currentDate = currentDate.addingTimeInterval(30)

        XCTAssertEqual(model.eventPhase, .running)
        XCTAssertEqual(model.currentSegment?.segment.title, "A")

        currentDate = currentDate.addingTimeInterval(75)

        XCTAssertEqual(model.eventPhase, .ended(15))
    }

    func testEventEndedPhaseCountsPastTotalDuration() throws {
        var currentDate = Date(timeIntervalSinceReferenceDate: 10 * 60 * 60)
        let model = TrackTimerViewModel(loadSample: false, startTimer: false) {
            currentDate
        }
        try model.replaceSchedule(with: [
            TrackSegment(title: "A", durationMinutes: 20, type: .intro)
        ])

        model.eventStartDate = currentDate.addingTimeInterval(-20 * 60)
        model.play()
        currentDate = currentDate.addingTimeInterval(90)

        XCTAssertEqual(model.eventPhase, .ended(90))
        XCTAssertEqual(model.clampedElapsed, model.totalDuration, accuracy: 0.001)
        XCTAssertEqual(model.totalRemaining, 0, accuracy: 0.001)
    }

    func testImportedSchedulePersistsAndRestoresOnStartup() throws {
        let persistenceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("Schedule.json")
        let importURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
        defer {
            try? FileManager.default.removeItem(at: persistenceURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: importURL)
        }

        let data = Data(
            """
            [
              { "title": "Persisted", "durationMinutes": 7, "type": "intro" },
              { "title": "Restored", "durationMinutes": 11, "type": "talk" }
            ]
            """.utf8
        )
        try data.write(to: importURL)

        let importingModel = TrackTimerViewModel(
            loadSample: false,
            startTimer: false,
            persistedScheduleURL: persistenceURL
        )
        importingModel.importSchedule(from: importURL)

        XCTAssertEqual(importingModel.segments.map(\.title), ["Persisted", "Restored"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: persistenceURL.path))

        let restoringModel = TrackTimerViewModel(
            loadSample: true,
            startTimer: false,
            persistedScheduleURL: persistenceURL
        )

        XCTAssertEqual(restoringModel.segments.map(\.title), ["Persisted", "Restored"])
        XCTAssertNil(restoringModel.scheduleError)
    }
}

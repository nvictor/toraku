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

        model.skip()
        XCTAssertEqual(model.currentSegment?.segment.title, "B")

        model.reset()
        XCTAssertEqual(model.playbackState, .stopped)
        XCTAssertEqual(model.elapsed, 0)
        XCTAssertEqual(model.currentSegment?.segment.title, "A")
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

    func testSkipKeepsLiveTimerAnchoredToWallClock() throws {
        var currentDate = Date(timeIntervalSinceReferenceDate: 10 * 60 * 60)
        let model = TrackTimerViewModel(loadSample: false, startTimer: false) {
            currentDate
        }
        try model.replaceSchedule(with: [
            TrackSegment(title: "A", durationMinutes: 20, type: .intro),
            TrackSegment(title: "B", durationMinutes: 10, type: .talk)
        ])

        model.eventStartDate = currentDate.addingTimeInterval(-15 * 60)
        model.play()
        model.skip()

        XCTAssertEqual(model.currentSegment?.segment.title, "B")
        XCTAssertEqual(model.elapsed, 20 * 60, accuracy: 0.001)

        currentDate = currentDate.addingTimeInterval(60)

        XCTAssertEqual(model.elapsed, 21 * 60, accuracy: 0.001)
        XCTAssertEqual(model.currentSegment?.segment.title, "B")
    }
}

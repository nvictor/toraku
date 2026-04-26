import Foundation

enum ScheduleLoader {
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()

    static func decodeSchedule(from data: Data) throws -> [TrackSegment] {
        do {
            let segments = try decoder.decode([TrackSegment].self, from: data)
            try validate(segments)
            return segments
        } catch let error as ScheduleError {
            throw error
        } catch {
            throw ScheduleError.decodingFailed(error.localizedDescription)
        }
    }

    static func loadSampleSchedule(bundle: Bundle = .main) throws -> [TrackSegment] {
        guard let url = bundle.url(forResource: "sample-track", withExtension: "json") else {
            throw ScheduleError.missingSampleSchedule
        }

        let data = try Data(contentsOf: url)
        return try decodeSchedule(from: data)
    }

    static func validate(_ segments: [TrackSegment]) throws {
        guard !segments.isEmpty else {
            throw ScheduleError.emptySchedule
        }

        for (index, segment) in segments.enumerated() {
            if segment.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw ScheduleError.blankTitle(index: index)
            }

            if segment.durationMinutes <= 0 {
                throw ScheduleError.invalidDuration(title: segment.title)
            }
        }
    }

    static func buildTimeline(from segments: [TrackSegment]) throws -> [ScheduledSegment] {
        try validate(segments)

        var currentOffset: TimeInterval = 0

        return segments.map { segment in
            let duration = TimeInterval(segment.durationMinutes * 60)
            let scheduled = ScheduledSegment(
                id: segment.id,
                segment: segment,
                startOffset: currentOffset,
                endOffset: currentOffset + duration
            )
            currentOffset += duration
            return scheduled
        }
    }
}

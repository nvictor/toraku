import Foundation

struct ScheduledSegment: Identifiable, Equatable {
    let id: UUID
    let segment: TrackSegment
    let startOffset: TimeInterval
    let endOffset: TimeInterval

    var duration: TimeInterval {
        endOffset - startOffset
    }

    var durationMinutes: Int {
        segment.durationMinutes
    }
}

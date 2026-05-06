import Foundation

struct TrackSegment: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let speaker: String?
    let durationMinutes: Double
    let type: SegmentType
    let music: String?

    init(
        id: UUID = UUID(),
        title: String,
        speaker: String? = nil,
        durationMinutes: Double,
        type: SegmentType,
        music: String? = nil
    ) {
        self.id = id
        self.title = title
        self.speaker = speaker
        self.durationMinutes = durationMinutes
        self.type = type
        self.music = music
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case speaker
        case durationMinutes
        case type
        case music
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        speaker = try container.decodeIfPresent(String.self, forKey: .speaker)
        durationMinutes = try container.decode(Double.self, forKey: .durationMinutes)
        type = try container.decode(SegmentType.self, forKey: .type)
        music = try container.decodeIfPresent(String.self, forKey: .music)
    }
}

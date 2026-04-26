import SwiftUI

enum SegmentType: String, Codable, CaseIterable {
    case intro
    case talk
    case qa
    case breakTime = "break"
    case outro
    case custom

    var label: String {
        switch self {
        case .intro:
            "Intro"
        case .talk:
            "Talk"
        case .qa:
            "Q&A"
        case .breakTime:
            "Break"
        case .outro:
            "Outro"
        case .custom:
            "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .intro:
            "sparkles"
        case .talk:
            "person.wave.2"
        case .qa:
            "questionmark.bubble"
        case .breakTime:
            "cup.and.saucer"
        case .outro:
            "flag.checkered"
        case .custom:
            "circle.grid.2x2"
        }
    }

    var tint: Color {
        switch self {
        case .intro:
            .teal
        case .talk:
            .blue
        case .qa:
            .indigo
        case .breakTime:
            .orange
        case .outro:
            .green
        case .custom:
            .secondary
        }
    }
}

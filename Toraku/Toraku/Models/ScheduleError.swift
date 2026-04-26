import Foundation

enum ScheduleError: LocalizedError, Equatable {
    case emptySchedule
    case blankTitle(index: Int)
    case invalidDuration(title: String)
    case missingSampleSchedule
    case unreadableFile
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptySchedule:
            "The schedule is empty."
        case .blankTitle(let index):
            "Segment \(index + 1) needs a title."
        case .invalidDuration(let title):
            "\"\(title)\" needs a duration greater than zero."
        case .missingSampleSchedule:
            "The bundled sample schedule could not be found."
        case .unreadableFile:
            "Toraku could not read that file."
        case .decodingFailed(let message):
            "Toraku could not decode that JSON file. \(message)"
        }
    }
}

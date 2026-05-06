import Foundation

extension URL {
    func isDescendant(of directoryURL: URL) -> Bool {
        let filePath = standardizedFileURL.path
        let rawDirectoryPath = directoryURL.standardizedFileURL.path
        var directoryPath = rawDirectoryPath

        if !directoryPath.hasSuffix("/") {
            directoryPath += "/"
        }

        return filePath == rawDirectoryPath || filePath.hasPrefix(directoryPath)
    }
}

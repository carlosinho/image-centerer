import Foundation

public enum ExportFileNamer {
    public static func destinationURL(
        for sourceURL: URL,
        format: ImageFormat,
        in folderURL: URL,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        let fileExtension = format.fileExtension
        var candidate = folderURL
            .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension(fileExtension)
        var index = 2

        while fileExists(candidate) {
            candidate = folderURL
                .appendingPathComponent("\(sourceURL.deletingPathExtension().lastPathComponent) \(index)")
                .appendingPathExtension(fileExtension)
            index += 1
        }
        return candidate
    }
}

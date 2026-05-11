import Foundation
import ImageCentererCore

struct ImageJob: Identifiable, Equatable {
    let id: UUID
    let sourceURL: URL
    var fileName: String
    var format: ImageFormat
    var pixelWidth: Int?
    var pixelHeight: Int?
    var status: ImageJobStatus

    init(sourceURL: URL, format: ImageFormat, pixelWidth: Int?, pixelHeight: Int?) {
        self.id = UUID()
        self.sourceURL = sourceURL
        self.fileName = sourceURL.lastPathComponent
        self.format = format
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.status = .ready
    }
}

enum ImageJobStatus: Equatable {
    case ready
    case exported(URL)
    case failed(String)

    var label: String {
        switch self {
        case .ready:
            return "Ready"
        case .exported:
            return "Exported"
        case .failed(let message):
            return "Failed: \(message)"
        }
    }
}

struct ExportSummary: Equatable {
    let exportedCount: Int
    let failedCount: Int
}

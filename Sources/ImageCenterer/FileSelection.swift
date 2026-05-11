import AppKit
import Foundation
import ImageCentererCore
import UniformTypeIdentifiers

enum FileSelection {
    static let supportedTypes: [UTType] = [.png, .jpeg]

    @MainActor
    static func selectInputImages() -> [URL] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = supportedTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true
        return panel.runModal() == .OK ? panel.urls : []
    }

    @MainActor
    static func selectExportFolder() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Export"
        return panel.runModal() == .OK ? panel.url : nil
    }
}

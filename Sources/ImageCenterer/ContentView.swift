import AppKit
import ImageCentererCore
import SwiftUI

struct ContentView: View {
    @State private var jobs: [ImageJob] = []
    @State private var selectedJobID: ImageJob.ID?
    @State private var canvasWidth = ""
    @State private var canvasHeight = ""
    @State private var paddingX = "0"
    @State private var paddingY = "0"
    @State private var didInitializeCanvas = false
    @State private var previewImage: NSImage?
    @State private var isExporting = false
    @State private var summaryText = ""

    private let processor = ImageCenteringProcessor()

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedJobID) {
                ForEach(jobs) { job in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.fileName)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            if let width = job.pixelWidth, let height = job.pixelHeight {
                                Text("\(width) x \(height)")
                            }
                            Text(job.status.label)
                                .foregroundStyle(statusColor(job.status))
                                .lineLimit(1)
                        }
                        .font(.caption)
                    }
                    .tag(job.id)
                }
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            VStack(spacing: 0) {
                controls
                Divider()
                preview
                if !summaryText.isEmpty {
                    Text(summaryText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
        }
        .onChange(of: selectedJobID) { _, _ in refreshPreview() }
        .onChange(of: canvasWidth) { _, _ in refreshPreview() }
        .onChange(of: canvasHeight) { _, _ in refreshPreview() }
        .onChange(of: paddingX) { _, _ in refreshPreview() }
        .onChange(of: paddingY) { _, _ in refreshPreview() }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button("Add Images") {
                addImages(FileSelection.selectInputImages())
            }
            Button("Clear") {
                jobs.removeAll()
                selectedJobID = nil
                previewImage = nil
                summaryText = ""
                didInitializeCanvas = false
            }
            .disabled(jobs.isEmpty || isExporting)

            Spacer()

            Text("Canvas")
                .foregroundStyle(.secondary)
            TextField("Width", text: $canvasWidth)
                .frame(width: 88)
                .textFieldStyle(.roundedBorder)
            TextField("Height", text: $canvasHeight)
                .frame(width: 88)
                .textFieldStyle(.roundedBorder)

            Text("Padding")
                .foregroundStyle(.secondary)
            TextField("X", text: $paddingX)
                .frame(width: 72)
                .textFieldStyle(.roundedBorder)
            TextField("Y", text: $paddingY)
                .frame(width: 72)
                .textFieldStyle(.roundedBorder)

            Button("Export") {
                exportImages()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canExport)
        }
        .padding(16)
    }

    private var preview: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if let previewImage {
                Image(nsImage: previewImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(24)
            } else {
                Text(jobs.isEmpty ? "Add JPG or PNG images" : "Enter a valid canvas size and padding")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectedJob: ImageJob? {
        guard let selectedJobID else { return jobs.first }
        return jobs.first { $0.id == selectedJobID }
    }

    private var currentCanvasSize: CanvasSize? {
        guard let width = Int(canvasWidth), let height = Int(canvasHeight) else {
            return nil
        }
        return try? CanvasSize(width: width, height: height)
    }

    private var currentPadding: CanvasPadding? {
        guard let x = Int(paddingX), let y = Int(paddingY) else {
            return nil
        }
        return try? CanvasPadding(x: x, y: y)
    }

    private var canExport: Bool {
        !jobs.isEmpty && currentCanvasSize != nil && currentPadding != nil && !isExporting
    }

    private func addImages(_ urls: [URL]) {
        let existing = Set(jobs.map(\.sourceURL))
        var added: [ImageJob] = []

        for url in urls where !existing.contains(url) {
            do {
                let info = try processor.imageInfo(at: url)
                added.append(ImageJob(sourceURL: url, format: info.format, pixelWidth: info.width, pixelHeight: info.height))
                if !didInitializeCanvas {
                    canvasWidth = String(info.width)
                    canvasHeight = String(info.height)
                    didInitializeCanvas = true
                }
            } catch {
                let fallbackFormat = (try? ImageFormat.detect(from: url)) ?? .png
                var job = ImageJob(sourceURL: url, format: fallbackFormat, pixelWidth: nil, pixelHeight: nil)
                job.status = .failed(error.localizedDescription)
                added.append(job)
            }
        }

        jobs.append(contentsOf: added)
        if selectedJobID == nil {
            selectedJobID = jobs.first?.id
        }
        summaryText = ""
        refreshPreview()
    }

    private func refreshPreview() {
        guard let job = selectedJob, let canvasSize = currentCanvasSize, let padding = currentPadding else {
            previewImage = nil
            return
        }
        do {
            let processed = try processor.processImage(at: job.sourceURL, canvasSize: canvasSize, padding: padding)
            previewImage = NSImage(data: processed.data)
        } catch {
            previewImage = nil
        }
    }

    private func exportImages() {
        guard let canvasSize = currentCanvasSize,
              let padding = currentPadding,
              let folderURL = FileSelection.selectExportFolder() else {
            return
        }
        isExporting = true
        summaryText = ""

        var exported = 0
        var failed = 0
        for index in jobs.indices {
            do {
                let processed = try processor.processImage(
                    at: jobs[index].sourceURL,
                    canvasSize: canvasSize,
                    padding: padding
                )
                let destination = ExportFileNamer.destinationURL(
                    for: jobs[index].sourceURL,
                    format: processed.format,
                    in: folderURL
                )
                try processed.data.write(to: destination, options: .atomic)
                jobs[index].status = .exported(destination)
                exported += 1
            } catch {
                jobs[index].status = .failed(error.localizedDescription)
                failed += 1
            }
        }

        isExporting = false
        summaryText = "Exported \(exported). Failed \(failed)."
    }

    private func statusColor(_ status: ImageJobStatus) -> Color {
        switch status {
        case .ready:
            return .secondary
        case .exported:
            return .green
        case .failed:
            return .red
        }
    }
}

import CoreGraphics
import Foundation
import ImageCentererCore
import ImageIO

@main
struct ImageCentererTestRunner {
    static func main() throws {
        let tests = ProcessorTests()
        try tests.pngSmallerThanCanvasIsNotScaledUp()
        try tests.mixedOverflowImageIsScaledToFit()
        try tests.paddingIsAppliedBeforeFit()
        try tests.jpegOutputKeepsJPEGFormatAndCanvasSize()
        try tests.sameSizeCanvasDoesNotAddBorder()
        try tests.largerImageIsScaledDownToFit()
        try tests.transparentPNGFlattensOverWhite()
        try tests.transparentBackgroundKeepsCanvasTransparent()
        try tests.transparentBackgroundExportsJPEGAsPNG()
        try tests.unsupportedFileThrows()
        try tests.differentSizedImagesAreProcessedIndependently()
        try tests.exportFileNamerKeepsOriginalNamesAndIncrementsConflicts()
        print("All ImageCenterer tests passed.")
    }
}

private struct ProcessorTests {
    func pngSmallerThanCanvasIsNotScaledUp() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("small.png")
            try writeImage(width: 2, height: 2, pixels: Array(repeating: .red, count: 4), format: .png, to: sourceURL)

            let result = try ImageCenteringProcessor().processImage(
                at: sourceURL,
                canvasSize: try CanvasSize(width: 6, height: 6)
            )
            let decoded = try decodePixels(from: result.data)

            try expect(result.format == .png, "PNG input should produce PNG output.")
            try expect(result.pixelWidth == 6, "Output width should match the canvas.")
            try expect(result.pixelHeight == 6, "Output height should match the canvas.")
            try expect(decoded.colorAt(x: 0, y: 0).isClose(to: .white), "Smaller image should not scale up.")
            try expect(decoded.colorAt(x: 5, y: 5).isClose(to: .white), "Smaller image should not scale up.")
            try expect(decoded.colorAt(x: 2, y: 2).isClose(to: .red), "Smaller image should stay centered at original size.")
            try expect(decoded.colorAt(x: 3, y: 3).isClose(to: .red), "Smaller image should stay centered at original size.")
        }
    }

    func mixedOverflowImageIsScaledToFit() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("mixed.png")
            try writeImage(
                width: 1024,
                height: 900,
                pixels: Array(repeating: .red, count: 1024 * 900),
                format: .png,
                to: sourceURL
            )

            let result = try ImageCenteringProcessor().processImage(
                at: sourceURL,
                canvasSize: try CanvasSize(width: 1280, height: 720)
            )
            let decoded = try decodePixels(from: result.data)

            try expect(result.pixelWidth == 1280, "Output width should match the canvas.")
            try expect(result.pixelHeight == 720, "Output height should match the canvas.")
            try expect(decoded.colorAt(x: 200, y: 360).isClose(to: .white), "Scaled image should leave horizontal white margin.")
            try expect(decoded.colorAt(x: 260, y: 360).isClose(to: .red), "Scaled image should occupy the centered interior.")
            try expect(decoded.colorAt(x: 1020, y: 360).isClose(to: .red), "Scaled image should occupy the centered interior.")
            try expect(decoded.colorAt(x: 1100, y: 360).isClose(to: .white), "Scaled image should leave horizontal white margin.")
            try expect(decoded.colorAt(x: 640, y: 0).isClose(to: .red), "Scaled image should fill canvas height.")
            try expect(decoded.colorAt(x: 640, y: 719).isClose(to: .red), "Scaled image should fill canvas height.")
        }
    }

    func paddingIsAppliedBeforeFit() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("padded.png")
            try writeImage(width: 100, height: 100, pixels: Array(repeating: .green, count: 10_000), format: .png, to: sourceURL)

            let result = try ImageCenteringProcessor().processImage(
                at: sourceURL,
                canvasSize: try CanvasSize(width: 200, height: 200),
                padding: try CanvasPadding(x: 50, y: 50)
            )
            let decoded = try decodePixels(from: result.data)

            try expect(decoded.colorAt(x: 49, y: 100).isClose(to: .white), "X padding should remain white.")
            try expect(decoded.colorAt(x: 50, y: 100).isClose(to: .green), "Image should start after X padding.")
            try expect(decoded.colorAt(x: 149, y: 100).isClose(to: .green), "Image should end before right padding.")
            try expect(decoded.colorAt(x: 150, y: 100).isClose(to: .white), "Right X padding should remain white.")
            try expect(decoded.colorAt(x: 100, y: 49).isClose(to: .white), "Y padding should remain white.")
            try expect(decoded.colorAt(x: 100, y: 50).isClose(to: .green), "Image should start after Y padding.")
        }
    }

    func jpegOutputKeepsJPEGFormatAndCanvasSize() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("photo.jpeg")
            try writeImage(width: 3, height: 3, pixels: Array(repeating: .blue, count: 9), format: .jpeg(preferredExtension: "jpeg"), to: sourceURL)

            let result = try ImageCenteringProcessor().processImage(
                at: sourceURL,
                canvasSize: try CanvasSize(width: 7, height: 5)
            )

            try expect(result.format == .jpeg(preferredExtension: "jpeg"), "JPEG extension family should be preserved.")
            try expect(result.pixelWidth == 7, "JPEG output width should match the canvas.")
            try expect(result.pixelHeight == 5, "JPEG output height should match the canvas.")
            try expect(!result.data.isEmpty, "JPEG output should contain encoded data.")
        }
    }

    func sameSizeCanvasDoesNotAddBorder() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("same.png")
            try writeImage(width: 2, height: 2, pixels: Array(repeating: .green, count: 4), format: .png, to: sourceURL)

            let result = try ImageCenteringProcessor().processImage(
                at: sourceURL,
                canvasSize: try CanvasSize(width: 2, height: 2)
            )
            let decoded = try decodePixels(from: result.data)

            try expect(decoded.colorAt(x: 0, y: 0) == .green, "Same-size image should fill the canvas.")
            try expect(decoded.colorAt(x: 1, y: 1) == .green, "Same-size image should fill the canvas.")
        }
    }

    func largerImageIsScaledDownToFit() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("large.png")
            try writeImage(width: 6, height: 2, pixels: Array(repeating: .red, count: 12), format: .png, to: sourceURL)

            let result = try ImageCenteringProcessor().processImage(
                at: sourceURL,
                canvasSize: try CanvasSize(width: 3, height: 3)
            )
            let decoded = try decodePixels(from: result.data)

            try expect(result.pixelWidth == 3, "Output width should match the canvas.")
            try expect(result.pixelHeight == 3, "Output height should match the canvas.")
            try expect(decoded.colorAt(x: 1, y: 0).isClose(to: .white), "Scaled-down image should keep vertical margin.")
            try expect(decoded.colorAt(x: 1, y: 1).isClose(to: .red), "Larger image should scale down into the canvas.")
            try expect(decoded.colorAt(x: 1, y: 2).isClose(to: .white), "Scaled-down image should keep vertical margin.")
        }
    }

    func transparentPNGFlattensOverWhite() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("transparent.png")
            try writeImage(width: 1, height: 1, pixels: [.clear], format: .png, to: sourceURL)

            let result = try ImageCenteringProcessor().processImage(
                at: sourceURL,
                canvasSize: try CanvasSize(width: 1, height: 1)
            )
            let decoded = try decodePixels(from: result.data)

            try expect(decoded.colorAt(x: 0, y: 0) == .white, "Transparent source pixels should flatten over white.")
        }
    }

    func transparentBackgroundKeepsCanvasTransparent() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("small.png")
            try writeImage(width: 2, height: 2, pixels: Array(repeating: .red, count: 4), format: .png, to: sourceURL)

            let result = try ImageCenteringProcessor().processImage(
                at: sourceURL,
                canvasSize: try CanvasSize(width: 6, height: 6),
                background: .transparent
            )
            let decoded = try decodePixels(from: result.data)

            try expect(result.format == .png, "Transparent output should be PNG.")
            try expect(decoded.colorAt(x: 0, y: 0) == .clear, "Canvas margin should stay fully transparent.")
            try expect(decoded.colorAt(x: 5, y: 5) == .clear, "Canvas margin should stay fully transparent.")
            try expect(decoded.colorAt(x: 2, y: 2) == .red, "Image pixels should stay opaque on a transparent canvas.")
            try expect(decoded.colorAt(x: 3, y: 3) == .red, "Image pixels should stay opaque on a transparent canvas.")
        }
    }

    func transparentBackgroundExportsJPEGAsPNG() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("photo.jpg")
            try writeImage(width: 2, height: 2, pixels: Array(repeating: .blue, count: 4), format: .jpeg(preferredExtension: "jpg"), to: sourceURL)

            let result = try ImageCenteringProcessor().processImage(
                at: sourceURL,
                canvasSize: try CanvasSize(width: 4, height: 4),
                background: .transparent
            )
            let decoded = try decodePixels(from: result.data)

            try expect(result.format == .png, "JPEG input with transparent background should convert to PNG.")
            try expect(decoded.colorAt(x: 0, y: 0) == .clear, "Converted JPEG margin should be transparent.")
            try expect(decoded.colorAt(x: 2, y: 2).isClose(to: .blue), "Converted JPEG should keep its image pixels.")

            let folder = URL(fileURLWithPath: "/exports", isDirectory: true)
            let destination = ExportFileNamer.destinationURL(for: sourceURL, format: result.format, in: folder) { _ in false }
            try expect(destination.lastPathComponent == "photo.png", "Converted JPEG should export with a .png extension.")
        }
    }

    func unsupportedFileThrows() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("not-image.txt")
            try Data("nope".utf8).write(to: sourceURL)

            do {
                _ = try ImageCenteringProcessor().processImage(
                    at: sourceURL,
                    canvasSize: try CanvasSize(width: 10, height: 10)
                )
                throw TestFailure("Unsupported input should throw.")
            } catch ImageProcessingError.unsupportedFileType {
            }
        }
    }

    func differentSizedImagesAreProcessedIndependently() throws {
        try withTemporaryDirectory { directory in
            let wideURL = directory.appendingPathComponent("wide.png")
            let tallURL = directory.appendingPathComponent("tall.png")
            try writeImage(width: 12, height: 4, pixels: Array(repeating: .red, count: 48), format: .png, to: wideURL)
            try writeImage(width: 4, height: 12, pixels: Array(repeating: .blue, count: 48), format: .png, to: tallURL)

            let canvasSize = try CanvasSize(width: 6, height: 6)
            let processor = ImageCenteringProcessor()
            let wide = try processor.processImage(at: wideURL, canvasSize: canvasSize)
            let tall = try processor.processImage(at: tallURL, canvasSize: canvasSize)
            let decodedWide = try decodePixels(from: wide.data)
            let decodedTall = try decodePixels(from: tall.data)

            try expect(wide.pixelWidth == 6 && wide.pixelHeight == 6, "Wide image output should match the requested canvas.")
            try expect(tall.pixelWidth == 6 && tall.pixelHeight == 6, "Tall image output should match the requested canvas.")
            try expect(decodedWide.colorAt(x: 3, y: 1).isClose(to: .white), "Wide image should have independent vertical margins.")
            try expect(decodedWide.colorAt(x: 3, y: 3).isClose(to: .red), "Wide image should be processed from its own dimensions.")
            try expect(decodedTall.colorAt(x: 1, y: 3).isClose(to: .white), "Tall image should have independent horizontal margins.")
            try expect(decodedTall.colorAt(x: 3, y: 3).isClose(to: .blue), "Tall image should be processed from its own dimensions.")
        }
    }

    func exportFileNamerKeepsOriginalNamesAndIncrementsConflicts() throws {
        let folder = URL(fileURLWithPath: "/exports", isDirectory: true)
        let source = URL(fileURLWithPath: "/input/avatar.png")
        let occupied = Set([
            "/exports/avatar.png",
            "/exports/avatar 2.png"
        ])

        let destination = ExportFileNamer.destinationURL(for: source, format: .png, in: folder) {
            occupied.contains($0.path)
        }

        try expect(destination.path == "/exports/avatar 3.png", "Original names should be preserved and conflicts should increment.")
    }

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory)
    }

    private func writeImage(width: Int, height: Int, pixels: [TestColor], format: ImageFormat, to url: URL) throws {
        try expect(pixels.count == width * height, "Fixture pixel count must match dimensions.")
        var bytes = pixels.flatMap(\.rgba)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &bytes,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ),
              let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, format.utType.identifier as CFString, 1, nil) else {
            throw TestFailure("Could not create fixture image.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        try expect(CGImageDestinationFinalize(destination), "Fixture image should be written.")
    }

    private func decodePixels(from data: Data) throws -> DecodedPixels {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw TestFailure("Could not decode processed image.")
        }
        let width = image.width
        let height = image.height
        var bytes = Array(repeating: UInt8(0), count: width * height * 4)
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &bytes,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw TestFailure("Could not create decode context.")
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return DecodedPixels(width: width, height: height, bytes: bytes)
    }

    private func expect(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw TestFailure(message)
        }
    }
}

private struct DecodedPixels {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    func colorAt(x: Int, y: Int) -> TestColor {
        let index = (y * width + x) * 4
        return TestColor(
            red: bytes[index],
            green: bytes[index + 1],
            blue: bytes[index + 2],
            alpha: bytes[index + 3]
        )
    }
}

private struct TestColor: Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8

    var rgba: [UInt8] {
        [red, green, blue, alpha]
    }

    static let red = TestColor(red: 255, green: 0, blue: 0, alpha: 255)
    static let green = TestColor(red: 0, green: 255, blue: 0, alpha: 255)
    static let blue = TestColor(red: 0, green: 0, blue: 255, alpha: 255)
    static let white = TestColor(red: 255, green: 255, blue: 255, alpha: 255)
    static let clear = TestColor(red: 0, green: 0, blue: 0, alpha: 0)

    func isClose(to other: TestColor, tolerance: UInt8 = 6) -> Bool {
        abs(Int(red) - Int(other.red)) <= tolerance &&
            abs(Int(green) - Int(other.green)) <= tolerance &&
            abs(Int(blue) - Int(other.blue)) <= tolerance
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

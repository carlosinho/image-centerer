import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct CanvasSize: Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) throws {
        guard width > 0, height > 0 else {
            throw ImageProcessingError.invalidCanvasSize
        }
        self.width = width
        self.height = height
    }
}

public struct CanvasPadding: Equatable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int = 0, y: Int = 0) throws {
        guard x >= 0, y >= 0 else {
            throw ImageProcessingError.invalidPadding
        }
        self.x = x
        self.y = y
    }
}

public enum ImageFormat: Equatable, Sendable {
    case png
    case jpeg(preferredExtension: String)

    public var fileExtension: String {
        switch self {
        case .png:
            return "png"
        case .jpeg(let preferredExtension):
            return preferredExtension.lowercased() == "jpeg" ? "jpeg" : "jpg"
        }
    }

    public var utType: UTType {
        switch self {
        case .png:
            return .png
        case .jpeg:
            return .jpeg
        }
    }
}

public struct ProcessedImage: Sendable {
    public let data: Data
    public let format: ImageFormat
    public let pixelWidth: Int
    public let pixelHeight: Int
}

public struct PreviewImage: Sendable {
    public let cgImage: CGImage
    public let pixelWidth: Int
    public let pixelHeight: Int
}

public protocol ImageCenteringProcessing: Sendable {
    func processImage(at sourceURL: URL, canvasSize: CanvasSize, padding: CanvasPadding) throws -> ProcessedImage
}

public enum ImageProcessingError: LocalizedError {
    case unsupportedFileType
    case decodeFailed
    case encodeFailed
    case invalidCanvasSize
    case invalidPadding
    case cannotCreateContext
    case cannotReadImageMetadata

    public var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Only PNG and JPG images are supported."
        case .decodeFailed:
            return "The image could not be decoded."
        case .encodeFailed:
            return "The processed image could not be encoded."
        case .invalidCanvasSize:
            return "Canvas width and height must be positive whole numbers."
        case .invalidPadding:
            return "Padding must be zero or a positive whole number."
        case .cannotCreateContext:
            return "The output canvas could not be created."
        case .cannotReadImageMetadata:
            return "The image dimensions could not be read."
        }
    }
}

public struct ImageCenteringProcessor: ImageCenteringProcessing, Sendable {
    private let jpegQuality: CGFloat

    public init(jpegQuality: CGFloat = 0.95) {
        self.jpegQuality = jpegQuality
    }

    public func processImage(
        at sourceURL: URL,
        canvasSize: CanvasSize,
        padding: CanvasPadding = try! CanvasPadding()
    ) throws -> ProcessedImage {
        let format = try ImageFormat.detect(from: sourceURL)
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ImageProcessingError.decodeFailed
        }
        guard let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCache: true
        ] as CFDictionary) else {
            throw ImageProcessingError.decodeFailed
        }

        let rendered = try render(sourceImage, canvasSize: canvasSize, padding: padding)
        let data = try encode(rendered, format: format)
        return ProcessedImage(
            data: data,
            format: format,
            pixelWidth: canvasSize.width,
            pixelHeight: canvasSize.height
        )
    }

    public func previewImage(
        at sourceURL: URL,
        canvasSize: CanvasSize,
        padding: CanvasPadding = try! CanvasPadding(),
        maxPixelDimension: Int = 1400
    ) throws -> PreviewImage {
        guard maxPixelDimension > 0 else {
            throw ImageProcessingError.invalidCanvasSize
        }
        _ = try ImageFormat.detect(from: sourceURL)
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw ImageProcessingError.decodeFailed
        }

        let previewCanvasSize = canvasSize.scaledToFit(maxPixelDimension: maxPixelDimension)
        let previewPadding = padding.scaled(from: canvasSize, to: previewCanvasSize)
        let targetSourceDimension = sourceTargetDimension(
            from: source,
            canvasSize: previewCanvasSize,
            padding: previewPadding
        ) ?? max(previewCanvasSize.width, previewCanvasSize.height)

        guard let sourceImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: targetSourceDimension,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary) else {
            throw ImageProcessingError.decodeFailed
        }

        let rendered = try render(sourceImage, canvasSize: previewCanvasSize, padding: previewPadding)
        return PreviewImage(
            cgImage: rendered,
            pixelWidth: previewCanvasSize.width,
            pixelHeight: previewCanvasSize.height
        )
    }

    public func imageInfo(at sourceURL: URL) throws -> (format: ImageFormat, width: Int, height: Int) {
        let format = try ImageFormat.detect(from: sourceURL)
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw ImageProcessingError.cannotReadImageMetadata
        }
        return (format, width, height)
    }

    private func render(_ sourceImage: CGImage, canvasSize: CanvasSize, padding: CanvasPadding) throws -> CGImage {
        let width = canvasSize.width
        let height = canvasSize.height
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw ImageProcessingError.cannotCreateContext
        }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high

        let drawRect = Placement(
            imageWidth: CGFloat(sourceImage.width),
            imageHeight: CGFloat(sourceImage.height),
            canvasWidth: CGFloat(width),
            canvasHeight: CGFloat(height),
            paddingX: CGFloat(padding.x),
            paddingY: CGFloat(padding.y)
        ).imageDrawRect
        context.draw(sourceImage, in: drawRect)

        guard let output = context.makeImage() else {
            throw ImageProcessingError.cannotCreateContext
        }
        return output
    }

    private func encode(_ image: CGImage, format: ImageFormat) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, format.utType.identifier as CFString, 1, nil) else {
            throw ImageProcessingError.encodeFailed
        }

        var options: [CFString: Any] = [:]
        if case .jpeg = format {
            options[kCGImageDestinationLossyCompressionQuality] = jpegQuality
        }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageProcessingError.encodeFailed
        }
        return data as Data
    }
}

private extension CanvasSize {
    func scaledToFit(maxPixelDimension: Int) -> CanvasSize {
        let longestSide = max(width, height)
        guard longestSide > maxPixelDimension else {
            return self
        }
        let scale = CGFloat(maxPixelDimension) / CGFloat(longestSide)
        return try! CanvasSize(
            width: max(1, Int((CGFloat(width) * scale).rounded())),
            height: max(1, Int((CGFloat(height) * scale).rounded()))
        )
    }
}

private extension CanvasPadding {
    func scaled(from sourceSize: CanvasSize, to targetSize: CanvasSize) -> CanvasPadding {
        let scaleX = CGFloat(targetSize.width) / CGFloat(sourceSize.width)
        let scaleY = CGFloat(targetSize.height) / CGFloat(sourceSize.height)
        return try! CanvasPadding(
            x: max(0, Int((CGFloat(x) * scaleX).rounded())),
            y: max(0, Int((CGFloat(y) * scaleY).rounded()))
        )
    }
}

private func sourceTargetDimension(
    from source: CGImageSource,
    canvasSize: CanvasSize,
    padding: CanvasPadding
) -> Int? {
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let imageWidth = properties[kCGImagePropertyPixelWidth] as? Int,
          let imageHeight = properties[kCGImagePropertyPixelHeight] as? Int else {
        return nil
    }

    let placement = Placement(
        imageWidth: CGFloat(imageWidth),
        imageHeight: CGFloat(imageHeight),
        canvasWidth: CGFloat(canvasSize.width),
        canvasHeight: CGFloat(canvasSize.height),
        paddingX: CGFloat(padding.x),
        paddingY: CGFloat(padding.y)
    )
    return max(1, Int(max(placement.imageDrawRect.width, placement.imageDrawRect.height).rounded(.up)))
}

private struct Placement {
    let imageDrawRect: CGRect

    init(
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        canvasWidth: CGFloat,
        canvasHeight: CGFloat,
        paddingX: CGFloat,
        paddingY: CGFloat
    ) {
        let paddedWidth = imageWidth + paddingX * 2
        let paddedHeight = imageHeight + paddingY * 2
        let scale = min(1, canvasWidth / paddedWidth, canvasHeight / paddedHeight)
        let scaledPaddedWidth = paddedWidth * scale
        let scaledPaddedHeight = paddedHeight * scale
        let paddedOriginX = (canvasWidth - scaledPaddedWidth) / 2
        let paddedOriginY = (canvasHeight - scaledPaddedHeight) / 2

        imageDrawRect = CGRect(
            x: paddedOriginX + paddingX * scale,
            y: paddedOriginY + paddingY * scale,
            width: imageWidth * scale,
            height: imageHeight * scale
        )
    }
}

public extension ImageFormat {
    static func detect(from url: URL) throws -> ImageFormat {
        switch url.pathExtension.lowercased() {
        case "png":
            return .png
        case "jpg":
            return .jpeg(preferredExtension: "jpg")
        case "jpeg":
            return .jpeg(preferredExtension: "jpeg")
        default:
            throw ImageProcessingError.unsupportedFileType
        }
    }
}

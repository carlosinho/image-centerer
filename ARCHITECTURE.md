# Architecture

Image Centerer is a local-only macOS image processing app. The implementation is intentionally small: a SwiftUI shell owns user interaction, and a separate core target owns deterministic image processing and export naming.

There is no server, database, authentication, background daemon, network integration, plugin system, or persistent app state.

## Targets

`Package.swift` defines three targets:

- `ImageCentererCore`: reusable image-processing and filename logic.
- `ImageCenterer`: SwiftUI macOS executable app.
- `ImageCentererCoreTests`: Swift Testing suite covering image behavior and export naming.

The app target depends on `ImageCentererCore`. The core target does not depend on SwiftUI or AppKit.

## Design Philosophy

The core rule is that output should be predictable from five inputs:

- source file URL
- output canvas width/height
- X/Y padding
- canvas background (white or transparent)
- source file format

The UI is thin and stateful. The processor is stateless and does not remember previous jobs. This keeps batch behavior simple: every selected image is processed independently through the same processor call.

The app favors local platform APIs over dependencies:

- `NSOpenPanel` for file/folder selection
- `CGImageSource` for decoding and metadata
- `CGContext` for canvas rendering
- `CGImageDestination` for PNG/JPEG output
- `UTType.png` and `UTType.jpeg` for output encoding identifiers

## Core Invariants

Implemented invariants in `ImageCenteringProcessor`:

- Canvas width must be greater than zero.
- Canvas height must be greater than zero.
- Padding X and Y must be zero or positive.
- Supported extensions are exactly `png`, `jpg`, and `jpeg`, case-insensitive through `lowercased()`.
- Output dimensions always equal the requested `CanvasSize`.
- Output background is white or fully transparent, per the requested `CanvasBackground`.
- With a transparent background, output format is always PNG regardless of input format, because JPEG cannot store alpha.
- Images are never scaled up.
- Images are scaled down if the image plus padding would exceed the canvas.
- Padding participates in fitting but is not drawn as a separate object; it appears as background canvas area around the drawn image.
- With a white background, PNG alpha is flattened by drawing onto the white canvas; with a transparent background, source alpha is preserved.
- JPEG output uses lossy compression quality `0.95`.
- The first frame/image from `CGImageSource` is used.
- Metadata preservation is not implemented.

The exact fit scale is:

```swift
scale = min(1, canvasWidth / paddedWidth, canvasHeight / paddedHeight)
```

where:

```text
paddedWidth  = sourceImage.width  + paddingX * 2
paddedHeight = sourceImage.height + paddingY * 2
```

The drawn image rect is then placed inside the scaled padded rectangle:

```text
paddedOriginX = (canvasWidth - paddedWidth * scale) / 2
paddedOriginY = (canvasHeight - paddedHeight * scale) / 2

imageX = paddedOriginX + paddingX * scale
imageY = paddedOriginY + paddingY * scale
imageW = sourceWidth * scale
imageH = sourceHeight * scale
```

## Main Data Flow

### Image Selection

`ContentView` calls `FileSelection.selectInputImages()`.

`FileSelection` creates an `NSOpenPanel` configured with:

- `allowedContentTypes = [.png, .jpeg]`
- multiple selection enabled
- files enabled
- directories disabled
- alias resolution enabled

For each selected URL, `ContentView.addImages(_:)`:

1. Skips the URL if it is already present in `jobs`.
2. Calls `ImageCenteringProcessor.imageInfo(at:)`.
3. Creates an `ImageJob` with filename, format, pixel width, pixel height, and `.ready` status.
4. Initializes canvas width/height from the first successfully loaded image only.
5. If metadata loading fails, creates a failed job when possible.

Duplicate detection is by exact `URL` equality in the current in-memory job list.

### Preview

Preview is recomputed in `ContentView.refreshPreview()` whenever any of these change:

- selected job
- canvas width
- canvas height
- padding X
- padding Y
- background selection

If the canvas or padding values are invalid, preview is cleared. If processing succeeds, the returned preview `CGImage` is wrapped in `NSImage` and displayed with SwiftUI `Image(nsImage:)`.

Preview uses `ImageCenteringProcessor.previewImage(...)`, not the export-grade `processImage(...)` path. This keeps live preview responsive while typing:

- each new preview request cancels the previous preview task
- preview work is lightly debounced
- processing runs in a detached user-initiated task
- the preview canvas is capped to a maximum pixel dimension
- ImageIO creates a thumbnail-sized source image when possible
- the preview skips final PNG/JPEG encoding

Preview and export still share the same placement math and canvas rendering behavior. Export remains the source of truth for final output dimensions and encoding.

When the transparent background is selected, the preview draws a checkerboard pattern behind the image so transparent areas are visible.

### Export

`ContentView.exportImages()`:

1. Validates current canvas and padding.
2. Opens a folder picker through `FileSelection.selectExportFolder()`.
3. Starts an export `Task`.
4. Iterates over `jobs.indices`.
5. Updates progress text before each item.
6. Calls `processor.processImage(...)` for each job independently in a detached user-initiated task.
7. Resolves the destination URL with `ExportFileNamer.destinationURL(...)`.
8. Writes encoded data atomically.
9. Updates the job status to `.exported(destination)` or `.failed(error.localizedDescription)`.
10. Shows a summary string: `Exported N. Failed M.` or `Export canceled. Exported N. Failed M.`

The batch continues after individual file failures. Canceling export stops the loop before starting another item; it does not delete files that were already written.

## Models And State

There is no persistence layer and no database.

Runtime state lives in SwiftUI `@State` properties in `ContentView`:

- `jobs: [ImageJob]`
- `selectedJobID: ImageJob.ID?`
- `canvasWidth: String`
- `canvasHeight: String`
- `paddingX: String`
- `paddingY: String`
- `isTransparentBackground: Bool`
- `didInitializeCanvas: Bool`
- `previewImage: NSImage?`
- `isExporting: Bool`
- `summaryText: String`
- `previewTask: Task<Void, Never>?`
- `exportTask: Task<Void, Never>?`
- `exportProgressText: String`

`ImageJob` exists only for UI bookkeeping:

- `id`: stable SwiftUI list identity
- `sourceURL`: input file
- `fileName`: display name
- `format`: detected `ImageFormat`
- `pixelWidth` / `pixelHeight`: metadata for display
- `status`: ready/exported/failed

`ExportSummary` exists in code but is not currently used by the UI.

## State Transitions

`ImageJobStatus` has three states:

```text
ready
exported(URL)
failed(String)
```

Current transitions:

- new valid input -> `ready`
- metadata/read failure during add -> `failed(message)`
- export success -> `exported(destinationURL)`
- export failure -> `failed(message)`

There is no retry state. A failed job can be processed again if the user clicks export again; the export loop still iterates all jobs.

## Format And Naming Rules

`ImageFormat.detect(from:)` uses the source URL extension:

- `png` -> `.png`
- `jpg` -> `.jpeg(preferredExtension: "jpg")`
- `jpeg` -> `.jpeg(preferredExtension: "jpeg")`

The output extension comes from the detected format:

- PNG stays `.png`
- JPG stays `.jpg`
- JPEG stays `.jpeg`

Exception: with a transparent background, the output format is forced to PNG, so `.jpg` and `.jpeg` inputs export as `.png`.

`ExportFileNamer.destinationURL(...)` preserves the original basename:

```text
/input/avatar.png + /exports -> /exports/avatar.png
```

Conflict resolution appends a space and counter before the extension:

```text
avatar.png
avatar 2.png
avatar 3.png
```

The implementation accepts a `fileExists` closure, which allows tests to verify naming without touching real files.

## Packaging Architecture

The project is a Swift Package, not an Xcode app project. `scripts/package-app.sh` creates the `.app` bundle manually.

The app version comes from the script's first argument when given, otherwise from the `VERSION` file at the repository root. `VERSION` is the source of truth; git tags (`v0.1.3`) are expected to match it.

The script:

1. Runs `swift build -c release --product ImageCenterer`.
2. Creates `dist/Image Centerer.app`.
3. Copies `.build/release/ImageCenterer` to `Contents/MacOS/Image Centerer`.
4. Writes `Contents/Info.plist`.
5. Converts `app-icon.png` to an `.icns` file if the PNG exists.
6. Writes `Contents/Resources/ImageCenterer.icns`.
7. Applies ad-hoc signing with `codesign --force --deep --sign -` when `codesign` is available.

The generated `dist/` directory is ignored by git.

Distribution is build-it-yourself: no binaries are published. Users clone the repository and run the packaging script locally. An app compiled on the user's own machine never receives the `com.apple.quarantine` attribute, so Gatekeeper does not block it and no signing or notarization is needed.

GitHub Actions (`.github/workflows/ci.yml`) runs `swift build`, the test suite, and the packaging script on every push and pull request to verify the source builds cleanly on a machine other than the author's.

## API Architecture

There are no HTTP routes, API endpoints, webhooks, queues, or external service integrations.

The closest thing to an internal API is the core target:

```swift
public struct CanvasSize
public struct CanvasPadding
public enum CanvasBackground
public enum ImageFormat
public struct ProcessedImage
public struct PreviewImage
public protocol ImageCenteringProcessing
public struct ImageCenteringProcessor
public enum ExportFileNamer
```

The main public processing call is:

```swift
processImage(at:canvasSize:padding:background:) throws -> ProcessedImage
```

The preview processing call is:

```swift
previewImage(at:canvasSize:padding:background:maxPixelDimension:) throws -> PreviewImage
```

## Failure Handling

Core errors are represented by `ImageProcessingError`:

- `unsupportedFileType`
- `decodeFailed`
- `encodeFailed`
- `invalidCanvasSize`
- `invalidPadding`
- `cannotCreateContext`
- `cannotReadImageMetadata`

The UI converts thrown errors to `localizedDescription` and stores them in `ImageJobStatus.failed`.

Batch export is best-effort: one failed image does not stop later images from being processed.

Atomic writes are used for exported image data:

```swift
try processed.data.write(to: destination, options: .atomic)
```

## Edge Cases And Intentional Exceptions

- The app does not upscale small images.
- The app does not crop as a primary behavior anymore; oversize images are scaled down to fit.
- If padding is so large that the padded image exceeds the canvas, the whole padded rectangle is scaled down.
- If `app-icon.png` is missing, packaging still creates the app without a custom icon.
- The UI initializes canvas dimensions from the first successfully loaded image and does not later overwrite user edits when more images are added.
- File type support is extension-based before decoding. A file with an unsupported extension fails even if its bytes contain image data.
- Multi-frame formats are not handled as animations; ImageIO loads the first image at index `0`.
- EXIF orientation normalization is not implemented explicitly.
- Metadata is not copied to output files.
- The UI does not sandbox or request persistent security-scoped bookmarks; it processes files selected during the current session.

## Security Considerations

The app is local-only and does not transmit images.

Input files are decoded with system ImageIO APIs. Malformed files can fail decode and are marked failed in the UI.

The package script applies ad-hoc signing only. It does not provide Developer ID signing or notarization. Because the app is always built locally rather than downloaded, Gatekeeper quarantine does not apply and the app opens normally.

The app writes only to the export folder selected by the user during the export flow.

## Performance Characteristics

Processing is currently synchronous on the main UI path:

- preview processing runs in response to UI state changes
- export loops over jobs on the main actor/UI interaction path

This is acceptable for small batches and moderate image sizes, but large images or large batches can make the UI feel blocked. There is no background queue, cancellation, streaming pipeline, or progress per file beyond final job status updates.

Memory usage is proportional to the decoded source image plus the rendered output canvas and encoded data. Very large canvas sizes will allocate large bitmap contexts.

## Testing And Maintenance Notes

The behavior coverage lives in `Tests/ImageCentererCoreTests`, a Swift Testing suite run through `swift test`.

Run it with:

```sh
./scripts/test.sh
```

The script wraps `swift test`. On machines with only the Apple Command Line Tools installed (no Xcode), Swift Testing's framework is not on the default compiler search path and the `_Testing_Foundation` cross-import overlay ships without Swift module interfaces, so the script passes the framework paths explicitly and disables cross-import overlays. With a full Xcode installation, the script falls through to plain `swift test`.

The suite creates temporary fixture images and checks actual rendered pixels after processing. It covers the important image rules and export naming behavior.

Maintenance-sensitive areas:

- `Placement` math in `ImageCenteringProcessor.swift`
- format detection and output extension preservation
- `ExportFileNamer` conflict behavior
- packaging script icon generation and `Info.plist` keys
- Swift 6 actor isolation around AppKit panels

## Existing Limitations

These are current facts, not planned work:

- macOS only.
- No CLI for processing images directly.
- No drag-and-drop input.
- No user preferences persistence.
- No custom output naming pattern.
- No overwrite option.
- No concurrent export processing.
- No prebuilt binary distribution; the app is built from source.
- No explicit EXIF orientation handling.
- No metadata preservation.

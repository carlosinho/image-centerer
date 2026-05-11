<h1 align="center">Image Centerer</h1>

<table>
  <tr>
    <td width="240" align="center" valign="top">
      <img src="app-icon.png" alt="Image Centerer logo" width="220" />
    </td>
    <td valign="middle">
      <strong>Image Centerer</strong> is a local macOS app for placing PNG and JPG images onto a fixed-size white canvas. It is built for batch image cleanup: choose images, choose the final canvas size, optionally add padding around the image, preview the result, and export processed files.
      <br /><br />
      The app does not upload images, call external services, or store a library. All processing happens locally on the selected files.
    </td>
  </tr>
</table>

<p align="center">
  <img src="image-centerer-scr.png" alt="Image Centerer app screenshot" width="900" />
</p>

## What It Does

For each selected image, Image Centerer creates a new output image with the requested pixel dimensions.

The processing rules are:

- Output canvas is filled with solid white.
- Supported inputs are `.png`, `.jpg`, and `.jpeg`.
- Output format follows the input format family.
- The original filename is preserved on export.
- If the destination filename already exists, the app writes `name 2.ext`, `name 3.ext`, and so on.
- Each input image is processed independently, so mixed source dimensions are valid in the same batch.
- The image is centered on the canvas.
- Padding X/Y is treated as extra white space around the image before fitting.
- Images are scaled down when the padded image would exceed the canvas.
- Images are never scaled up.
- Transparent PNG pixels are flattened against the white canvas.

Example export names:

```text
avatar.png   -> avatar.png
photo.jpeg   -> photo.jpeg
image.jpg    -> image.jpg

avatar.png already exists:
avatar.png   -> avatar 2.png
```

## Main User Flow

1. Open the app.
2. Click **Add Images** and select one or more PNG/JPG files.
3. The canvas width and height are initialized from the first successfully loaded image.
4. Edit canvas width/height if needed.
5. Optionally set X and Y padding.
6. Select an image in the sidebar to preview its processed result.
7. Click **Export**.
8. Choose an output folder.
9. The app processes every selected image and shows exported/failed counts.

The app currently uses standard file picker dialogs. It does not implement drag-and-drop.

## Tech Stack

- Swift 6.2 package
- macOS 15 minimum target
- SwiftUI for the app UI
- AppKit `NSOpenPanel` for input and export folder selection
- CoreGraphics and ImageIO for image decoding, rendering, and encoding
- UniformTypeIdentifiers for PNG/JPEG format identifiers
- Shell packaging script using `swift build`, `sips`, `iconutil`, `codesign`, and `ditto`

There are no third-party dependencies.

## Project Structure

```text
Package.swift
Sources/
  ImageCenterer/
    ContentView.swift          SwiftUI UI and export workflow
    FileSelection.swift        macOS open panels
    ImageCentererApp.swift     app entry point and activation policy
    ImageJob.swift             UI job/status model
  ImageCentererCore/
    ImageCenteringProcessor.swift  image loading, fitting, rendering, encoding
    ExportFileNamer.swift          export destination naming
  ImageCentererTestRunner/
    main.swift                behavior test runner for image processing
Tests/
  ImageCentererCoreTests/
    PackageTestPlaceholder.swift   placeholder SwiftPM test target
scripts/
  package-app.sh              builds a local .app bundle and release zip
app-icon.png                  source image used for the packaged app icon
```

Generated files are written under `dist/` and `.build/`; both are ignored by git.

## Requirements

- macOS 15 or newer
- Swift 6.2 or newer
- Command-line tools that include `swift`, `sips`, `iconutil`, `codesign`, and `ditto`

No environment variables are required.

## Run From Source

```sh
swift run ImageCenterer
```

The app explicitly sets itself as a regular foreground macOS app on launch, which is needed because it is run as a SwiftPM executable rather than from a normal `.app` bundle.

## Build And Verify

Build all targets:

```sh
swift build
```

Run SwiftPM’s test command:

```sh
swift test
```

Run the image behavior checks:

```sh
swift run ImageCentererTestRunner
```

`ImageCentererTestRunner` is the meaningful test suite for this project. It generates temporary fixture images and verifies:

- smaller images are not scaled up
- larger images are scaled down to fit
- mixed width/height overflow is fitted correctly
- padding is applied before fitting
- JPEG output stays JPEG
- transparent PNGs flatten over white
- unsupported extensions fail
- differently sized images are processed independently
- export naming preserves original names and increments conflicts

## License

Image Centerer is available under the MIT License. See `LICENSE`.
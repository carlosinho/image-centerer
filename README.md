# Image Centerer

Image Centerer is a small macOS app for batch-processing local PNG and JPG images onto a fixed white canvas.

It lets you:

- Select one or more PNG/JPG images.
- Set an output canvas width and height in pixels.
- Add X/Y padding around each image before fitting.
- Center each image on a white canvas.
- Scale images down when needed so they fit the canvas.
- Never scale images up.
- Export each result using the same filename and format family as the original.

## Download And Run

Download the latest `Image-Centerer-macOS-*.zip` from GitHub Releases, unzip it, and open `Image Centerer.app`.

If macOS blocks the app because it was downloaded from the internet, right-click the app and choose **Open**. This project does not use Developer ID signing or notarization.

## Build A Local App

Requirements:

- macOS 15 or newer
- Swift 6.2 or newer

Create a local app bundle and release zip:

```sh
./scripts/package-app.sh
```

If `app-icon.png` exists in the repository root, the package script automatically converts it into a macOS `.icns` icon and embeds it in the app bundle.

The script writes:

```text
dist/Image Centerer.app
dist/Image-Centerer-macOS-0.1.0.zip
```

You can open the app directly:

```sh
open "dist/Image Centerer.app"
```

Or move it into `/Applications`.

To set a release version in the generated zip and app metadata:

```sh
./scripts/package-app.sh 1.0.0
```

## Run From Source

```sh
swift run ImageCenterer
```

## Verify

```sh
swift build
swift test
swift run ImageCentererTestRunner
```

`ImageCentererTestRunner` contains the behavior checks for image fitting, padding, format preservation, independent batch processing, and export naming.

## Export Behavior

Output files keep the original filename:

```text
avatar.png -> avatar.png
photo.jpeg -> photo.jpeg
image.jpg -> image.jpg
```

If a file already exists in the export folder, the app increments the name:

```text
avatar.png
avatar 2.png
avatar 3.png
```

## License

MIT

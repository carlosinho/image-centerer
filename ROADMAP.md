# Development

## Status

Stable at v0.1.5 — all shipped features work and are covered by tests.

## Roadmap

### v0.1.0 — Initial release

- [x] Swift Package with split targets: `ImageCenterer` (SwiftUI app) and `ImageCentererCore` (stateless processing logic, no AppKit/SwiftUI dependency)
- [x] PNG/JPG/JPEG input selection via `NSOpenPanel` (multi-select, alias resolution)
- [x] Centering onto a fixed-size white canvas — `scale = min(1, w/paddedW, h/paddedH)`, see `Placement` math in `ImageCenteringProcessor.swift`
- [x] Padding X/Y as extra background space, applied before fitting
- [x] Never upscale; scale down only when the padded image exceeds the canvas
- [x] Live preview of the selected image's processed result
- [x] Batch export — each image processed independently, mixed dimensions allowed
- [x] Original filename preserved on export; conflicts become `name 2.ext`, `name 3.ext` (`ExportFileNamer`, testable via `fileExists` closure)
- [x] Output format follows the input format family (`.png`/`.jpg`/`.jpeg` preserved)
- [x] Canvas size auto-initialized from the first successfully loaded image
- [x] `scripts/package-app.sh` — builds `dist/Image Centerer.app` manually (Info.plist, `sips`/`iconutil` icon, ad-hoc `codesign`); no Xcode project

### v0.1.1–v0.1.2 — Logic cleanup, export cancellation

- [x] Async export in a `Task` so the window stays responsive; Cancel button stops the batch after the current in-flight item (already-written files are kept)
- [x] Preview responsiveness: debounced (~75 ms), stale preview tasks canceled, capped preview bitmap via `previewImage(...)` — skips final encoding; export remains the source of truth
- [x] Batch is best-effort: one failed image doesn't stop the rest; summary shows `Exported N. Failed M.`

### v0.1.3 — Transparent background support

- [x] Transp. toggle: keep the canvas transparent instead of flattening to white
- [x] Checkerboard pattern behind transparent areas in the preview
- [x] Transparent mode forces PNG output for all inputs (JPEG can't store alpha); white mode flattens PNG alpha against white

### v0.1.4 — Repo and test improvements

- [x] Swift Testing suite in `Tests/ImageCentererCoreTests` — verifies rendered pixels, fitting rules, format rules, export naming
- [x] `scripts/test.sh` — wraps `swift test` with the extra flags needed on Command Line Tools-only machines (no Xcode)
- [x] GitHub Actions CI (`.github/workflows/ci.yml`) — build, test, and packaging check on every push/PR

### v0.1.5 — Source-only distribution and update check

- [x] No binary zips on releases — users build from source with `package-app.sh`; local builds skip Gatekeeper quarantine entirely (see `LOCAL_RELEASE_NOTES.md` for the release flow)
- [x] Check for Updates: manual menu item (always reports a result) + silent weekly check on launch (alerts only when a newer release exists)
- [x] Version logic in core (`AppVersion` parsing/comparison, `UpdateCheckSchedule`) with tests; single HTTPS GET to the GitHub latest-release API; last-check date in `UserDefaults`
- [x] `VERSION` file as source of truth for the app version, written into the bundle by `package-app.sh`; `swift run` builds have no version and skip the scheduled check

### v0.2.0 - Branding and UI improvement
- [x] Change branding to Owlign
  - App name should be: Owlign
  - App title in the main window should say: Owlign Image Centerer
  - The readme should label the app from now: Owlign Image Centerer
- [ ] Drag-and-drop file input (the app only uses standard file picker dialogs now)

### Backlog / Future

- CLI for processing images directly
- Overwrite option on export
- Custom output naming pattern
- Concurrent export processing
- Explicit EXIF orientation handling
- Metadata preservation
- User preferences persistence beyond the update check's last-check date
- Way to disable the weekly update check from the UI
- Prebuilt binary distribution (currently build-from-source only)
- Platforms beyond macOS

## Known Issues / Tech Debt

- `ExportSummary` exists in core but is unused by the UI (noted in ARCHITECTURE.md).
- File type support is extension-based before decoding — a valid image with the wrong extension fails.
- Duplicate input detection is exact `URL` equality only.
- No explicit EXIF orientation normalization; no metadata copied to output; first frame only for multi-frame formats. All intentional for now (documented in "Edge Cases And Intentional Exceptions").

## Decisions Pending

- None recorded. (Nothing open in README.md, ARCHITECTURE.md, or LOCAL_RELEASE_NOTES.md.)

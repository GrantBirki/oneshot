# Overlay Rendering Performance Notes

## Why this exists

Selection and window capture overlays are expected to feel as responsive as the native macOS screenshot tool. The original implementation relied on full-screen draw calls on every mouse move, which could feel laggy on large or multi-display setups. This document captures the current rendering approach and the performance-focused changes that made the overlay smooth.

## Summary of the approach

- Replace `draw(_:)`-based rendering with layer-backed rendering using `CAShapeLayer`.
- Update only layer paths and frames on interaction instead of triggering full view redraws.
- Dim only the active selection/highlight area so the rest of the screen remains unchanged.
- Disable implicit animations for updates to keep feedback immediate.

## Current overlay architecture

### Selection overlay

File: `Sources/Capture/SelectionOverlay.swift`

- `SelectionOverlayView` owns four layers:
  - `dimmingLayer` to render the dimmed selection interior.
  - `borderLayer` to render the selection outline.
  - `metricsBackgroundLayer` for the size bubble background.
  - `metricsTextLayer` for the size text.
- Updates flow:
  - Mouse events update `SelectionOverlayState`.
  - `SelectionOverlayController` calls `updateOverlay()` on each view.
  - `updateOverlay()` updates layer frames, paths, and text.
- Rendering details:
  - Dimming is applied only to the selection rectangle.
  - `CATransaction.setDisableActions(true)` avoids implicit animations.
  - Layer `contentsScale` is set from the window backing scale factor to keep text and lines crisp.

### Window overlay

File: `Sources/Capture/WindowCaptureOverlay.swift`

- `WindowCaptureOverlayView` owns two layers:
  - `dimmingLayer` for the dimmed highlighted window interior.
  - `highlightLayer` for the window outline.
- Updates flow:
  - Mouse movement updates the highlighted window.
  - `updateLayers()` updates paths and visibility.
- Rendering details mirror the selection overlay: inner dimming path and disabled implicit animations.

### Shared path builder

File: `Sources/Capture/OverlayPathBuilder.swift`

- `OverlayPathBuilder.innerDimmingPath(for:)` builds a path for the active selection/highlight rect.

## Performance rationale

- `draw(_:)` invalidations forced full-screen rasterization and blending on every mouse move.
- Layer path updates shift work to the compositor and reduce CPU overhead.
- Avoiding implicit animations prevents laggy visual drift during fast drags.

## Tests

File: `Tests/OverlayPathBuilderTests.swift`

- Validates that the dimming path exists for a rect and is absent when no rect is provided.

## Future ideas (if performance regresses)

- Throttle overlay updates to the display refresh rate with a display link.
- Cache selection geometry updates when the mouse hasn't moved beyond a pixel threshold.

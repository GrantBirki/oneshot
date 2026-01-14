# v0 Specification

This document outlines the specifications for version 0 (v0) of the OpenShot macOS screenshot utility.

## Goals

- Keep the app simple, reliable, and installable via Homebrew (open source, unsigned is acceptable for MVP).
- Minimum macOS: 14 (Sonoma).
- Build as a macOS app bundle, unsigned for MVP; optional codesign + notary supported via env flags.
- Distribute via Homebrew cask.
- Users will need to approve the app on first run (Gatekeeper).
- Provide an extemely simple and easy to use screenshot utility that works in a similar way to the built-in macOS screenshot tool.
- Extend the MacOS screenshot tool with additional features such as:
  - Disabling the post-capture overlay image preview/hover tile.
  - Custom save locations including the ability to automatically save to clipboard, desktop, documents, or a user specified folder.
  - Custom file naming conventions.
  - The ability to fully disable the floating thumbnail preview and just default to instantly saving the screenshot or copying to clipboard.
  - Makes use of macOS native screenshot APIs where possible to ensure compatibility and reliability.
  - The ability to "click and drag" the resulting screenshot that hovers in the bottom right corner to drag and drop it into other applications.
  - Support for keyboard shortcuts similar to macOS's built-in screenshot tool. Allow the user to customize these shortcuts so they can choose their own preferred key combinations. This is a global setting that applies system-wide for taking screenshots.
  - It should be lightweight and have minimal impact on system resources.
  - It should have a clean and intuitive user interface that is easy to navigate.
  - It should be stable and reliable, with minimal bugs or crashes.
  - It should be secure and respect user privacy.
  - It should have the ability to do click-and-drag after pressing the screenshot shortcut to immediately select the area to capture.
  - It should support capturing screenshots of specific windows, full screen, or selected areas.
  - By default, it should save screenshots as a maximum quality PNG file to preserve image quality.
  - By default, filenames of screenshots should be named in a filesystem-safe RFC3339-like format (see Filename Format).

## App Surface

- Menu-bar only app (no Dock icon).
- Preferences/settings window (full window, not a popover).
- User setting to enable/disable launch at login.
- Auto-launch implementation: SMAppService.

## Capture & Hotkeys

- Capture modes: drag-to-select area (default), full screen, window capture.
- Default global hotkeys (no external deps):
  - `ctrl+p` => drag selection capture. This is the default and golden path for capturing screenshots. At least for me personally!
  - `ctrl+shift+p` => full screen capture. I don't use this as much but I'm sure others do so we need it as a feature.
- Default hotkey for window capture: TBD.
- Hotkeys should be user-configurable in preferences.
- No capture delay for v0 (always instant).
- Use a custom selection overlay with CG APIs / ScreenCaptureKit for capture.

## Floating Preview

- Show a floating preview tile after capture (supports drag/drop into other apps and click-to-open).
- Preview timeout is configurable; include a "never timeout" mode that keeps the tile until the user closes it.
- Preview actions:
  - Upper-left "X" closes the preview and immediately saves to disk (ends any delay early).
  - Upper-right red trash icon cancels the delayed save and deletes the pending capture.

## Output & Storage

- Default output behavior:
  - Immediately copy the screenshot to clipboard.
  - After 7 seconds, save a PNG to `~/Downloads`.
- If the delayed save timer completes, save to disk.
- If the user clicks the trash icon before the delay completes, cancel the save.
- Output format: PNG only for v0.
- Save location should be configurable in preferences (desktop, downloads, documents, custom folder).

## Filename Format

- Default filename format: `screenshot_<timestamp>.png`.
- Timestamp is RFC3339-like but filesystem safe:
  - Replace `:` and `-` characters in date/time with `_`.
  - Replace timezone sign with `tz_plus` or `tz_minus`.
  - Example: `screenshot_2026_01_12T13_43_15_tz_minus_08_00.png`.

## Tooling & Distribution

- Use XcodeGen (`project.yml`) to generate the Xcode project.
- Use SwiftLint + SwiftFormat for linting/formatting.
- "Scripts to rule them all" via `script/` (bootstrap/build/test/lint).
- Bootstrap should be idempotent, fast, and cache where possible.
- Package app as unsigned zip for Homebrew cask; support optional codesign + notary via env flags.

## Non-Goals (MVP)

- No custom installer; Homebrew cask only.
- No capture delays (instant only for v0).

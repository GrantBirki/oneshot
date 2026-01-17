# OneShot Usage

This guide explains how to use OneShot day to day. For every setting and toggle, see
[`docs/settings.md`](settings.md).

## Quick Start

1) Install via Homebrew: `brew install --cask grantbirki/tap/oneshot`
2) Launch OneShot from Applications (it runs as a menu bar app).
3) When prompted, grant Screen Recording permission in System Settings.

## Permissions

OneShot needs Screen Recording permission to capture screenshots:

- System Settings → Privacy & Security → Screen Recording (or Screen & System Audio Recording)
- Toggle OneShot on, then quit and relaunch the app

## Capture Modes

Use the menu bar icon (camera) or hotkeys to capture:

- Selection: click and drag to choose an area; press Esc to cancel
- Window: click a window to capture it; press Esc to cancel
- Full screen: capture all screens

Default hotkeys:

- Selection: Control + P
- Full screen: Control + Shift + P
- Window: none (set one in Settings)

## Preview Tile

When enabled, a floating preview appears after capture:

- Checkmark button saves immediately
- Trash button discards the capture
- Click the preview image to save (if needed) and open in Preview
- Drag the preview into other apps to drop the image
- Esc saves, Command+Delete discards

If Auto-dismiss is enabled, the preview waits for the Save delay timer, then follows
the chosen timeout behavior (save or discard). If Auto-dismiss is disabled, the preview
stays until you act, but the file still saves after the delay.

## Output Behavior

- Every capture is copied to your clipboard.
- Saved files are PNGs.
- Save location and filename prefix are configurable in Settings.
- When previews are disabled, use Default output to choose Save to disk or Clipboard only.

## Settings

All preferences and defaults live in [`docs/settings.md`](settings.md).

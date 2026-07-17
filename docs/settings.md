# Settings

This document describes the settings available in OneShot.

The settings window is organized into General, Capture, Output, Preview, Hotkeys, and About tabs. The Capture tab contains the selection and sound controls.

## General

- `Launch at login` (default: off): Start OneShot automatically when you sign in. If macOS requires approval, OneShot reports that state and links to Login Items; a registration failure reverts the toggle.
- `Show menu bar icon` (default: on): Show the OneShot icon in the menu bar. If you turn this off, open OneShot from Spotlight to bring the settings window back.

## Selection

- `Show selection size` (default: on): Show the selection dimensions next to the cursor while selecting.
- `Selection dimming` (default: `Full screen`): Choose how the overlay dims the screen (`Full screen` or `Selection only`).
- `Selection color` (default: `#5151513F`): Selection-only fill color as RGBA hex (example: `#5151513F`). Used when `Selection dimming` is `Selection only`; the control is disabled for full-screen dimming. Six-digit values are treated as fully opaque.
- `Selection visual cue` (default: `Disabled`): Visual cue shown when selection mode starts (`Red pulse` or `Disabled`).

## Output

- `Filename prefix` (default: `screenshot`): Prefix used when naming saved screenshots. Invalid filename characters are stripped, empty results fall back to `screenshot`, and long Unicode prefixes are shortened at a valid character boundary so the complete filename stays within the filesystem limit. Settings shows an example of the effective filename.
- `Copy to clipboard automatically` (default: on): Copy captures to the clipboard immediately. The copy remains if you later discard the preview or delete its saved file. Clipboard-only output always copies, so this toggle is disabled in that mode.
- `Save location` (default: `Downloads`): Choose where screenshots are saved (`Downloads`, `Desktop`, `Documents`, or `Custom`).
- `Custom folder`: Writable folder used when `Save location` is set to `Custom`. `~` expands to your home folder. OneShot validates a newly selected folder before saving the preference; if a stored folder later becomes unavailable, the capture remains recoverable and OneShot offers Retry or Save As instead of silently changing destinations.
- `Default output` (previews disabled) (default: `Save to disk`): Choose whether screenshots save to disk or only copy to the clipboard.

Notes:

- When `Copy to clipboard automatically` is off, only the `Default output` option `Copy to clipboard` will place images on the clipboard.
- When `Default output` is `Copy to clipboard`, nothing is saved to disk and the save location/filename prefix are ignored.
- When floating previews are disabled and clipboard-only output is selected, disk naming and location controls are disabled because they cannot affect the result.
- If a generated filename already exists, OneShot keeps the timestamped name and appends a numbered suffix such as `-2` or `-3` instead of overwriting the existing file.

## Sound

- `Play shutter sound` (default: on): Play a sound when a screenshot is captured.
- `Shutter sound` (default: `Default shutter`): Choose the capture sound (`Default shutter`, `Grant's camera`, `Leah's camera`, or `Norm's camera`).
- `Volume` (default: `100%`): Set the shutter sound volume between 0% and 100%. Use the play button next to the slider to preview the selected sound at the current volume.

## Preview

- `Show floating preview` (default: on): Show the thumbnail preview after capture.
- `Auto-dismiss preview` (default: on): Automatically dismiss the preview after the save delay. Hovering or dragging pauses the dismissal.
- `Save delay (seconds)` (default: `7`): Time to wait before the preview timeout or background save when previews are enabled. Finite values are limited to `0...3600` seconds; invalid stored values migrate to `7`.
- `On preview timeout` (default: `Save to disk`): Choose whether the capture saves to disk or is discarded when the preview timer ends. Only applies when `Auto-dismiss preview` is on, and the control is disabled otherwise.
- `On new screenshot` (default: `Save previous capture`): Choose whether a visible preview is saved immediately or discarded when a new capture happens.

Click the checkmark to save immediately or the trash icon to discard the pending file. Discarding does not clear a clipboard copy.
Clicking the preview thumbnail saves (if needed) and opens the saved file in your default image app (typically Preview).
When Auto-dismiss is off, the preview stays visible until you act; if you do nothing, the file still saves after the delay.

If saving fails, the preview stays open with Retry, Save As, Copy, and Don't Save/Delete File actions. If opening fails after a successful save, the file remains on disk and can be retried or revealed in Finder.

When previews are disabled, screenshots follow the `Default output` setting and the save delay is ignored.

## Hotkeys

- `Selection`: Hotkey for selection capture (default: none).
- `Scrolling`: Hotkey for scrolling capture (default: none).
- `Full screen`: Hotkey for full screen capture (default: none).
- `Window`: Hotkey for window capture (no default).

Notes:

- Click a field and press the shortcut you want to record.
- Shortcuts must include at least one modifier key, so combinations like `Ctrl+D` are supported but plain letter keys are rejected.
- Press `Esc` to cancel recording and keep the previous shortcut.
- Use the clear button (or Delete while recording) to set the shortcut to `None`.
- OneShot rejects a duplicate shortcut assigned to another capture mode and restores the previous value.
- A shortcut that conflicts with macOS or another app remains visible but is marked inactive with an explanation.
- Hotkey changes take effect immediately.

## About

- `Check for Updates`: Manually check GitHub Releases for a newer stable OneShot release. This only runs when clicked, downloads or installs nothing, and opens the GitHub release page only when you choose `Open Release`.

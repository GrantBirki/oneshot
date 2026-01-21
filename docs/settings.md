# Settings

This document describes the settings available in OneShot.

## General

- `Launch at login` (default: off): Start OneShot automatically when you sign in.
- `Hide menu bar icon` (default: off): Remove the OneShot icon from the menu bar. To bring it back, open OneShot from Spotlight and disable this setting.

## Selection

- `Show selection coordinates` (default: on): Show the selection size next to the cursor while selecting.
- `Selection dimming` (default: `Full screen`): Choose how the overlay dims the screen (`Full screen` or `Selection only`).
- `Selection color` (default: `#5151513F`): Selection-only fill color as RGBA hex (example: `#5151513F`). Used when `Selection dimming` is `Selection only`. Six-digit values are treated as fully opaque.
- `Selection visual cue` (default: `Disabled`): Visual cue shown when selection mode starts (`Red pulse` or `Disabled`).

## Output

- `Filename prefix` (default: `screenshot`): Prefix used when naming saved screenshots. Invalid filename characters are stripped; empty results fall back to `screenshot`.
- `Copy to clipboard automatically` (default: on): Copy captures to the clipboard immediately, even if you later discard the preview.
- `Save location` (default: `Downloads`): Choose where screenshots are saved (`Downloads`, `Desktop`, `Documents`, or `Custom`).
- `Custom folder`: Path used when `Save location` is set to `Custom`. `~` expands to your home folder. Empty or relative paths fall back to `Downloads`.
- `Default output` (previews disabled) (default: `Save to disk`): Choose whether screenshots save to disk or only copy to the clipboard.

Notes:

- When `Copy to clipboard automatically` is off, only the `Default output` option `Copy to clipboard` will place images on the clipboard.
- When `Default output` is `Copy to clipboard`, nothing is saved to disk and the save location/filename prefix are ignored.

## Sound

- `Play shutter sound` (default: on): Play a sound when a screenshot is captured.
- `Shutter sound` (default: `Default shutter`): Choose the capture sound (`Default shutter`, `Grant's camera`, `Leah's camera`, or `Norm's camera`).
- `Volume` (default: `100%`): Set the shutter sound volume between 0% and 100%.

## Preview

- `Show floating preview` (default: on): Show the thumbnail preview after capture.
- `Auto-dismiss preview` (default: on): Automatically dismiss the preview after the save delay. Hovering or dragging pauses the dismissal.
- `Save delay (seconds)` (default: `7`): Time to wait before the preview timeout or background save when previews are enabled.
- `On preview timeout` (default: `Save to disk`): Choose whether the capture saves to disk or is discarded when the preview timer ends. Only applies when `Auto-dismiss preview` is on.
- `On new screenshot` (default: `Save previous capture`): Choose whether a visible preview is saved immediately or discarded when a new capture happens.

Click the checkmark to save immediately or the trash icon to discard.
Clicking the preview thumbnail saves (if needed) and opens the saved file in your default image app (typically Preview).
When Auto-dismiss is off, the preview stays visible until you act; if you do nothing, the file still saves after the delay.

When previews are disabled, screenshots follow the `Default output` setting and the save delay is ignored.

## Hotkeys

- `Selection`: Hotkey for selection capture (default: none).
- `Scrolling`: Hotkey for scrolling capture (default: none).
- `Full screen`: Hotkey for full screen capture (default: none).
- `Window`: Hotkey for window capture (no default).

Notes:

- Click a field and press the shortcut you want to record.
- Press `Esc` to cancel recording and keep the previous shortcut.
- Use the clear button (or Delete while recording) to set the shortcut to `None`.
- A warning appears if the shortcut may conflict with system shortcuts.
- Some hotkey changes require quitting and reopening OneShot.

# Settings

This document describes the settings available in OneShot.

## General

- `Launch at login`: Start OneShot automatically when you sign in.
- `Hide menu bar icon`: Remove the OneShot icon from the menu bar. To bring it back, open OneShot from Spotlight and disable this setting.
- `Show selection coordinates`: Show the selection size next to the cursor while selecting.
- `Selection dimming`: Choose how the overlay dims the screen (`Full screen` or `Selection only`). Default is `Full screen`.
- `Selection color`: Selection-only fill color as RGBA hex (example: `#FFFFFF1E`). Default is `#FFFFFF1E` and can be restored with `Reset`.
- `Selection visual cue`: Choose a visual cue when selection mode starts (`Red pulse` or `Disabled`). Default is `Disabled`.

## Output

- `Filename prefix`: Prefix used when naming saved screenshots. Empty or invalid values fall back to `screenshot`.
- `Copy to clipboard automatically`: Toggle whether captures are copied to the clipboard in addition to any saves.
- `Save location`: Choose where screenshots are saved (`Downloads`, `Desktop`, `Documents`, or `Custom`).
- `Custom folder`: Absolute path used when `Save location` is set to `Custom`. Empty or relative paths fall back to `Downloads`.
- `Default output` (previews disabled): Choose whether screenshots save to disk (clipboard copy depends on the auto-copy toggle) or only copy to the clipboard.

Notes:

- When `Copy to clipboard automatically` is off, only the `Default output` option `Copy to clipboard` will place images on the clipboard.

## Preview

- `Show floating preview`: Show the thumbnail preview after capture.
- `Auto-dismiss preview`: Automatically dismiss the preview after the save delay. Hovering or dragging pauses the dismissal (and any timed save) until interaction ends.
- `Save delay (seconds)`: Time to wait before applying the preview timeout or background save when previews are enabled.
- `On preview timeout`: Choose whether the capture saves to disk or is discarded when the preview timer ends.
- `On new screenshot`: Behavior when another capture happens while a preview is still visible.
  - `Save previous capture`: Saves the existing capture immediately and replaces the preview.
  - `Discard previous capture`: Cancels the existing capture and replaces the preview.

Click the checkmark to save immediately or the trash icon to discard.
Clicking the preview thumbnail saves (if needed) and opens the saved file in Preview so edits apply to the same file on disk.
When Auto-dismiss is off, the preview stays visible until you act, but the file still saves after the delay.

When previews are disabled, screenshots follow the `Default output` setting and the save delay is ignored.

## Hotkeys

- `Selection`: Hotkey for selection capture (default: none).
- `Full screen`: Hotkey for full screen capture (default: none).
- `Window`: Hotkey for window capture (no default).

Notes:

- Click a field and press the shortcut you want to record.
- Press `Esc` to cancel recording and keep the previous shortcut.
- Use the clear button (or Delete while recording) to set the shortcut to `None`.
- A warning appears if the shortcut may conflict with system shortcuts.
- Some hotkey changes require quitting and reopening OneShot.

# Settings

This document describes the settings available in OneShot.

## General

- `Launch at login`: Start OneShot automatically when you sign in.

## Output

- `Filename prefix`: Prefix used when naming saved screenshots.
- `Save location`: Choose where screenshots are saved (`Downloads`, `Desktop`, `Documents`, or `Custom`).
- `Custom folder`: Path used when `Save location` is set to `Custom`.

## Preview

- `Show floating preview`: Show the thumbnail preview after capture.
- `Auto-dismiss preview`: Automatically dismiss the preview after the save delay.
- `Save delay (seconds)`: Time to wait before saving a screenshot when previews are enabled.
- `On new screenshot`: Behavior when another capture happens while a preview is still visible.
  - `Save previous capture`: Saves the existing capture immediately and replaces the preview.
  - `Discard previous capture`: Cancels the existing capture and replaces the preview.

When previews are disabled, screenshots are saved immediately and the save delay is ignored.

## Hotkeys

- `Selection`: Hotkey for selection capture.
- `Full screen`: Hotkey for full screen capture.
- `Window`: Hotkey for window capture.

Notes:

- Click a field and press the shortcut you want to record.
- Press `Esc` to cancel recording and keep the previous shortcut.
- Use the clear button (or Delete while recording) to set the shortcut to `None`.
- A warning appears if the shortcut may conflict with system shortcuts.
- Some hotkey changes require quitting and reopening OneShot.

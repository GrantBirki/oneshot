# OneShot Usage

This guide explains how to use OneShot day to day. For every setting and toggle, see
[`docs/settings.md`](settings.md).

## Quick Start

1) Install via Homebrew: `brew install --cask grantbirki/tap/oneshot`
2) Launch OneShot from Applications (it runs as a menu bar app).
3) When prompted, grant Screen Recording permission in System Settings.

If Gatekeeper blocks an ad-hoc, unnotarized build, right-click `OneShot.app` and choose Open, or use Open Anyway in System Settings → Privacy & Security.

## Permissions

OneShot needs Screen Recording permission to capture screenshots:

- System Settings → Privacy & Security → Screen Recording (or Screen & System Audio Recording)
- Toggle OneShot on, then quit and relaunch the app

## Capture Modes

Use the menu bar icon (camera) or hotkeys to capture:

- Selection: click and drag to choose an area; press Esc to cancel
- Window: point to a window and click or press Return to capture it; press Esc to cancel
- Full screen: capture all screens
- Scrolling: select an area contained by one display, start near the top of the content, then scroll downward. Use the floating Stop control, the menu item, or the configured scrolling hotkey to finish.

Default hotkeys: none. Set them in Settings > Hotkeys.

Selection overlay:

- The size label next to the cursor can be toggled in Settings.

Scrolling capture is intentionally downward-only. Reverse movement is ignored instead of removing previously captured content. If capture reaches its pixel or memory safety limit, or repeated frame capture fails, OneShot returns the best valid partial screenshot and explains why it stopped.

## Preview Tile

When enabled, a floating preview appears after capture:

- Checkmark button saves immediately
- Trash button discards the pending file; an existing clipboard copy is retained
- Click the preview image to save (if needed) and open in your default image app (typically Preview)
- Drag the preview into other apps to drop the image
- After clicking or keyboard-focusing the preview, Esc saves and Command+Delete discards. These shortcuts do not react to keys typed in another app.

If saving fails, the preview stays open and offers Retry, Save As, Copy, and Don't Save/Delete File. If the file saved but could not be opened, it remains on disk and the preview offers Retry Open or Reveal in Finder.

If Auto-dismiss is enabled, the preview waits for the Save delay timer, then follows
the chosen timeout behavior (save or discard). If Auto-dismiss is disabled, the preview
stays until you act; if you do nothing, the file still saves after the delay.

## Output Behavior

- Clipboard copy is optional; toggle it in Settings > Output. When enabled, copies happen immediately and remain on the clipboard even if you later discard the preview or delete its saved file.
- Saved files are PNGs.
- Save location and filename prefix are configurable in Settings.
- When previews are disabled, use Default output to choose Save to disk or Clipboard only.

## Settings

All preferences and defaults live in [`docs/settings.md`](settings.md).

## Update

```bash
brew update
brew upgrade --cask oneshot
```

If OneShot is running, quit and relaunch it after upgrading so the new version loads.

## Uninstall

```bash
brew uninstall --cask oneshot
```

To remove settings and state:

```bash
brew uninstall --zap oneshot
```

## Menu Bar Icon

Opening OneShot from Spotlight shows the Settings window. This is useful if you hide the menu bar icon in Settings; just search for OneShot and turn the icon back on. A background launch at login stays hidden when the menu bar icon is disabled.

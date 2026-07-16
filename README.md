# PasteX

PasteX is a local-first, keyboard-first macOS clipboard history manager. This MVP records plain text only and never syncs data off your Mac.

## Run

```bash
swift run PasteX
```

Use **Option-Space** to show the clipboard window. Search immediately, use the arrow keys to select an item, and press **Return** to paste it as plain text.

The first paste invokes the macOS Accessibility permission request, because PasteX uses the system paste command to insert text into the previously active app. Until permission is granted, the selected text is still copied to the clipboard.

## Build a distribution package

```bash
./Scripts/package.sh 0.0.1
```

This produces `dist/PasteX-v0.0.1-macos-arm64.zip`, containing a macOS app bundle for Apple Silicon Macs (macOS 14+).

## Included P0 features

- Menu bar resident app and Option-Space global shortcut
- Plain-text clipboard history, local JSON persistence, pause/resume recording
- Search, keyboard selection, Return-to-paste, and plain-text copy/paste
- Favorites, basic groups, per-item deletion and history clearing
- Configurable retention period, text-size cap, and history-size cap

History is stored at `~/Library/Application Support/PasteX/history.json`.

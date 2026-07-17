# PasteX

PasteX is a local-first, keyboard-first clipboard manager for macOS 14+. It stores history on the Mac, never sends clipboard content to a server, and is designed for fast keyboard-driven reuse.

## Run from source

```bash
swift run PasteX
```

The default global shortcut is **Option-Space** (configurable to Command-Shift-V). Search immediately, use the arrow keys to select an item, press Return to paste, or press Command-1 through Command-9 to paste a visible result directly.

PasteX requests macOS Accessibility permission only when it needs to paste into the previously active application, position its compact menu near a focused input, or expand snippets system-wide.

## What is included in 0.0.4

- Clipboard history with text, link, code, and color classification; source-app and timestamp metadata; duplicate suppression; search and type/group filters.
- Menu-bar resident app, configurable global shortcut, keyboard-first panel, compact focused-input positioning with a safe centred fallback, and light/dark native UI.
- Pinned items, aliases, groups (create/rename/delete), batch deletion, timed history cleanup, and protected destructive clearing.
- Plain-text paste, one-off editing, saved edited copies, dynamic templates (`{{date}}`, `{{time}}`, `{{clipboard}}`, and custom fields), and optional typed snippet expansion.
- Configurable history lifetime (1 day, 7 days, 30 days, or forever), maximum item count, and maximum item size. Pinned items are excluded from normal pruning.
- Privacy controls: timed or manual pause, default password-manager app exclusions, sensitive-content detection, optional short-term sensitive storage, automatic sensitive expiry, Touch ID/system-password reveal, strict screen-sharing masking, and post-paste clipboard clearing.
- Encrypted local persistence. History and settings live in `~/Library/Application Support/PasteX/history.pastex`; the AES key is stored in the user’s Keychain. A legacy `history.json` file is migrated on first launch.
- Settings open in their own window. Clipboard history opens as an independent borderless floating panel, automatically focuses search, supports type/group/favorites filtering, and closes when it loses focus.
- The compact left navigation now only retains primary history actions; group and type filtering lives in the history toolbar so the history list remains the visual focus.

## Build a distribution package

```bash
./Scripts/package.sh 0.0.4
```

This creates `dist/PasteX-v0.0.4-macos-arm64.zip`, containing an ad-hoc signed `PasteX.app` for Apple Silicon Macs. To sign with a Developer ID for external distribution, provide your identity:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/package.sh 0.0.4
```

The GitHub `v0.0.4` release includes the generated ZIP and its SHA-256 checksum.

# Clipstasher

> The clipboard manager you can trust with your API keys.

A privacy-first macOS menu bar app that captures your clipboard history locally. Open source, zero telemetry, no cloud sync.

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)](https://www.apple.com/macos/)
[![MIT License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![GitHub Sponsors](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ea4aaa)](https://github.com/sponsors/ShreyRavi)

## Install

Clipstasher is distributed as an unsigned `.dmg`. macOS will show a security warning on first launch — this is expected. Use either method below.

> **Note:** Clipstasher is not notarized. This means macOS Gatekeeper will flag it on first run. The workaround is one step either way.

### Option A — Direct download (GUI)

1. Download the latest `.dmg` from the [Releases](https://github.com/ShreyRavi/clipstasher/releases) page.
2. Open the `.dmg` and drag **Clipstasher.app** to `/Applications`.
3. Run `xattr -d com.apple.quarantine /Applications/Clipstasher.app` to give permissions (one-time).
4. Right-click **Clipstasher.app** → **Open** → **Open** to bypass Gatekeeper (one-time), and log into Keychain.

### Option B — CLI install

```sh
# Download and mount
curl -L https://github.com/ShreyRavi/clipstasher/releases/latest/download/Clipstasher.dmg -o /tmp/Clipstasher.dmg
hdiutil attach /tmp/Clipstasher.dmg -mountpoint /tmp/ClipstasherMount

# Copy to Applications
cp -r /tmp/ClipstasherMount/Clipstasher.app /Applications/

# Unmount and clean up
hdiutil detach /tmp/ClipstasherMount
rm /tmp/Clipstasher.dmg

# Remove quarantine flag (bypasses Gatekeeper — no right-click needed)
xattr -d com.apple.quarantine /Applications/Clipstasher.app
```

Then launch normally from `/Applications` or Spotlight.

## Getting started

1. Launch Clipstasher — a clipboard icon appears in your menu bar.
2. Copy anything (text, code, API keys, error messages) as you normally would.
3. Click the clipboard icon to open your clip history. Click any clip to paste it directly (or copy-only — configurable in Settings).

That's it. Clips are stored locally in `~/Library/Application Support/Clipstasher/`.

## Features

- **Click to paste** — click any clip to paste it directly into the active app (requires Accessibility access); configure copy-only mode in Settings → Behavior
- **Clipboard history** — holds up to 1,000 recent clips (configurable 100–1,000)
- **Fast search** — instant filter across all clips
- **Pin important clips** — pinned clips survive "Clear All" and the history limit
- **Image support** — captures PNG/TIFF screenshots from the clipboard
- **Sensitive content blur** — API keys, tokens, and env vars blurred at display time; hover to reveal
- **Launch at Login** — optional, via Settings → System

## Privacy & Security

Text clips are encrypted at rest using **AES-256-GCM**. The encryption key is generated on first launch and stored in the macOS Keychain under `com.shreyravi.clipstasher`.

**Limitations — read before relying on this for sensitive data:**
- Image files are stored as unencrypted PNGs in `~/Library/Application Support/Clipstasher/images/`
- Any process running as the same macOS user can read the Keychain key — this does not protect against malware or an attacker with user-level access
- The sensitive content blur in the UI is a display convenience only; it is independent of the at-rest encryption
- For stronger protection, enable **FileVault** (System Settings → Privacy & Security → FileVault), which encrypts the entire disk

You can verify the binary integrity by comparing the SHA256 hash shown in **Settings → About** against the hash published on the GitHub release page.

## Updating

Clipstasher has no auto-updater. To update:

**GUI:**
1. Download the new `.dmg` from the [Releases](https://github.com/ShreyRavi/clipstasher/releases) page.
2. Quit Clipstasher (right-click the menu bar icon → Quit).
3. Open the `.dmg`, drag the new `Clipstasher.app` to `/Applications` and replace the existing one.
4. Relaunch from `/Applications`.

**CLI:**
```sh
# Quit the running app first
osascript -e 'quit app "Clipstasher"'

curl -L https://github.com/ShreyRavi/clipstasher/releases/latest/download/Clipstasher.dmg -o /tmp/Clipstasher.dmg
hdiutil attach /tmp/Clipstasher.dmg -mountpoint /tmp/ClipstasherMount
cp -r /tmp/ClipstasherMount/Clipstasher.app /Applications/
hdiutil detach /tmp/ClipstasherMount
rm /tmp/Clipstasher.dmg
xattr -d com.apple.quarantine /Applications/Clipstasher.app 2>/dev/null || true

open /Applications/Clipstasher.app
```

Your clip history, pins, and settings are preserved across updates — they live in `~/Library/Application Support/Clipstasher/` and are not touched by the update process.

## FAQ

**Why does Clipstasher ask for Accessibility access?**
Click-to-paste works by simulating ⌘V via the Accessibility API (`CGEvent.post`). Without it, Clipstasher falls back to copy-only mode. You can permanently disable click-to-paste in **Settings → Behavior** if you prefer not to grant access.

**Why 500ms polling instead of NSPasteboard change notification?**
macOS doesn't expose a public pasteboard change notification API. The `changeCount` integer on `NSPasteboard.general` is the official polling mechanism. 500ms is fast enough to capture any intentional copy without impacting battery life.

**Does Clipstasher work when other apps are in focus?**
Yes. Clipstasher disables App Nap so its timer fires reliably even in the background.

**How do I recover if the database gets corrupted?**
Clipstasher will show a dialog with a "Start Fresh" option that renames the corrupted file (preserving it as a backup) and creates a clean database. You can also manually delete `~/Library/Application Support/Clipstasher/clips.sqlite`.

**SPM / package resolution issues after cloning?**
If Xcode shows "Missing package product" errors, go to **File → Packages → Reset Package Caches** and then **Resolve Package Versions**.

## Build from source

See [CONTRIBUTING.md](CONTRIBUTING.md) for prerequisites and build instructions.

## Building a release DMG

Prerequisites: macOS, Xcode 15+, `xcodegen` (`brew install xcodegen`).

```sh
# 1. Generate Xcode project
xcodegen generate

# 2. Build Release .app (unsigned)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project Clipstasher.xcodeproj \
  -scheme Clipstasher \
  -configuration Release \
  -derivedDataPath /tmp/clipstasher-build \
  build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 3. Package into DMG
APP="/tmp/clipstasher-build/Build/Products/Release/Clipstasher.app"
STAGING="/tmp/clipstasher-dmg-staging"
VERSION="1.0.0"  # update per release

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -r "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "Clipstasher" \
  -srcfolder "$STAGING" \
  -ov -format UDZO \
  "Clipstasher-${VERSION}.dmg"

# 4. Print SHA256 for release notes
shasum -a 256 "Clipstasher-${VERSION}.dmg"
```

Output: `Clipstasher-1.0.0.dmg` in the current directory.

## SHA256 Verification

| Artifact | SHA256 |
|----------|--------|
| Running binary | See **Settings → About → Binary SHA256** |
| Release `.dmg` | Published on each [GitHub Release](https://github.com/ShreyRavi/clipstasher/releases) |

## Support

- [Report an issue](https://github.com/ShreyRavi/clipstasher/issues)
- [Sponsor on GitHub](https://github.com/sponsors/ShreyRavi) — free forever, sponsors keep it alive

## License

MIT — see [LICENSE](LICENSE).

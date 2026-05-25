# Contributing to Clipstasher

## Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later (includes Swift 5.9)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

> **SPM note:** If Xcode shows "Missing package product" errors after cloning, go to **File → Packages → Reset Package Caches** and then **Resolve Package Versions**.

## Build

```sh
git clone https://github.com/ShreyRavi/clipstasher.git
cd clipstasher

# Regenerate the .xcodeproj from project.yml (required after pulling)
xcodegen generate

# Open in Xcode
open Clipstasher.xcodeproj
```

Press **Cmd+B** to build, **Cmd+R** to run.

## Test

Press **Cmd+U** in Xcode to run all tests.

From the command line:
```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project Clipstasher.xcodeproj \
             -scheme ClipstasherTests \
             -destination 'platform=macOS' \
             test
```

All 87 unit tests should pass. Tests use an in-memory GRDB database — no disk state.

## Architecture

| File | Responsibility |
|------|---------------|
| `ClipstasherApp.swift` | `@main` SwiftUI App, MenuBarExtra scene |
| `ClipStore.swift` | `@MainActor` ObservableObject — GRDB, all DB operations |
| `ClipboardMonitor.swift` | NSPasteboard 500ms polling, re-entry guard |
| `SensitiveContentDetector.swift` | Regex patterns — no DB side effects |
| `ClipstasherView.swift` | Main 320×480pt popover UI |
| `ClipItemRow.swift` | 52pt list row with blur, pin, copy |
| `SettingsView.swift` | Preferences + About tabs |

Key constraints:
- Never write to the DB on the main thread — all writes use `Task.detached`
- `lastSelfWriteChangeCount` re-entry guard prevents capturing your own copy actions
- Use `LazyVStack` (not `List`) for <50ms popover open with 1,000 items
- `SensitiveContentDetector` is presentation-only — no schema changes

## Submitting changes

1. Fork the repo and create a branch
2. Make your changes with tests
3. `xcodebuild test` passes
4. Open a PR against `main`

Please file bugs at [GitHub Issues](https://github.com/ShreyRavi/clipstasher/issues).

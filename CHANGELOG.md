# Changelog

All notable changes to Clipstasher are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
Versioning: [Semantic Versioning](https://semver.org/)

---

## [Unreleased]

### Added
- At-rest encryption for text clips using AES-256-GCM; key stored in macOS Keychain
- Legacy plaintext clips read transparently without migration (passthrough on decrypt)
- "Updating" section in README with GUI and CLI update instructions

## [1.0.0] — 2026-05-24

### Added
- Menu bar clipboard history (up to 1,000 clips, configurable)
- Fast instant search across all clips
- Pin/unpin clips to preserve them across "Clear All" and history pruning
- Image clipboard support (PNG/TIFF captured, stored as PNG)
- Sensitive content blur for API keys, tokens, and environment variables
  - Patterns: `sk-...`, `ghp_...`, `Bearer ...`, `ENV_VAR=value`
  - Hover to reveal; blur is UI-only (not encrypted on disk)
- Settings panel (gear icon):
  - **Preferences:** history limit (100–1,000), Launch at Login toggle
  - **About:** binary SHA256 for integrity verification, data folder path, GitHub Issues link
- Consecutive-duplicate deduplication (same content copied twice → stored once)
- Migration failure recovery dialog (Start Fresh / Quit)
- App Nap prevention for reliable 500ms background polling
- macOS 13+ support (MenuBarExtra `.window` style)
- XCTest suite covering all 17 core unit-testable paths

[Unreleased]: https://github.com/ShreyRavi/clipstasher/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ShreyRavi/clipstasher/releases/tag/v1.0.0

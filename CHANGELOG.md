# Changelog

## Unreleased — Phase 0

- Audited and initialized the private official repository.
- Selected iOS 26.0, Swift 6, native SwiftUI, local SwiftData and Apple audio adapters.
- Added the first Swift domain implementation and conservative Signal Path policy.
- Added 19 domain XCTest methods and macOS package CI.
- Documented audio/Files restrictions, licensing boundaries, build and evidence requirements.

An iOS app target, importer, player and IPA are pending later phases.

## Unreleased — Phases 1–2

- Added reproducible native Xcode app, themes, Home/Library/Now Playing/Settings and icon.
- Added private-copy coordinated import, local SwiftData store, real metadata/artwork and deduplication.
- Added search/favorites/group browsing, local availability/metadata rescan and storage information.
- Added iOS simulator integration/UI tests, unsigned device build and conditional IPA packaging.
- Playback remains pending Phase 3; no physical device or bit-perfect verification is claimed.

## Unreleased — Phase 3

- Implemented native file/PCM scheduling, transport, seek, queue, shuffle and repeat.
- Added system remote controls, local text/timing Now Playing metadata with suggestions excluded, background playback configuration, interruptions, routes and reset handling.
- Added queue/position restoration and observed output diagnostics; all output remains Not Bit-Verified.
- Expanded to twelve themes with distinct surfaces/accents and separated mini-player transport from navigation.
- Added queue/seek regression tests and offline WAV/ALAC PCM graph tests.
- Gapless transitions, physical output verification and lock-screen artwork remain pending.

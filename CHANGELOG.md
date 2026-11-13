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
- Fixed a reserved `hash` storage-property collision discovered by actual library tests; renamed the persisted attribute to fileHash with migration mapping.
- Made the native glass mini-player independently visible/accessibile in every tab and retained its navigation UI assertion.

## Unreleased — Phase 4

- Adopted user-selected Prism logo with native reproducible icon export.
- Connected the shared Signal Path evaluator to actual file/decoder/mixer/session/route observations.
- Added six-stage evidence-labelled Signal Path UI and memory-only route/interruption events.
- Added invalidation coverage for inactive, interrupted, stopped and ambiguous-output states.
- Preserved no-bit-verification policy; physical DAC properties remain unknown.

## Unreleased — Phase 5

- Added bounded offline integer PCM reference generation/comparison with decoded PCM hashes, whole-frame alignment, channel/volume/rail/mismatch reports and no physical-verification inference.
- Added negative controls for single-bit changes, channels, gain, clipping, resampling, dropped frames, invalid containers and ambiguous alignment.
- Added handwritten WAV/AIFF PCM16/24 offline production-graph matrix tests at six rates, library metadata scale tests and audio path/parser boundary tests.
- Added native test screenshots and an accessibility label/touch-target check; expanded mini-player navigation to a minimum 44-point target.
- Replaced the separate simulator capture with bounded export of actual XCTest attachments.
- Version 0.5.0/build 5. Execution and physical limitations must be recorded in the verification report; authored tests alone do not prove passing results.

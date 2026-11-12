# Verification and phase ledger

## Phase 0

Core Swift 6 package compiled with Xcode 26.3 / Swift 6.2.4; all 19 domain tests passed. Evidence: https://github.com/Cloud9null/Soundly/actions/runs/43245316376 . No runtime bit verification exists.

## Phase 1 implementation

Checked-in reproducible Soundly.xcodeproj and shared scheme, iOS 26.0 minimum, Swift 6, native SwiftUI Home/Library/Settings, bottom-accessory mini-player, Now Playing sheet, six saved appearance choices, native Liquid Glass, original waveform app icon, privacy manifest and background audio declaration. Empty/selected state is honest: audio engine and transport controls are not implemented.

The initial Phase 1 commit 9035c8b080c6ef97875897fd67355ac3e70685c4 passed the unsigned generic iOS Release device build in GitHub CI. Latest app and UI test results must be read from PR #1 checks. Declaring background audio in Info.plist alone does not implement background playback.

## Phase 2 implementation

- Local SwiftData store explicitly disables CloudKit. Worker ModelActor handles import writes.
- Native Files multi-file picker and separate folder picker; scoped resources, coordinated read/copy, recursive accessible folder walk, symlink/package skipping.
- Bounded 1 MiB streaming copy and SHA-256, staging/final move, duplicate lookup, insertion rollback cleanup; reimport restores missing copies without duplicating the record. Source extension is an initial filter; AVAudioFile must decode a frame and report supported lossless/PCM codec before registration. AAC M4A is rejected.
- Cancellation checked during chunks, metadata blocks and enumeration; counters report imported, duplicate, error and cancellation totals. Cancellation preserves finished imports.
- AVFoundation metadata plus bounded FLAC STREAMINFO/Vorbis/PICTURE parser; Unicode fallback filenames; source bit depth remains unknown when unavailable. ID3 and MP4 common fields, album artist, composer, genre and track/disc tags handled where exposed. Unusual vendor tags and repeated multi-artist semantics need further fixtures.
- Bounded thumbnail generation and in-memory artwork cache. Search through database predicate, alphabetical/date sorting, favorites filter, album/artist/folder browsing, persistent favorite changes.
- Local rescan refreshes available metadata and artwork, marks missing files, and preserves records/favorites/history. It does not scan external sources again without a new user selection.
- Settings shows imported-folder labels, track count and imported music bytes. Music and database are excluded from backup; keep originals.
- Seven iOS integration tests authored: actual WAV import/dedup/metadata, corrupt rejection, pre-cancellation, store reopen/missing file preservation, recursive folder/symlink behavior, malformed FLAC and FLAC source-depth/Unicode comments. One native UI navigation test and one appearance test.

## Remaining verification and scope

The execution host is Linux without Swift/Xcode; actual iOS builds/tests run in GitHub macOS CI. A green macOS core-package check does not substitute for the iOS workflow. Refer to latest PR check logs for compiler/test results and retained evidence. Initial account artifact upload failed due to exhausted quota; changing visibility does not itself establish successful artifact delivery.

No physical iPhone installation, DAC, audible playback, background playback, bit-perfect capture, format/rate matrix, or 100/1,000/10,000-track performance measurements have been performed. Linked external folders/bookmarks, comprehensive metadata edge cases, playlists/LRC, full listening-history Home sections and a dedicated duplicate manager remain later work. The importer shows aggregate counters and up to 20 per-file error details in the UI; it does not log filenames to CI.

Phase 3 implements the audio engine, queue, seek, interruption handling and system controls. Phase 4 binds actual observations to Signal Path UI. Phase 5 expands fixture/UI/accessibility/performance tests. Phase 6 verifies signing/installation and release readiness. An unsigned IPA from CI is an early app for signing/testing, not a completed music player or a verified installation.

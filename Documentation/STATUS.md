# Verification and phase ledger

Current checkpoint: **Phase 5 automated quality**, version **0.5.0 (5)**. Earlier phase sections below describe historical implementation states. See PHASE-5-VERIFICATION.md for current executed evidence and DEVICE-ACCEPTANCE.md for physical testing still required.

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


## Phase 3 implementation update

Native AudioTransport actor, PlaybackController, queue/persistence, system controls, interruption/route/reset handling and observed diagnostics are now implemented. Theme count is twelve. See PHASE-3-AUDIO.md for exact behavior and limitations; prior statements that playback is pending describe the earlier Phase 2 checkpoint. No physical playback, installation, DAC or bit verification result has been established. Check current-head Actions for compilation and the authored playback tests; do not infer success from this ledger.

## Phase 3 verified checkpoint

Commit 122af9cb6928328124009cb225395712b683eeec passed the unsigned iOS Release build and all **38** core/app/UI tests. An unsigned arm64 device IPA was actually generated, downloaded and inspected. See PHASE-3-VERIFICATION.md for exact run, test breakdown, hashes and limits. The optional screenshot failed due to a shutdown base simulator; it is not included or claimed as reviewed.

## Phase 4 verified checkpoint

User-selected Prism is the primary icon. Actual source/decoder/mixer/session/route observations now feed the canonical Signal Path assessment and six evidence-labelled native cards, with a private bounded memory-only route/interruption history. Version 0.4.0/build 4 on commit c4737944a0d5a69f926900786fe905f03f183a0f passed the unsigned Release build and **41** core/app/UI tests. Its actual arm64 IPA was downloaded and hash-checked; the compiled Prism icon was inspected. Run: https://github.com/Cloud9null/Soundly/actions/runs/43289267087 .

The separate optional simulator Home capture timed out; no running-screen visual QA is claimed. Packaging precedes that bounded step, and IPA/test evidence upload succeeded. See PHASE-4-VERIFICATION.md for precise hashes and limits. Physical installation/playback/routes, background lifecycle, full rate matrix, performance/accessibility and external bit comparison remain unverified. Gapless and lock-screen artwork remain pending; the wider MVP is not declared complete. No runtime output is bit-verified.

## Phase 5 verified automated quality checkpoint

Commit 4c10720b3e6be9bda55048efd4703f458e1868ee passed Xcode 26.3 unsigned Release and **65 unique tests**: 19 core, 28 app, 3 UI and 15 Python. Run: https://github.com/Cloud9null/Soundly/actions/runs/43374763875 . The two new matrix methods cover 24 WAV/AIFF integer PCM16/24 cases through 192 kHz with zero numerical mismatches, separate from the existing FLAC/ALAC fixtures. Synthetic 100/1,000/10,000-row metadata queries passed; no real-library benchmark is claimed.

Six actual UI test screenshots and both matrix records exported and were downloaded. Native review found and corrected empty/search copy and a missing Source icon; final corrected views were inspected. A scoped Home element-description audit and mini-player target/value check passed. The arm64 0.5.0/build 5 IPA was downloaded, archive-digest checked and inspected; see PHASE-5-VERIFICATION.md for exact hashes, scope and remaining physical/quality work. PCM-CAPTURE-TOOLS.md documents executable local reference/negative-control/capture comparison tools, which cannot authenticate hardware or grant bit verification. The broader MVP and physical distribution acceptance remain incomplete.

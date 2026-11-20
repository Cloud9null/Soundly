# 0.11 local playlist exchange

Adds an original bounded local M3U/M3U8 parser and UTF-8 extended-M3U export. Import resolves references against existing private-library records: exact Soundly SHA-256 annotations, exact filenames, then unique metadata. An explicit unknown hash never falls back to a different song. Matched track order is preserved and repeated resolved tracks collapse. Ambiguous/missing references are retained separately for retry after importing more music; export places pending references after resolved tracks, so the original mixed pending/resolved ordering is not retained.

The review sheet shows matched, unmatched, ambiguous, repeated, remote and invalid counts before saving. No referenced disk path is opened: local path strings are reduced to basenames only. Remote URLs, remote file hosts and UNC paths are skipped; HLS playlists are rejected. M3U8 requires UTF-8; legacy M3U can fall back to Windows-1252. Parsing is off the UI actor. Files are limited to 2 MiB and 20,000 references; JSON exchange retains its existing limits. Writes validate before replacing saved playlist data. Existing JSON without the optional pending field remains readable. Older Soundly versions may discard the new optional field when exporting.

Export includes playlist data, not music. Each track's context menu can explicitly share its existing private copy through the system share sheet. For another player to use the exported list, save those music files beside the playlist and preserve their exported filenames. No automatic network upload or download is implemented. Users choose destinations in system sheets. Physical Files-provider import/export acceptance remains a device check.

No audio graph, SwiftData schema, UI theme or icon assets changed. This release preserves the 0.10 integrated source waveform/glass playback deck and nine alternate icons. Source PCM display is not DAC measurement; no bit-perfect or exclusive-hardware claim is introduced. Gapless, physical output/system artwork/background acceptance and broader product work remain pending.

## Verification

Application/test/build source: 92ee8c5ddeb737516476239a4ba7131c836654ac.
CI: https://github.com/Cloud9null/Soundly/actions/runs/43699785424 . Xcode 26.3 unsigned iPhone Release passed. All 107 unique tests passed: 33 domain, 50 app/integration, 9 native UI and 15 Python comparison controls. The two new app methods verify compatibility of existing JSON/pending persistence and actual Song-model M3U roundtrip resolution. The native playlist creation/selection/relaunch flow passed with the new M3U export action present. Existing integrated waveform actual seek, icon metadata, queue, library, lyrics, Signal Path and PCM methods also passed. System Files import/export and share-sheet destination behavior still require physical-provider acceptance.

Standalone artifact: https://github.com/Cloud9null/Soundly/actions/runs/43699785424/artifacts/14155582720 . Downloaded archive SHA-256 matched 249b2f02029a25e55590ccb625e4858ad82a10c56090b61c3813e9e2059a2e2f.

Actual inspected IPA: Soundly-0.11.0-Prism-unsigned.ipa, 10,654,751 bytes, SHA-256 e09deec98fb870bf254ecb30efc1b24d231d9b5523e28f960b974bd561775425. Checked ZIP integrity, arm64 Mach-O iOS platform 2, minimum iOS 26.0, SDK 26.2, version 0.11.0/build 11, app.soundly.player, background audio and all nine alternate-icon declarations. XCTest/provisioning payloads and DEBUG fixture/launch markers were absent. Saved the actual IPA for personal Sideloadly delivery; this is not an installation test or physical bit verification.

The earlier attempt failed at test compilation because a new XCTest property collided with NSObject.hash. The final source renames that test property. No IPA was produced by the failed attempt.

PR #1 remains draft and main stays unmerged. Documentation-only follow-up preserves verified application/test/build/brand inputs.

Downloaded final native test evidence contains 27 PNG attachments and four offline PCM records. All 48 direct/mixer WAV/AIFF integer PCM16/24 stereo cases through 192 kHz had zero mismatched numerical samples. These are cases within existing tests, not extra tests or physical DAC captures. Evidence artifact: https://github.com/Cloud9null/Soundly/actions/runs/43699785424/artifacts/14156401901 ; its recomputed downloaded archive digest matched d9325664019e93113854e1ddcaf0c88adcdfdd7c7941be228d3a0308fcdf5694. Artifact retention is three days. Physical external digital capture remains required for any bit identity claim.

The final native enabled-waveform/long-title player attachment was visually inspected; square artwork, integrated seek surface, transport and footer remain arranged without overlap. Simulator volume rendering does not establish physical volume-control behavior.

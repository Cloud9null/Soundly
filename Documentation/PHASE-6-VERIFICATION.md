# Phase 6 — verified refinement and device preview

**Version 0.6.0/build 6** passed the unsigned iOS Release build and all **80 unique automated tests** on application/test commit `9da1e736ca806c9e727b91ad7eb290dc84271528`.

- iOS workflow: https://github.com/Cloud9null/Soundly/actions/runs/43483658251
- Toolchain: Xcode 26.3, build 17C529, standard macOS 26 arm64 runner.
- Device package: `Soundly-0.6.0-Prism-unsigned.ipa`.
- GitHub artifact: https://github.com/Cloud9null/Soundly/actions/runs/43483658251/artifacts/14067308292 (three-day retention; a separate persistent download was delivered in the project conversation).

## Executed checks

| Suite | Unique methods | Result |
| --- | ---: | --- |
| Core domain | 19 | Passed |
| iOS app/integration | 40 | Passed |
| Native UI | 6 | Passed |
| Python PCM comparison controls | 15 | Passed |
| Total | 80 | Zero failures |

The four matrix methods are included in the app count; they exercise **48 WAV/AIFF integer PCM16/24 stereo cases** across direct and main-mixer graphs at 44.1, 48, 88.2, 96, 176.4 and 192 kHz. All four exported records were downloaded and checked: 12 cases each, zero numerical sample mismatches. This is exact numerical comparison in offline AVAudioEngine rendering, not physical iPhone/DAC bit verification. Existing FLAC/ALAC fixtures, actual transport scheduling/seek/pause and synthetic metadata stores through 10,000 rows also passed; no real-library benchmark is claimed.

Seven duplicate methods passed: actual hash scanning/removal, retained-current preference/history/favorite merge, changed-file rejection, shared filenames, missing/cancelled scans, traversal/symlink rejection and simulated interrupted-operation restore/committed cleanup. The native UI removal flow reviewed actual duplicate test bytes, confirmed deletion and changed the library from 3 to 2 rows. Original Files sources are not deletion targets.

All six native UI methods passed. Coverage includes offline empty/search/settings navigation, full-screen dismissal, the scoped Home description audit, a populated player with real generated PCM24 files, artwork expansion/close, the live quality sheet, queue, controlled accessibility2 text, touch regions and transport above the glass footer. The full-row Settings diagnostics link waits for a stationary native Form row in its UI test. AX coordinate comparisons use a one-millionth-of-a-point numeric tolerance for transformed values such as 43.99999999999997; controls retain their 44-point minimum.

## Native screenshot review

Sixteen PNG screenshots and the four matrix records exported successfully and were downloaded. Final native screenshots were inspected: Home and its system tab-bar accessory, numbered Songs, the full-screen player, compact artwork at accessibility text sizes, inactive Signal Path, live quality sheet, queue, immersive artwork and duplicate review. Song rows now share the theme surface; main transport and volume remain clear of the footer in the tested layout. Test artwork is original and labelled Reference/Test PCM. No user music was included in CI.

Preceding UI runs exposed undersized hit regions, overwritten artwork-close identity, text-size propagation, large-text overlap, row backgrounds, floating-point bounds comparisons and Settings navigation after scrolling. Corrections were made and the full final suite passed; those failed attempts did not package a deliverable IPA. Source changes alone were never counted as passing execution.

## Downloaded artifact inspection

The GitHub ZIP archive was downloaded and its advertised digest checked before extraction:

- Archive SHA-256: `4e26d754959cc06214a4ffe64dca0457cc1911005d8f0ebf9af9399cc609c1ec`.
- IPA size: **1,914,072 bytes**.
- IPA SHA-256: `916cd73cbbb569dd484ab71a8673d99761e9c0992d8158dc6e3ecd081c27d56f`.

The IPA ZIP passed its integrity check. Its actual executable is arm64 Mach-O with `LC_BUILD_VERSION` platform iOS (not simulator). Info.plist reports iPhoneOS, version 0.6.0, build 6, minimum OS 26.0, bundle `app.soundly.player` and background audio. Compiled assets are included. No provisioning profile, Apple signing material, XCTest payload or test fixture flags/audio markers were found. It requires signing with the user's own Sideloadly configuration; it is not an Apple-signed export or an installation test.

## Physical and product boundaries

User screenshots establish installed-interface observations for the earlier build, not final 0.6 device acceptance. No physical signing/installation, audible/background/locked-screen lifecycle, interruption, USB DAC/Bluetooth/AirPlay or external digital-capture result is claimed here. The simulator quality screenshot correctly reports an observed rate conversion; it does not establish native-rate hardware behavior.

The direct graph bypasses the application main mixer only for compatible observed formats. It does not bypass iOS, provide exclusive DAC access or reveal physical DAC bit depth. Integer/Float32 conversion stays disclosed. No runtime path can grant Verified Bit-Perfect. External digital capture and DEVICE-ACCEPTANCE.md remain necessary. Broader accessibility/contrast/performance, gapless, lock-screen artwork, playlists/LRC, linked folders and the remaining product scope are still separate work.

The subsequent documentation-only commit preserves every verified app, test, script, project, brand and workflow file. Main remains unmerged and PR #1 remains draft.

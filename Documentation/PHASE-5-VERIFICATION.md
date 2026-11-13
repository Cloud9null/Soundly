# Phase 5 — verified automated quality checkpoint

Application/delivery commit: `4c10720b3e6be9bda55048efd4703f458e1868ee`.

Successful CI: https://github.com/Cloud9null/Soundly/actions/runs/43374763875

The reproducible project check, unsigned Release device build, all required tests, packaging, actual XCTest attachment export and artifact upload succeeded with Xcode 26.3 on the macOS runner. The selected test device was an available iOS 26 **iPhone 17 Pro simulator**, not physical equipment.

## Actual test results

| Suite | Test methods | Result |
| --- | ---: | --- |
| Swift domain package | 19 | Passed |
| iOS app integration/unit tests | 28 | Passed |
| Native UI tests | 3 | Passed |
| Python PCM reference/comparator tests | 15 | Passed |
| Unique total | **65** | **Zero failures** |

The separate Core workflow also passes the same 19 domain tests; these are not counted twice. The **24 WAV/AIFF cases** are exercised inside two matrix methods, not counted as 24 additional XCTest methods.

The 28 app tests cover appearance (1), library import/persistence (7), metadata scale (3), PCM matrix (2), existing PCM rendering (4), queue/seek (5), live transport (1), Signal Path (3) and audio/parser boundaries (2).

## PCM and scaling evidence

- Handwritten WAV and AIFF, 16/24-bit stereo, at 44.1/48/88.2/96/176.4/192 kHz: **24 cases**, 2,048 frames and both channels per case, **zero numerically mismatched samples** through the production offline graph. The two exported matrix text records were downloaded and inspected. This is internal PCM evidence, not a physical DAC measurement.
- Existing ALAC/WAV and FLAC 16-bit/44.1 kHz and 24-bit/96 kHz graph tests remain passing. No blanket ALAC/FLAC or route/rate matrix is inferred from the wider WAV/AIFF checks.
- Synthetic in-memory metadata stores at **100, 1,000 and 10,000** records passed count, exact search, favorite filter and sorted-page assertions. These are functional database tests; no real-song import, artwork, scroll, startup, energy or device benchmark is claimed.
- Python negative controls passed actual single-bit, channel-swap, gain, additional rail samples, resampling changes, dropped frames, rate/width, truncated-container and ambiguous-alignment checks. PCM equality never grants hardware verification. CLI exit codes 0/1/2 were also exercised locally.
- Twelve generated reference WAVs and their decoded PCM SHA-256 manifest were downloaded from the final CI artifact and hash-checked. Independent Linux decoding with **ffmpeg 7.1.5-0+deb13u1** also matched all twelve generated PCM hashes. ffmpeg is a developer validation tool, not an app runtime dependency.

## Native UI and accessibility evidence

Three native UI tests passed: navigation/empty states/Signal Path, a real unmatched-search query, and primary-control description/value/minimum touch target plus the system's sufficient-element-description audit on Home.

Six screenshots exported successfully from **the actual test process**: Home, Library, Settings, empty Now Playing, inactive Signal Path and unmatched local search. The earlier quality run's five screens were visually reviewed; that review exposed misleading empty/search copy and a missing Source icon. After corrections, the final Library, unmatched-search and Source-card screenshots were inspected again and confirm those fixes. No fictional songs, artwork, active route values or physical device results were inserted to make screenshots appear functional.

The mini-player now has a minimum 44-point target and a VoiceOver value with the selected title/artist (or honest empty-state value). This scoped audit and normal-size/default-appearance screenshot review do **not** establish comprehensive VoiceOver, Dynamic Type, contrast, Reduce Motion, all-theme or small-device accessibility approval. Populated-library/active-player visuals and those wider checks remain to be reviewed on suitable data/equipment.

Initial quality commit bdae83f passed 64 tests before the separate search regression was added. The final commit/run above repeated the full build/checks and passes 65; its IPA is the delivered revision.

## Inspected device artifact

Artifact: https://github.com/Cloud9null/Soundly/actions/runs/43374763875/artifacts/14014975448

| Property | Observed value |
| --- | --- |
| Delivered file | Soundly-0.5.0-Prism-unsigned.ipa |
| IPA bytes | 1782839 |
| Executable/platform | ARM64 Mach-O / iPhoneOS |
| Bundle ID | app.soundly.player |
| Version / build | 0.5.0 / 5 |
| Minimum iOS | 26.0 |
| Background declaration | audio |
| Identity | User-selected Prism master/native icon export retained |

IPA SHA-256:

`6c9a14cbaa280f7215ef464f7adc0a1865aea2b02dce3e229faf14f14f766283`

Downloaded archive SHA-256, matched against GitHub's reported artifact digest:

`4a81ae228cff421dfc7b6b40ae048b4e72c71db9da3b65a6a9ee57adb47f50c8`

The IPA was downloaded and inspected for the actual binary, bundle settings, version, deployment minimum and background mode. It is a device application packaged with signing disabled, for later signing/testing; a physical install has not been performed. Reference fixtures and XCTest screenshots are CI test evidence, not music bundled into the Release app.

## Phase boundary and remaining work

The **automated quality milestone** is complete for this explicit source revision. Physical signing/installation, audible/background/lock-screen behavior, actual interruptions/routes/DACs, external digital capture, broad accessibility and real-library energy/performance remain unverified. Gapless, lock-screen artwork, wider playlists/LRC and linked folders remain pending. The overall MVP is not declared finished from CI alone; main remains unmerged and PR #1 stays draft.

Use BUILDING.md, DEVICE-ACCEPTANCE.md and PCM-CAPTURE-TOOLS.md for the next distribution/equipment checks. All runtime output remains Not Bit-Verified. A matching supplied PCM window cannot authenticate its capture provenance or prove every downstream iOS/DAC stage. No account, telemetry, runtime dependency, signing secret, copied reference-product code or owner-unselected license was added.

Subsequent documentation-only commits preserve the verified application, test and script sources and delivered IPA. This report always refers to the explicit application/delivery commit above.

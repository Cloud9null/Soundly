# Phase 4 verified checkpoint — 2026-11-12

Application and delivery commit: `c4737944a0d5a69f926900786fe905f03f183a0f`.

CI: https://github.com/Cloud9null/Soundly/actions/runs/43289267087

The workflow completed successfully. Required build/test/packaging steps passed; the optional native Home screenshot timed out and is not included or claimed as reviewed.

## Executed checks

- Reproducible project generation matched the checked-in Xcode project.
- Xcode 26.3 unsigned generic iOS Release build succeeded.
- **19 core-package tests** passed, zero failures.
- **21 simulator app tests** passed, zero failures: appearance (1), import/persistence (7), offline PCM graph (4), queue/seek (5), live transport (1), live Signal Path/source/route classification (3).
- **1 native UI test** passed, including Home/Library/Settings, mini-player, Now Playing and Signal Path/status navigation.
- Total: **41 tests, zero failures**.
- Existing WAV/ALAC and FLAC 16-bit/44.1 kHz and 24-bit/96 kHz production-graph tests remain passing.
- Actual FLAC source depth remains 24-bit integer while the observed AVAudioFile processing format is Float32. The shared assessment correctly discloses conversion instead of claiming bit identity at equal rates.
- Live transport assertions cover inactive preparation, playing observations, interruption invalidation and stopped-session status. Route mapping covers single exposed ports and conservative ambiguous/missing-output fallback.

The same application source passed all 41 tests in earlier run 43287008707, then that run was cancelled during a separate optional simulator capture before packaging. Commit c473794 only changed CI ordering and bounded capture; an explicit Git diff confirmed application, tests, core policy, generator, project and Brand were unchanged from e41e72c. The complete delivery run above repeated the required checks and produced the actual artifact.

## Inspected device artifact

Artifact: https://github.com/Cloud9null/Soundly/actions/runs/43289267087/artifacts/13975969813

The ZIP archive was downloaded and its SHA-256 matched GitHub's reported digest. The contained IPA was inspected, not merely renamed from sources:

| Property | Observed value |
| --- | --- |
| IPA filename | Soundly-0.4.0-Prism-unsigned.ipa |
| IPA bytes | 1778997 |
| Executable | ARM64 Mach-O device binary |
| Supported platform | iPhoneOS |
| Bundle identifier | app.soundly.player |
| Version / build | 0.4.0 / 4 |
| Minimum iOS | 26.0 |
| Background mode | audio |
| App icon | Compiled Prism icon and asset catalog present |

IPA SHA-256:

`23ef535ebc1348470ba23406997081a72f600aef2e2ec4f0eec7108304bef49f`

Archive SHA-256:

`b045c03fc83677bc4c09db20698df806f1d8cd88d3d6da03552fa3decf0edee4`

The embedded 120-pixel app icon was extracted, its Apple CgBI PNG decoded for inspection, and the Prism mark visually confirmed. The original compiled icon/IPA was not modified. The exact user-approved master remains Brand/Prism-master.png, exported by Apple's sips in the native build phase.

## Optional capture limitation

The separate base simulator booted, but its subsequent app installation/capture sequence did not complete within two minutes. Logs explicitly report a capture timeout; continue-on-error allows the already tested/packaged IPA and Tests.xcresult to upload. There is **no Home.png** in this artifact. UI navigation execution passed, but full visual QA of the running Home/Now Playing/Signal Path screens is not claimed. Packaging now precedes this optional step so it cannot hold up artifact creation indefinitely.

## Remaining physical and product validation

This is an **unsigned** device application for later signing, not a verified installation. Physical iPhone installation, audible/background/lock-screen lifecycle, interruptions on equipment, USB DAC, Bluetooth/AirPlay, complete format/rate matrix, accessibility/energy/performance and external digital-capture comparisons remain unverified. Follow DEVICE-ACCEPTANCE.md and AUDIO-VERIFICATION.md and record real results.

No route is Verified Bit-Perfect. The app cannot infer exclusive DAC access, physical bit depth or sample identity from iOS session metadata. Gapless transitions and lock-screen artwork remain pending, along with broader playlist/LRC and linked-folder work. No license, signing secrets, account, application networking, analytics or third-party runtime dependency was added. Main remains unmerged and PR #1 stays draft.

Subsequent documentation-only commits do not change the verified application sources or delivered IPA; this report always refers to the explicit application/delivery commit above.

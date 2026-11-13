# Phase 3 verified checkpoint — 2026-11-12

Application source commit: `122af9cb6928328124009cb225395712b683eeec`.

CI: https://github.com/Cloud9null/Soundly/actions/runs/43258090726

- Xcode 26.3 unsigned generic iOS Release build succeeded.
- 19 core-package tests passed.
- 18 simulator app tests passed: appearance (1), import/persistence (7), offline PCM rendering (4), queue/seek (5), realtime transport (1).
- 1 UI navigation/mini-player/Now Playing test passed.
- Total: **38 tests, zero failures**.
- Offline production-graph PCM tests passed for WAV 16-bit, ALAC 16-bit, FLAC 16-bit/44.1 kHz and FLAC 24-bit/96 kHz.
- Simulator transport test passed preparation without session activation, play-clock advancement, pause, seek, resume and stop.
- Previous reserved hash-property crashes are resolved: import, nested-folder and store-reopen tests now pass. Mini-player UI navigation now passes.

## Device artifact

Artifact: https://github.com/Cloud9null/Soundly/actions/runs/43258090726/artifacts/13963406744

The archive was downloaded and its SHA-256 matched GitHub's reported artifact digest. The contained IPA was inspected: ARM64 Mach-O device executable, iPhoneOS supported platform, bundle `app.soundly.player`, version `0.3.0`, minimum iOS `26.0`, background audio mode present.

- IPA bytes: `403635`
- IPA SHA-256: `0e5d5ce4a56cab51e93215c236bd54c21c377c856421dc8309b3ce8c0013161c`
- Archive SHA-256: `2455bec89f37bb6d57376de84220caa92a7918ba2268f6667b4dd94c438b4dca`

This is an unsigned device build for subsequent signing, not a physically verified iPhone installation. The selected new logo is still pending; this IPA retains the original waveform icon.

## Scope limits and failed optional step

The automatic Home capture failed because Xcode testing used a simulator clone while the requested base simulator was shutdown. Its best-effort step did not fail the successful build/tests/IPA job. There was **no Home PNG** in this artifact, and visual QA is not claimed. The preview script is corrected to boot the base device and explicitly install the compiled simulator app before capture; that ancillary correction still needs its next execution. Application source and the verified IPA are unchanged by this documentation/CI-only correction.

No physical iPhone, audible output, USB DAC, locked-screen/background lifecycle, Bluetooth/AirPlay, full rate/format matrix, energy/performance or external digital-capture result is claimed. Gapless transitions and lock-screen artwork remain pending. All output remains Not Bit-Verified.

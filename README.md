# Soundly

**Your music. Your files. Your sound.**

Native iOS 26+ SwiftUI local music library and player under development. Official repository: Cloud9null/Soundly. Work is on `feat/ios-mvp` in draft PR #1; main is not overwritten or merged automatically.

## Implemented

- Reproducible checked-in Xcode project, Swift 6, user-selected Prism icon and privacy manifest.
- Native Home, Library, Now Playing and Settings; twelve persistent appearance choices and Liquid Glass.
- Offline private-copy Files/folder import, streaming SHA-256 deduplication, cancellation and progress.
- Local SwiftData database without CloudKit; metadata/artwork, search, favorites, albums/artists/folders and local rescan.
- Separate pure domain package and conservative Signal Path evaluator.

Phase 3 adds native file/PCM playback, seek, queue, repeat/shuffle, remote controls, local playback-session restoration and observed audio diagnostics. Physical playback/installation and bit identity remain unverified until tested; source badges describe files, not the DAC. See [audio implementation and test boundaries](Documentation/PHASE-3-AUDIO.md). Gapless transitions are not yet implemented.

Phase 4 connects the canonical Signal Path policy to actual source, decoder, mixer, active-session and route observations. Six native evidence-labelled stages distinguish parsed metadata, reported configuration, inference and unknown physical measurements. Integer/float conversion is disclosed; matching sample rates never grant bit verification. A bounded memory-only route/interruption history contains no track titles or file paths. See [Signal Path implementation](Documentation/PHASE-4-SIGNAL-PATH.md).

See [verification ledger](Documentation/STATUS.md), [architecture](Documentation/ARCHITECTURE.md), [audio validation](Documentation/AUDIO-VERIFICATION.md) and [build instructions](Documentation/BUILDING.md). Always inspect the iOS workflow, not only the core-package check.

## Build

Open `Soundly.xcodeproj`, select the shared Soundly scheme and an iOS 26+ destination, and build using Xcode 26.3. No third-party package installation is needed. Set your own team for device signing. Bundle ID defaults to `app.soundly.player` and can be overridden in Xcode or xcodebuild. No signing secrets are stored.

`python3 Scripts/generate_project.py` regenerates the project deterministically after adding Swift source files. `swift test` runs the separate core package. The macOS iOS workflow builds unsigned arm64 Release, runs simulator app/integration/UI tests, then packages an unsigned IPA only if prior steps pass.

No accounts, application networking, analytics, advertising, external lookups or third-party runtime dependencies. A selected iCloud/File Provider source may need a download during import; completed private copies are offline. Imported copies/database are excluded from device backup: retain original music files.

No project license has been selected. No source or assets copied from referenced products.

## Verified Phase 3 checkpoint

The iOS Release build and all 38 core/app/UI tests passed on application commit `122af9cb6928328124009cb225395712b683eeec`. An unsigned arm64 IPA was generated and inspected. See [verification report](Documentation/PHASE-3-VERIFICATION.md) for the artifact, hashes, test breakdown and unverified physical-device behavior. No gapless or physical bit-perfect claim is made.

## Verified Phase 4 checkpoint

Commit `c4737944a0d5a69f926900786fe905f03f183a0f` passed the unsigned iOS Release build and all **41 core/app/UI tests**. Version **0.4.0 (4)** was packaged as an arm64 device IPA, downloaded, hash-checked and inspected, including its compiled Prism icon. See [Phase 4 verification](Documentation/PHASE-4-VERIFICATION.md) for exact evidence and limitations. The optional Home capture timed out; no running-screen visual QA is claimed. Signing/physical installation, DAC behavior, gapless and external sample identity remain unverified or pending. Use the [device acceptance checklist](Documentation/DEVICE-ACCEPTANCE.md) for testing on real equipment.

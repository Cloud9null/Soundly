# Soundly

**Your music. Your files. Your sound.**

Native iOS 26+ SwiftUI local music library and player under development. Official repository: Cloud9null/Soundly. Work is on `feat/ios-mvp` in draft PR #1; main is not overwritten or merged automatically.

## Implemented

- Reproducible checked-in Xcode project, Swift 6, original icon and privacy manifest.
- Native Home, Library, Now Playing and Settings; six persistent appearance choices and Liquid Glass.
- Offline private-copy Files/folder import, streaming SHA-256 deduplication, cancellation and progress.
- Local SwiftData database without CloudKit; metadata/artwork, search, favorites, albums/artists/folders and local rescan.
- Separate pure domain package and conservative Signal Path evaluator.

**Playback is pending Phase 3.** Selecting a song displays real imported metadata and cover, not simulated playback. No DSP, bit-perfect, output sample-rate or hardware claim is fabricated. Source format labels describe the file only.

See [verification ledger](Documentation/STATUS.md), [architecture](Documentation/ARCHITECTURE.md), [audio validation](Documentation/AUDIO-VERIFICATION.md) and [build instructions](Documentation/BUILDING.md). Always inspect the iOS workflow, not only the core-package check.

## Build

Open `Soundly.xcodeproj`, select the shared Soundly scheme and an iOS 26+ destination, and build using Xcode 26.3. No third-party package installation is needed. Set your own team for device signing. Bundle ID defaults to `app.soundly.player` and can be overridden in Xcode or xcodebuild. No signing secrets are stored.

`python3 Scripts/generate_project.py` regenerates the project deterministically after adding Swift source files. `swift test` runs the separate core package. The macOS iOS workflow builds unsigned arm64 Release, runs simulator app/integration/UI tests, then packages an unsigned IPA only if prior steps pass.

No accounts, application networking, analytics, advertising, external lookups or third-party runtime dependencies. A selected iCloud/File Provider source may need a download during import; completed private copies are offline. Imported copies/database are excluded from device backup: retain original music files.

No project license has been selected. No source or assets copied from referenced products.

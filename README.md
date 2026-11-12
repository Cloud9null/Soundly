# Soundly

**Your music. Your files. Your sound.**

Private, offline, native iOS music player under active development.

## Current milestone — Phase 0

Repository audited and initialized. The first executable code is a dependency-free Swift 6 domain package containing validated PCM metadata, library track values, and a conservative Signal Path evaluator. Nineteen XCTest methods cover misleading verification states, route classification, conversions, unavailable measurements, unsafe paths, and incomplete Unicode metadata.

This is not yet an iOS application. There is no Xcode app target, UI, importer, player, or IPA in this phase. Package compilation and tests must be confirmed by the linked Actions run; source existence does not imply successful execution. See [status](Documentation/STATUS.md).

## Selected implementation

- Deployment target: **iOS 26.0**, native SwiftUI and Liquid Glass.
- Initial CI: **macos-15 / Xcode 26.3**, Swift 6 mode. The workflow records the actual compiler and SDK versions and fails if that Xcode is unavailable.
- Local domain package: `swift test` on a host with Swift 6 or newer.
- Planned app: SwiftUI + SwiftData (local configuration, no CloudKit entitlement).
- Planned audio adapter: AVAudioFile → bounded PCM buffers → AVAudioPlayerNode / AVAudioEngine → AVAudioSession playback. Every observed conversion is disclosed. RemoteIO is a later measured alternative, not an exclusive-DAC promise.
- Zero application networking, accounts, analytics, advertising, cloud sync, or third-party runtime dependencies.

Read [architecture](Documentation/ARCHITECTURE.md), [audit](Documentation/PHASE-0-AUDIT.md), [audio verification](Documentation/AUDIO-VERIFICATION.md), and [build/distribution plan](Documentation/BUILDING.md).

## Repository policy

Work proceeds on `feat/ios-mvp`; `main` received only the minimal initialization needed to create a development branch in an empty repository. Do not merge an unfinished milestone as a release. No license has been selected; no third-party code or visual assets are incorporated.

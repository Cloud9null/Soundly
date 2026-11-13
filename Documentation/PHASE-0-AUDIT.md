# Phase 0 — audit and decisions

Audit date: 2026-11-12. Repository: https://github.com/Cloud9null/Soundly . Personal GitHub connection; private repository; default branch named `main`; push permission available. Initial branches endpoint returned `[]` and contents returned “This repository is empty.” No existing project files or history to preserve. No pre-existing repository AGENTS.md was available; the user's supplied instructions apply.

The execution host is Linux. `git`, `gh`, and Python are installed; `swift` and `xcodebuild` are absent. No macOS host or Apple signing material is available in this session. GitHub macOS CI is the available compilation strategy. No credential is requested or committed.

## Product references and reuse

- [Apple Liquid Glass](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views): use standard SwiftUI navigation and controls; reserve custom glass for floating controls and the mini-player. iOS 26.0 chosen as minimum to avoid imitation glass or a second fallback design. Dynamic Type, VoiceOver, Reduce Motion, and Reduce Transparency must be checked on the actual UI.
- [1-bit](https://1-bit.app/): visual reference for source/decoder/session/route disclosure and compact source-format labels. Its marketing statements are not evidence about Soundly's playback path. No code/assets reused.
- [WaveFlow](https://waveflow.app/) and [repository](https://github.com/InstaZDLL/WaveFlow): inspected repository metadata, LICENSE, library documentation, smart-playlist documentation, and core library domain source. Rust/Tauri/SQLite desktop architecture is not directly portable to SwiftUI/iOS. Useful concepts include explicit unavailable-file records, separate domain/adapters, local rules, and cached artwork. GPL-3.0 source is not incorporated. No Soundly LICENSE is added without owner selection.

## Audio decisions

[Apple QA1631](https://developer.apple.com/library/archive/qa/qa1631/_index.html): preferred rate is a request; inspect actual rate after activation. Reconfiguration can stop/restart I/O, so native-rate changes and gapless transitions across unlike formats need separate policies. Use playback category without optional mixing/ducking; this is not proof of exclusive physical output.

[AVAudioFile](https://developer.apple.com/documentation/avfaudio/avaudiofile) reads decoded PCM buffers. Keep source file format, decoder processing format, engine connection format, and session values distinct. FLAC and ALAC codec identifiers exist in [Core Audio](https://developer.apple.com/documentation/coreaudiotypes/audio-format-identifiers); actual supported files must be probed and tested. A `.m4a` extension does not establish ALAC. Unknown depth stays unknown; compressed ASBD fields must not be blindly treated as PCM bit depth.

Initial implementation choice: AVAudioEngine/AVAudioPlayerNode with bounded background buffer production. This favors controllable queue/seek/background operation with Apple's supported stack. No custom render callback is introduced in Phase 0. Later callback code must not allocate, lock, access disk, or call UI. Integer/float conversion is disclosed conservatively even when it may preserve all source sample values. A lower-level RemoteIO implementation is considered only after measurement identifies a material benefit.

Use currentRoute port names/types/channels only; do not invent USB chip, supported rate lists, effective hardware depth, or negotiated Bluetooth codec. Classic A2DP/HFP is classified as lossy transport. LE/unknown wireless and AirPlay stay unverified without stronger transport evidence. System volume does not by itself disclose the location or arithmetic of downstream gain. Use the system route picker for output selection; there is no generic preferred-USB-output API to invent.

## Files decisions

[Apple directory access](https://developer.apple.com/documentation/uikit/providing-access-to-directories): UIDocumentPickerViewController with `.folder`, scoped URL lifetime, and NSFileCoordinator. MVP copies only selected accessible music to Application Support/Music via temporary staging, content hash, and an atomic final move. Check cancellation between files/chunks; expose progress and per-file failures. Do enumeration, hashing, metadata, artwork, and copy work off the main actor. Skip symlinks and packages; enforce destination confinement. Do not silently delete records after provider or permission failure.

Linked folders are later optional functionality: use iOS-compatible minimal bookmarks as in Apple's directory guide, handle stale bookmarks and revoked access, offer reauthorization. Do not assume macOS `.withSecurityScope` options are available on iOS. No permanent filesystem watcher or background scan is promised. An iCloud/provider source may need network to download during user-selected import; the finished private copy must play offline.

## Build strategy

The [live macos-15 runner manifest](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md) inspected during audit lists `/Applications/Xcode_26.3.app` and iOS 26.2 SDK. Xcode 26.3 is selected explicitly rather than relying on the runner's Xcode 16.4 default. Availability must still be verified by each run. Initial CI tests the package. Phase 1 adds the checked-in Xcode app project and simulator/device build jobs. Only an actual device build can become a sideloadable device IPA; a simulator `.app` cannot.

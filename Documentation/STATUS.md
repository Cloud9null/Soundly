# Verification and phase ledger

## Phase 0 — implementation

- Repository privacy, empty initial state and personal-account access observed through GitHub.
- Minimal initialization commit on main, development branch feat/ios-mvp.
- SDK/deployment/architecture and privacy decisions documented with primary sources.
- Actual Swift 6 package: PCM format validation, track domain model, Signal Path assessment.
- 19 XCTest methods authored. Test success is determined by Actions, not this count.
- macOS CI configured for package compilation/testing and retained logs.

Execution host: Linux; no swift or xcodebuild. Local static checks can validate file structure/YAML and Git diff; they do not compile Swift. Consult the PR's Actions checks for authoritative compiler/test outcome.

## Later phases — not implemented in Phase 0

1. Xcode project, SwiftUI Home/Library/Now Playing, mini-player, themes, icon, native Liquid Glass, accessibility and iOS build CI.
2. SwiftData persistence, coordinated Files/folder import, background scanning/cancellation, metadata/artwork, search, deduplication and rescan.
3. Real codec probing and PCM playback, seek/queue, remote/background controls, interruptions and route changes.
4. Bind actual audio observations to Signal Path UI; no fabricated values.
5. Fixture/decoder/device/integration/UI/performance/accessibility tests; external capture requires equipment.
6. Verified device build, unsigned IPA packaging, installation/signing instructions exercised on iPhone, release/tag only after evidence.

No feature is complete merely because a model or plan exists. There is no current player, app binary, verified bit-perfect route, installation result, or IPA.

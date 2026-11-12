# Build and distribution

## Phase 0

Requires Swift 6+ for the package. On macOS with Xcode 26.3:

```sh
export DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer
xcodebuild -version
swift --version
swift package resolve
swift test
```

The checked-in Actions workflow runs these steps with read-only repository permissions and uploads test logs. It does not build an iOS app yet. On the current Linux execution host, no Swift compiler is installed; no local Swift test result is claimed.

GitHub's account artifact storage quota was reported exhausted during the initial run. Console logs remain the authoritative evidence; a separate log ZIP is best-effort and does not hide failed tests. A future IPA upload requires available artifact storage or another authorized delivery path. No account artifacts are deleted automatically.

## Phase 1 target

Check in a reproducible `Soundly.xcodeproj`, shared scheme, native SwiftUI app target, configurable `PRODUCT_BUNDLE_IDENTIFIER` (initially `app.soundly.player`), iOS 26.0 minimum, Swift 6, privacy manifest, asset catalog and app icon, Info.plist with background audio mode, and no microphone/photo-library permission. No signing team, certificate, profile or Apple ID is committed. CI must first build for simulator and generic iOS device with signing disabled, and run the app's actual tests when targets exist.

## Later device artifact

After a successful generic iOS **device** Release build with `CODE_SIGNING_ALLOWED=NO`, package the built `Soundly.app` under `Payload/Soundly.app` in a ZIP named `Soundly-unsigned.ipa`. Confirm executable is arm64 and bundle contains required resources. This is packaging an unsigned device application, not an Apple-signed export and not proof of installation. Simulator binaries cannot be substituted. Do not rename an empty directory or source ZIP as IPA.

For a signed distribution export, Xcode requires a valid signing identity and appropriate provisioning/export configuration. Keep all signing assets outside Git.

[Sideloadly](https://sideloadly.io/) accepts IPA files and signs/installs using the user's Apple account on their computer. The owner performs account sign-in there; credentials are never supplied to Soundly, GitHub, or this repository. Use the official tool, pair/trust the iPhone, load the generated device IPA, choose the device/account, and follow Apple's device developer/trust prompts where required. Actual unsigned-artifact acceptance and installation still need a device test. Free-account signing generally expires after seven days according to Sideloadly; signing/refresh is separate from offline playback.

No IPA exists in Phase 0. No App Store/TestFlight release or paid account is required for current development. Do not tag a usable release before the MVP acceptance evidence exists.

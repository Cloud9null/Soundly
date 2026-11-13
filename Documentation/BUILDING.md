# Build and distribution

## Requirements

- macOS with Xcode 26.3, including an iOS 26 simulator runtime.
- Swift 6; minimum device OS: iOS 26.0. Linux cannot build the iOS application.
- No third-party runtime packages, account, application server or signing secrets are required to build unsigned.

Open `Soundly.xcodeproj`, select the shared **Soundly** scheme and your destination. The bundle identifier defaults to `app.soundly.player`; override `PRODUCT_BUNDLE_IDENTIFIER` for your own signing configuration. Select your own development team for a signed device build. Never commit certificates, provisioning profiles, Apple account credentials or signing keys.

## Reproduce CI

```sh
export DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer
xcodebuild -version
python3 Scripts/generate_project.py
git diff --exit-code -- Soundly.xcodeproj
swift test
python3 -m unittest discover -s Scripts/tests -v
xcodebuild -project Soundly.xcodeproj -scheme Soundly -configuration Release -destination 'generic/platform=iOS' -derivedDataPath build/device CODE_SIGNING_ALLOWED=NO build
xcrun simctl list devices available
```

Choose an installed iOS 26 iPhone simulator UUID, then run:

```sh
xcodebuild -project Soundly.xcodeproj -scheme Soundly -configuration Debug -destination 'platform=iOS Simulator,id=REPLACE_WITH_UUID' -derivedDataPath build/simulator -resultBundlePath build/Tests.xcresult CODE_SIGNING_ALLOWED=NO test
```

The project generator is deterministic and uses the Python standard library. It includes the canonical `Sources/SoundlyCore` files in the app target; `swift test` separately tests that same domain policy. The first native build phase exports the approved Prism master to the app icon using Apple's `sips`. No image service or network operation is involved.

`.github/workflows/ios.yml` uses the macOS 15 runner and Xcode 26.3. It builds unsigned arm64 Release, runs core, Python PCM negative controls and simulator integration/UI tests, then packages the device IPA only after successful builds/tests. Actual UI screenshots and PCM matrix records are retained as XCTest attachments and exported with xcresulttool under a two-minute limit; no separate simulator boot/install is needed. Test evidence, reference WAVs/PCM manifest and IPA are uploaded as `soundly-ios` with three-day retention. A core-only green check does not establish an iOS build result. Consult the exact verification report/run for the source commit you intend to install; artifact links may expire.

## Unsigned device IPA

After the Release device build and tests succeed:

```sh
mkdir -p build/ipa/Payload
cp -R build/device/Build/Products/Release-iphoneos/Soundly.app build/ipa/Payload/
cd build/ipa
zip -qr ../Soundly-unsigned.ipa Payload
```

This packages an actual device application for later signing; it is not an Apple-signed export or proof of installation. A simulator binary cannot be substituted. A normal signed Xcode archive/export requires a valid signing identity and appropriate provisioning/export configuration; keep those assets outside Git.

## Install using Sideloadly

1. Obtain the official desktop tool from https://sideloadly.io/ on your Windows PC or Mac.
2. Connect your own iPhone and accept its computer trust/pairing prompts.
3. Load the device IPA, select the phone and use your Apple account inside Sideloadly. Do not supply credentials to Soundly, GitHub, this repository or this chat.
4. Follow the tool's current signing/install instructions and the iPhone's developer/trust prompts if required. The selected signing account determines provisioning and refresh requirements; signing is separate from offline playback.
5. For an update, use the same signing account and resulting bundle identifier. Keep your original music files and avoid deleting the existing app, because deleting it removes its private library. Imported copies/database are excluded from device backup.

Unsigned-artifact signing acceptance, physical installation and device playback still require an actual test on your equipment. No TestFlight/App Store release or verified bit-perfect result is implied. Do not tag a usable release until the relevant MVP acceptance evidence exists.

Use [DEVICE-ACCEPTANCE.md](DEVICE-ACCEPTANCE.md) for the concrete installation/import/playback/route checklist and record physical results separately from CI evidence.

Use [PCM-CAPTURE-TOOLS.md](PCM-CAPTURE-TOOLS.md) for offline reference generation/comparison. The Python tools are test infrastructure, not application dependencies, and cannot authenticate a physical digital capture.

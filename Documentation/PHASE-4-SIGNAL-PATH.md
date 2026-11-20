# Phase 4 — live Signal Path and Prism identity

The user selected logo C (Prism). Brand/Prism-master.png preserves that exact approved image. A native Xcode build phase uses Apple's sips to export a 1024×1024 RGB icon without re-generating the mark. The original source image is retained; no cloud/image generation step runs during builds.

## Shared policy, live observations

The app target now compiles the same Sources/SoundlyCore Swift files tested by the standalone package, without a third-party dependency or duplicate policy implementation. SourceFormatInspector inspects the file once when the transport opens it: FLAC STREAMINFO, ALAC ASBD/source-depth flags, or actual linear PCM file description. Source width is never inferred from AVAudioFile's decoder float width. No artwork or full file is loaded by this inspector; FLAC inspection reads only its signature/header and 34-byte STREAMINFO.

Every transport observation constructs a new SignalPathSnapshot from the current source information, decoder processing format, main mixer output format, application gain, active-session rate/channel count, output port type, system volume and I/O buffer duration. No file reads occur in progress polling. Playback replacement clears the UI's observation immediately. Interruption explicitly invalidates session activation; stopped, paused-restored, media-reset and route-refresh states cannot silently retain the previous active route assertion.

SignalPathEvaluator remains the sole assessment policy. Bluetooth A2DP/HFP is lossy transport. Known rate/channel/representation/width changes are converted; integer-to-float conversion is disclosed without claiming it necessarily loses information. Native Sample Rate — Not Bit-Verified requires complete compatible observed formats and a supported single route. AirPlay/LE/multiple/unknown outputs are never granted native/verified status based solely on matching rates. Unknowns remain unknown. Runtime policy cannot produce Verified Bit-Perfect.

## UI and evidence

Source, decoder, engine, session, physical route and assessment are separate native SwiftUI cards. Labels identify file metadata, API observations, inference and unavailable measurements. Session properties are client-facing iOS observations, not a digital capture. The physical DAC bit depth, USB chip and complete supported-rate list are explicitly unavailable. System volume is shown separately and is not equated with verified digital unity gain.

The same report is available from Now Playing and Settings. A bounded 30-event memory-only route/interruption history logs no titles, filenames, paths or personal port names. There is no network diagnostics upload or persistent log. All app files/data remain local.

## Verification scope

Added real FLAC source-depth versus decoder-width integration coverage, port classification including ambiguous multiple outputs, no-observation fallback, and live transport assertions across playback/interruption/stop. UI navigation asserts the Signal Path page and visible status. Existing PCM, library, transport and domain tests remain enabled.

Version 0.4.0 / build 4. Build/test/IPA evidence must come from actual current CI; implementation alone does not prove execution. Physical iPhone/DAC/USB/Bluetooth/AirPlay/background and external capture remain unverified unless separately recorded. See previous phase reports for the earlier verified baseline. Gapless scheduling remains pending.

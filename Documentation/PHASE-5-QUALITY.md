# Phase 5 — automated quality and measurement boundaries

Version 0.5.0 / build 5 retains the approved Prism identity and twelve appearance choices. This phase extends verification rather than adding placeholders for unsupported product features.

## Authored checks

- Handwritten WAV/AIFF integer containers bypass an encoder round-trip as the definition of expected PCM. Two matrix test methods exercise **24 format/depth/rate cases**: WAV and AIFF, 16/24-bit stereo, six rates from 44.1 to 192 kHz. Each compares all 2,048 frames in both channels numerically exactly through the production offline AVAudioEngine graph, including signed limits and low bits. This does not measure AVAudioSession or physical output.
- Existing FLAC and ALAC graph fixtures remain enabled. No blanket format/rate/DAC support is inferred from a filename extension or authored test.
- Boundary tests reject transport path traversal/absolute/backslash names and truncated FLAC STREAMINFO instead of inventing source properties.
- Synthetic **in-memory metadata** stores at 100, 1,000 and 10,000 records exercise count, exact search, favorite filtering and limited sorted fetches. They contain no playable music rows or artwork and are not user-library import, scrolling, launch-time, battery or device benchmarks.
- The mini-player navigation target has a minimum 44-point height and exposes the current title/artist as its VoiceOver value. UI tests check its label, empty-state value and target dimensions and run the system's sufficient-element-description accessibility audit on Home. This is a scoped automated audit, not complete VoiceOver/Dynamic Type/contrast/Reduce Motion approval.
- Actual native UI test screenshots of Home, Library, Settings, empty Now Playing, inactive Signal Path and an unmatched local search are kept in Tests.xcresult and exported by xcresulttool. This replaces the unrelated base-simulator boot/install that previously stalled. Images show real application views with an empty test library; no fictional music catalog or route measurements are inserted. Initial screenshot review found a misleading empty-library/search message and missing Source-card icon; both were corrected, with separate empty/search states and a real-query UI regression.
- The separate Python PCM comparator/reference generator has negative controls for bit changes, channel mapping, gain, clipping, rate/width, resampling, dropped frames, alignment and malformed input. See PCM-CAPTURE-TOOLS.md for commands, format limits, metadata privacy and why PCM equality does not authenticate an external capture.

## Execution evidence

The final revision passed the unsigned iOS Release build and **65 unique tests** with zero failures. See PHASE-5-VERIFICATION.md for the exact source commit/run, 24-case matrix, scoped native screenshot/accessibility review, inspected IPA and remaining limits. The Linux editing host ran the Python suite and independently decoded generated reference WAVs with ffmpeg; actual iOS compilation/execution came from macOS CI.

Physical installation, audible/background/lock-screen behavior, USB/Bluetooth/AirPlay/DAC behavior, full accessibility review, real-library performance/energy and external digital captures still require suitable equipment/data. Gapless transitions and lock-screen artwork remain pending. No hardware results, benchmark numbers or Verified Bit-Perfect status are fabricated, and the complete MVP is not declared finished solely from automated tests.

Apple API references: https://developer.apple.com/documentation/avfaudio/avaudiofile ; https://developer.apple.com/documentation/xctest/xctattachment ; https://developer.apple.com/documentation/xcuiautomation/xcuiaccessibilityaudittype ; https://developer.apple.com/documentation/xcode-release-notes/xcode-16_3-release-notes . The selected runner's xcresulttool help is printed before attachment export so the actually installed command is recorded.

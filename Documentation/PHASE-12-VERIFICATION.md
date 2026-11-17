# Soundly 0.12.0 — verified player and output diagnostics

Verified code: `123728a71a8693f54b1ce8ba9ea512752d2d3e93`.
[Passing macOS iPhone/simulator run](https://github.com/Cloud9null/Soundly/actions/runs/44200295845).

## Delivered behavior

Now Playing removes the volume slider and enclosing playback panel, enlarges the uncropped square artwork, and integrates a source-derived RMS waveform into the seek surface. Progress uses interpolation; the waveform is not a fabricated live spectrum or an output measurement. Off retains a functional simple rail. Wave, Mirror and Bars remain available, including the legacy Orbit alias. Existing palettes plus a free RGB color picker and Artwork/Theme/Aurora/Sunset/Ocean/Rose backdrops persist locally.

The full-height quality sheet now distinguishes source, decoder, graph, output-node input/output PCM, session and destination. The compact source badge uses live file inspection when available. The output comparison prioritizes the separately observed output-node format, with a session fallback when unavailable. A session/node discrepancy is explicit: the simulator reported a 44.1 kHz session and a 48 kHz output interface, so the report correctly shows 44.1 → 48.0 kHz rather than claiming no conversion.

Float32 is labelled as a PCM processing/interface representation, not a physical 32-bit DAC capability. Bluetooth negotiated codec/bitrate and effective physical DAC depth remain unreported rather than guessed from a device name. Existing route-change invalidation, native-rate requests and audio graph behavior are preserved.

## Actual checks

- Unsigned arm64 iPhone Release: passed.
- Swift domain: 33 tests, zero failures.
- App/integration: 54 tests, zero failures.
- Native UI: 9 tests, zero failures.
- PCM reference/comparison tools: 15 tests, zero failures.
- Total: 111 unique automated tests.
- Four real production-graph offline PCM matrices: 48 combinations, zero numerical mismatches. These are offline engine tests, not physical output measurements.
- Native iPhone 17 Pro screenshots reviewed for the light player, dark long-title/source waveform, accessibility2 player, color/background settings, full-height output summary and Lyrics. The exported PNGs include 19 UI screenshots and nine icon previews.
- The enlarged square cover, 44-point controls, footer clearance and seek drag passed. The quality-sheet field is reachable, and Lyrics navigation passed using a settled, bounded native-menu coordinate rather than a missing UIKit activation point.

An earlier run passed all app tests and the new waveform layout, but exposed a medium-sheet visibility assertion and a UIKit menu activation-point failure. Reviewing its native screenshot also caught the session/output-node comparison discrepancy. All are addressed and included in the successful final run.

## Inspected IPA

- Filename: `Soundly-0.12.0.ipa`
- Bytes: 10671325
- SHA-256: `473311003d9fa403238fb76471c50576817ffa3f849dbd4b492c9cf158bc2751`
- Version/build: 0.12.0 (12)
- Bundle identifier: `app.soundly.player`
- Platform: iPhoneOS, arm64 Mach-O, LC_BUILD_VERSION platform 2
- Minimum iOS: 26.0
- ZIP CRC: passed
- Nine alternate icon declarations plus primary Prism: retained
- Provisioning payload, XCTest payloads and DEBUG fixture launch switch: absent

The actual standalone artifact is tied to the verified code SHA above. Re-sign with Sideloadly using the existing Apple account and bundle identifier, installing over the existing app. The library schema is unchanged. Do not uninstall Soundly to update.

## Remaining acceptance boundaries

Installation, physical playback/background/system artwork and each real Bluetooth/USB DAC route require iPhone testing. No physical bit-perfect verification is claimed. Equal rates/depths do not prove equal samples; a specific route requires an external digital capture. Existing gapless/product backlog is unchanged.

[Spanish update guide](0.12-GUIA.md).

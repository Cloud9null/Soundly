# 0.9 Now Playing refinement — verified automated build

Source: 35df22b1fdb5206e346c31f93fccf0d945bfadd8.
CI: https://github.com/Cloud9null/Soundly/actions/runs/43665055034

Responds to device screenshots showing cropped artwork, excess empty spacing and rigid visualization. Now Playing uses top-aligned content and an explicitly square fixed-size artwork button, with aspect-fit image presentation. Artwork sizing reserves space for the optional visualizer and enlarged text retains scroll access. Play/Pause uses a native circular Liquid Glass surface; previous/next sizing and circular secondary selections are more restrained.

The visualizer renders smooth filled Wave/Mirror curves, rounded Bars or Orbit from real decoded source amplitudes. An eight-second window around the playhead averages neighboring envelope bins and uses a square-root display scale. Mint/Rose/Ocean/Amber/Rainbow gradients are available from the display menu or Now Playing → More → Visualizer, including when Off. Style/color changes reuse analyzed samples. Refresh interpolation follows the playback clock, stops on pause and is disabled with Reduce Motion. This is an amplitude envelope before DSP, not an FFT, random animation or DAC/output measurement. No audio-engine processing is changed. Off remains default.

## Executed checks

Xcode 26.3 unsigned iPhone Release succeeded, along with 97 unique tests: 25 domain, 48 app/integration, 9 native UI and 15 Python. The native long-title/enabled-waveform case verifies square artwork below the header, reachable controls and the glass footer. Existing artwork callbacks, EQ/integrity, PCM matrices, duplicate cleanup, library, playlists, lyrics and navigation regressions passed their scoped checks. DEBUG-only visual fixtures contain actual varying-amplitude PCM; production visualization does not invent signal data.

Earlier executions exposed UI-test timing issues when mini-player content changes and when Settings row coordinates vary by subpoint glass/AX transforms. Tests now wait for selected mini-player content and use a half-point stationarity tolerance with a bounded wait. The final whole-suite run passed; failed attempts did not package a delivery IPA.

Player, long-title/waveform and accessibility-size snapshots from preceding attempts with the same production UI code were visually reviewed. The final native visual regression passed. Final archive bytes, final screenshots and IPA internals were not downloaded or locally inspected: the session's execution environment became unavailable after those earlier visual reviews. No local SHA-256 or physical installation claim is made.

## Actual distribution artifact

https://github.com/Cloud9null/Soundly/actions/runs/43665055034/artifacts/14142327680

GitHub confirms that the packaging step created Soundly-unsigned.ipa from Release-iphoneos/Soundly.app and successfully uploaded soundly-ios.zip (99705943 bytes). Reported archive SHA-256: 4140a973a808296044430b8db4df44d8497e79d013f47d20dd5b1c6a8d19185b. This is GitHub's reported upload digest, not a locally recomputed digest. Artifact retention ends 2026-11-18T02:10:05Z.

Download the artifact ZIP and extract Soundly-unsigned.ipa, then sign using Sideloadly. Version is 0.9.0/build 9, with the existing bundle ID, library schema, themes and icons preserved. See 0.9-GUIA.md. Physical iPhone rendering/energy, Lock Screen, routes/DAC and external sample identity remain manual acceptance. No Verified Bit-Perfect claim is introduced. Main remains unmerged; PR #1 stays draft.

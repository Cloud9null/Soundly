# 0.10 UI integration and S icons — verified automated preview

Integrates the full-source PCM waveform into the seek surface within a native glass playback deck. The full-track envelope is reduced to display bins with square-root amplitude scaling, played/unplayed coloring and a compact position dot; drag-to-seek and five-second accessibility adjustment are implemented. Waveform analysis remains on a cancellable worker; no audio processing or render callback changes. Off retains a functional seek rail. Legacy Orbit renders as Bars in the integrated rail. Separate live-window visualization/timeline and its on-screen technical caption are removed.

Library removes the centered Songs/Playlists/Smart Playlists stack. A toolbar Browse library menu contains category selection and collection navigation; song rows use two-line metadata and missing-file status. Populated Home uses a compact header. The underlying library/query/playlist models remain unchanged.

Adds six original Core Graphics S icons: Signature, Glacier, Midnight, NeonS, Circuit, Hologram. Existing Prism/Aurora/Pulse/Orbit remain. Asset manifests, generator build paths, alternate icon configuration, selector and packaged-image tests cover all nine alternatives. Native icon image attachments support visual review; physical SpringBoard switching remains a device check.

Native tests are updated for collection-menu navigation and integrated waveform geometry/actual seek. A separate small soundly-ipa artifact is uploaded after device compilation, independently of later test evidence; its availability alone does not establish test success. Record actual results and inspected artifact hashes below after execution.

## Executed verification — 2026-11-15

Application/test/build source: d300c9bf1a61b082467dd0de2005de9d63ab7f7f.
CI: https://github.com/Cloud9null/Soundly/actions/runs/43695990300 . Xcode 26.3 unsigned iPhone Release and 97 unique tests passed: 25 domain, 48 app/integration, 9 native UI, 15 Python. The integrated waveform test performs an actual paused seek by dragging and verifies the observed playback position, deck containment, square artwork and reachable controls. Collection-menu playlist navigation and all nine packaged alternate icon/previews passed.

Downloaded final test evidence contains 27 PNG attachments and four offline PCM records. All 48 direct/mixer WAV/AIFF PCM16/24 stereo cases through 192 kHz had zero numerical mismatches; these are cases within existing tests, not additional tests or physical DAC captures. The final integrated waveform screenshot was inspected after correcting adaptive rail/playhead contrast. Library, enlarged-text player and all six new S/cyber icon images from the preceding matching layout/asset code were visually reviewed. Physical icon switching, provider/accessibility/energy and device/DAC acceptance remain manual checks. Simulator system volume does not demonstrate physical volume presentation.

Earlier UI automation encountered a transient infinite mini-player accessibility frame. The test now requires finite in-window coordinates and taps using a stable window anchor. The final whole-suite run passed. This does not assert a physical-device result.

Standalone IPA artifact: https://github.com/Cloud9null/Soundly/actions/runs/43695990300/artifacts/14154845589 . Actual archive SHA-256 was recomputed and matched b129ec78652858c80af45be893fa954b1791cc606d84e2f8176ee934a763c30f. Test evidence artifact: https://github.com/Cloud9null/Soundly/actions/runs/43695990300/artifacts/14154771895 ; its downloaded digest matched 923cac3e3ec9ec6f819dd69f45799edf55d4753ada01ef85caa3faeaffafdd4e. Artifact retention is three days.

Inspected IPA: Soundly-0.10.0-Prism-unsigned.ipa, 10,594,221 bytes, SHA-256 2bc7b3b9d74600475fddf9ebfe78fee2d28c4d6021c44dcdab601767bc946a93. ZIP integrity, arm64 Mach-O executable/iOS platform 2, SDK 26.2, minimum iOS 26.0, version 0.10.0/build 10, app.soundly.player, background audio and all nine alternate-icon declarations were checked. XCTest/provisioning payloads and actual DEBUG fixture/launch markers were absent. The actual standalone IPA was saved for personal Sideloadly delivery. No signing secrets, physical installation or Verified Bit-Perfect result are claimed.

The audio graph and library schema are unchanged. Main stays unmerged and PR #1 stays draft. Documentation-only follow-up preserves verified application/test/build/brand inputs. See 0.10-GUIA.md for the moved Library controls, waveform preferences and icon selection.

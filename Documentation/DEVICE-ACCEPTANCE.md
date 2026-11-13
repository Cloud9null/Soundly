# Physical-device acceptance checklist

This is a test procedure, not a record of passing results. Simulator and offline graph tests do not establish audible output, background lifecycle, device signing or DAC behavior.

## Before testing

Install the unsigned device IPA using your own signing configuration/Sideloadly as described in BUILDING.md. Keep original music files. Update with the same signing account and resulting bundle identifier; deleting the app deletes its private library. Record Soundly version/build, application commit, iPhone model, iOS version and the route or DAC model manually when known. Do not record Apple account credentials, device serial numbers or music filenames in public issue reports.

Use small self-created/reference WAV, ALAC and FLAC files initially. The automated fixtures cover WAV/ALAC 16-bit and FLAC 16-bit/44.1 kHz and 24-bit/96 kHz; that does not establish support for every file or physical rate. Keep a second track with a different rate to exercise reconfiguration.

| Test | Procedure and expected behavior | Evidence to record |
| --- | --- | --- |
| Fresh offline launch | Launch in airplane mode before importing. Home, Library and Settings open without an account or network requirement. | App version, visible errors |
| Import and duplicates | Add Music → select local files or a folder. Reimport identical files. Complete files remain registered once; duplicate counters increase. | Imported/duplicate/error counters |
| Cancellation | Cancel a larger folder import. Previously completed tracks remain available; incomplete work is not registered as playable. | Counters and remaining library |
| Offline persistence | After successful import, enable airplane mode and relaunch. Play an imported track whose original was in a provider; the private copy should be sufficient. | Track duration, playback continuity |
| Transport | Play, pause, seek forward/back, resume, stop and select next/previous. Check elapsed time, repeat/shuffle state and queue selection. | Actions that fail and observed timing |
| Paused restore | Relaunch after pausing in a track. The queue/position should restore paused; audio session activation should wait for Play. | Restored position and report status |
| Background and lock screen | Begin playback, lock the phone, then use system pause/play/seek and track controls. Verify audible continuity. | Exact action, app state, interruption |
| Interruption | Exercise a real system interruption, then end it. Resume should follow system permission and prior playing state; no stale active-session proof should remain. | Resume behavior and route events |
| USB/headphones | Connect a known compatible route, then start a reference track. Observe the actual session rate/channels. Disconnect while playing; playback should pause to avoid unexpectedly continuing on the speaker. | Requested/source rate, observed rate, route |
| Bluetooth/AirPlay | Switch routes using system controls. A2DP/HFP must report Lossy Transport. Other unverifiable transports must never report Verified Bit-Perfect. Known conversions may still be disclosed. | Exposed port type and assessment reason |
| Theme/accessibility | Select the twelve themes, relaunch, increase Dynamic Type, enable VoiceOver and Reduce Motion. Check controls remain reachable and readable. | Theme, text size, failing control |

## Reading Signal Path correctly

Open Signal Path from Now Playing or Settings. The source format is parsed from the file; decoder and mixer formats come from AVFoundation. Session sample rate/channels, volume and port names are API observations, not a digital output capture. Inactive or unavailable observations should stay unknown. System volume does not prove downstream unity digital gain.

With integer source files, the AVAudioFile processing format may be Float32. The conservative status can therefore say **Converted / Resampled** even if source/session rates match. Read the reason: a representation/width change does not itself prove resampling or loss of information. No current runtime status can grant Verified Bit-Perfect. Effective physical DAC bit depth, USB chip and complete supported-rate list remain unknown unless independently measured.

For actual sample identity, follow AUDIO-VERIFICATION.md: capture digital output with suitable hardware, align without normalization/resampling, and compare decoded PCM samples. An analog recording, compressed FLAC hash, matching rates or an audible listening test is insufficient. Record results only for the exact tested configuration.

# Phase 3 — playback implementation and evidence boundaries

## Implemented control and audio path

`PlaybackController` is the observable main-actor presentation/system integration layer. `PlaybackQueue` is a separately testable value. `AudioTransport` is an actor owning AVAudioEngine, AVAudioPlayerNode and AVAudioFile; files and native audio objects do not escape across actors. The controller serializes commands and uses revision tokens so older completions cannot overwrite a newer request. The transport invalidates native completion notifications across stop, seek and replacement with a generation counter.

Playback uses AVAudioFile decoded PCM scheduled with AVAudioPlayerNode.scheduleSegment and dataPlayedBack completion semantics. Apple's decoder/scheduling workers handle file reads; the app does not decode entire tracks into memory or add a custom real-time render callback. Oversized segments are split at UInt32 frame limits; neither those boundaries nor track transitions are claimed gapless. A shared PCMGraph builds player → main mixer → output at unity application gain. Apple's main mixer is explicitly disclosed; this is not an exclusive DAC implementation.

Implemented: play, pause, stop, seek, next/previous, queue selection, shuffle avoiding immediate repetition when alternatives exist, repeat one/all/off, local queue/position persistence and paused restoration after relaunch. Pause records the frame and reschedules on resume. Repeat one applies to automatic completion; an explicit Next still advances. Natural queue completion stops unless repeat applies. No EQ, ReplayGain, normalization, time stretch or crossfade.

Configure playback category without optional mixing or ducking, request source rate while session is inactive, then activate and read the actual session. Source/decoder/mixer/session properties remain separate. Remote play/pause/toggle/stop/next/previous/seek use MPRemoteCommandCenter and route to the serialized controller. MPNowPlayingInfoCenter receives local metadata, duration, elapsed time and playback rate; ExcludeFromSuggestions is set to opt out of media suggestions. iOS 26 is the target; the newer NowPlaying framework is not mixed with these APIs.

## Route and lifecycle behavior

Route changes rebuild from the observed position. Unplugging an output pauses rather than deliberately starting built-in speaker playback. Route changes during an operation are deferred; self-induced category changes are ignored. Session interruptions remember whether playback was active and resume only with the system's shouldResume flag, unless the user paused/stopped meanwhile. Media-services reset rebuilds the engine and restores paused; engine configuration changes outside the reconfiguration suppression window rebuild the graph. Real hardware testing is required for timing/race behavior under USB/Bluetooth/AirPlay changes.

The main polling loop runs only after selection/restoration, uses a slower cadence while paused, and updates lock-screen metadata on integer seconds/state/track changes. Rejected native-rate requests retain playback at the effective session rate and produce an explicit diagnostic note.

Background audio is configured via playback session and UIBackgroundModes audio. This is implementation, not a claim of a physical screen-locked playback test.

## Honest diagnostics

The file badge describes source metadata. Diagnostics show decoder PCM representation/rate/channels, main mixer output rate, API-reported active session rate/channels and iOS-exposed route port names/types. There is no DAC chip, hardware bit-depth or negotiated Bluetooth codec guess. Bluetooth A2DP/HFP receives a lossy transport warning. Every route remains Not Bit-Verified. Equal rates, offline render equality and source hashes do not prove a physical route.

## Test coverage and limitations

Added queue tests for automatic repeat-one versus explicit Next, repeat-all wrapping, empty/persisted queue, shuffle non-repetition, and invalid/large seek positions. Added WAV 16-bit, ALAC 16-bit, FLAC 16-bit/44.1 kHz and FLAC 24-bit/96 kHz fixtures that decode and pass through the actual PCMGraph in AVAudioEngine offline manual rendering, checking channels and sample values. The synthetic FLAC fixtures are reproducible with Scripts/generate_audio_fixtures.py; ffmpeg is used only at fixture generation, not in the app. Their canonical decoded signed little-endian PCM hashes are recorded separately from compressed bytes and compared to the generated source during generation. These are authored iOS tests; consult the Actions run to determine their execution result. They do not capture the system output. A separate simulator-route test exercises transport clock advancement, pause, seek, resume and stop; its result is distinct from an audible or physical bit-identity test.

Existing 19 domain tests remain separate from app tests. Library import, persistent-store reopen, malformed files, cancellation, source FLAC depth/Unicode and navigation tests remain enabled. No physical iPhone/DAC, background/remote-control, FLAC/AIFF playback matrix, rate matrix, long-file, energy or external bit-perfect capture result is claimed without corresponding evidence.

Gapless compatible-track scheduling, lock-screen artwork, queue reordering/removal, full evidence-bound Signal Path UI and broader audio fixtures remain future work. Artwork remains visible in the app; lock-screen metadata currently includes text/timing only.

## Themes and logo options

Twelve persistent themes: System, Light, Dark, OLED, Ocean, Sunset, Amethyst, Forest, Rose, Graphite, Ivory and Midnight. Colored themes define both surface and accent. No custom animation overrides Reduce Motion; decorative artwork backgrounds respect Reduce Transparency. Contrast and accessibility need device/visual review.

Logo proposals are preview-only until the owner chooses a primary. The existing app icon is preserved. No generated candidate is silently installed or copied into the app target.

## Primary references

- https://developer.apple.com/documentation/avfaudio/avaudioplayernode/schedulesegment(_:startingframe:framecount:at:completioncallbacktype:completionhandler:)
- https://developer.apple.com/library/archive/qa/qa1631/_index.html
- https://developer.apple.com/documentation/avfaudio/performing-offline-audio-processing
- https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter
- https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfopropertyexcludefromsuggestions
- https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification

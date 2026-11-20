# Architecture decision record 001

Status: accepted for implementation; components below are planned unless listed in STATUS.md.

## Boundaries

`Sources/SoundlyCore` is an independent Swift 6 package. Validated PCMFormat, Track, SignalPathSnapshot, and the pure evaluator are implemented. The package neither imports SwiftUI/AVFoundation nor reads files, databases, or the network. Value types are Sendable. No global dependency container.

The upcoming Xcode app target resides in `Soundly/`: `App/`, `Core/Audio/`, `Core/Decoders/`, `Core/Library/`, `Core/Metadata/`, `Core/Storage/`, `Features/`, `DesignSystem/`, and `Resources/`. It consumes the root package as a local dependency. Do not include package tests in the app target.

App composition creates LibraryRepository, ImportCoordinator, MetadataReader, AudioPlaybackController, RouteMonitor, and artwork cache adapters. Views receive observable main-actor presentation state and actions, not database contexts or audio objects. Protocols are introduced at these testable I/O boundaries when their adapters are implemented. No empty service stubs posing as completed features.

## Local data

SwiftData local-only ModelContainer (no CloudKit configuration) stores persistent models separately from domain values. Serial ModelActor repository owns writes, pagination, indexed search and migration. Application Support/Music holds imported UUID-named files. Persist relative names only. Imported bytes receive a streaming SHA-256 for deduplication; identical tags/names do not imply identical content. Import staging prevents half-copied files being registered. Byte-identical duplicate detection is distinct from audio-content equivalence.

Artwork is bounded/downsampled on a worker before caching; full embedded artwork must not be loaded on every row render. Derived cache lives under Caches; originals/database/music use appropriate data protection with availability after first unlock to support screen-locked background audio. Exclude recoverable imported music/artwork from system backup by default and disclose this in settings. File protection is not a separately encrypted music vault.

Track metadata represents all requested MVP fields; genres can be multiple. Add disk persistence/migrations during Phase 2 rather than making unvalidated synthesized decoding bypass value validation. Preserve raw metadata and display fallback labels without corrupting Unicode.

## Playback concurrency

One serialized controller owns AVAudioEngine and queue generation. Decoder worker reads bounded PCM buffers outside realtime rendering. Stale completions carry generation tokens and cannot advance a replaced queue after seek/stop. Seek invalidates scheduled buffers and reschedules from the requested frame. UI receives throttled state, not render callbacks.

Configure AVAudioSession playback, request source rate, activate, then inspect effective session and engine formats. Route/configuration changes invalidate snapshots, pause safely on disconnection, and rebuild the graph off the render callback. Interruptions resume only when allowed and only if previously playing. Handle media-services reset by rebuilding objects. Lock-screen metadata and MPRemoteCommandCenter commands dispatch into the same serialized controller.

Gapless is a later acceptance gate using adjacent scheduling for compatible format/rate. Unlike-rate transitions may reconfigure I/O and must not be called gapless. ReplayGain, EQ, AutoMix and crossfade are disabled/unimplemented initially; never offer an enabled no-op setting. Future processing must change Signal Path assessment.

## Evidence policy

File parsing establishes source properties, decoder/engine inspection establishes client PCM formats, AVAudioSession supplies active session/route observations, and external capture establishes only a specifically documented experimental result. Do not substitute one for another.

SignalPathEvaluator can return native-rate/unverified, converted, lossy transport, or unknown. It cannot return verifiedBitPerfect. That enum case is reserved for a future evidence-bound mechanism, not a toggle or hash of imported bytes. Any future digital-capture result is scoped to the tested file, route, device, iOS, gain, channel layout and engine build; it does not certify arbitrary later playback.

## Extensions

Local smart-playlist rules query repository fields; no remote service is needed. LRC parser and embedded lyrics are separate worker services. AutoMix and analysis are opt-in later modules, outside realtime threads, mutually incompatible with an unmodified-signal claim. No NAS/network dependencies are added in the MVP.

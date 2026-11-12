# Audio validation plan

Current evidence: domain-policy tests only, pending/subject to the Actions result. No decoder, playback, external loopback, DAC or iPhone measurements exist yet.

## Automated fixtures, Phase 3–5

Generate deterministic original integer PCM (16/24-bit; 44.1/48/88.2/96/176.4/192 kHz) with impulses on separate channels, silence, low-level bit patterns, signed boundaries, a sweep and a clipping-adjacent sequence. Generate WAV/AIFF and encode FLAC/ALAC losslessly with recorded encoder versions. Keep generator seed, frame count and canonical interleaved signed little-endian decoded-PCM SHA-256. Distinguish storage width/sign extension from valid bit depth. Never compare compressed file hashes to device output.

Decode each fixture and compare the canonical PCM before playback; record processing format and any conversion. Seek at deterministic frame positions, cancel/import malformed files, and exercise interrupted decode. Test corrupt/truncated files without registering playable library entries. Format/rate claims are per fixture and route, not extension-based blanket support.

## External capture, hardware required

Record iPhone model, iOS version, Soundly commit, DAC/interface model exposed or manually provided by the tester, cable/route, source/decoder/engine/session formats, application gain, system volume, output routing and DSP settings. Capture digital output with hardware capable of observing the tested signal. An analog recording cannot prove digital bit identity.

Capture a synchronization prefix, align at whole-sample boundaries, preserve channel order and valid-bit sign convention. Compare every sample across the test window after alignment. Do not normalize, resample, dither, apply gain or time-stretch captured audio to force agreement. Report mismatch count, first mismatch, per-channel peaks, clipping, gain ratio, drift and frame count; use cross-correlation only to find alignment. Test different volumes and channel-specific impulses. Include deliberate resampling and channel-swap controls to prove the comparator detects failures. Exact equality demonstrates only the recorded test configuration.

Until this procedure is implemented and passes on real hardware, the runtime must show **Not Bit-Verified** even at matching rates. Route, track, build, gain or DSP changes invalidate earlier observations.

## Device acceptance

Airplane-mode first launch, import then reboot/relaunch, missing providers, background/lock-screen playback, remote commands, interruptions, unplugged USB/headphones, Bluetooth, AirPlay, media services reset, rapidly changing queue/seek, and memory-pressure artwork handling need device tests. Schedule same-rate adjacent fixtures to measure gapless discontinuities. Measure 100/1,000/10,000-track startup, search, scroll, import throughput, memory and energy using reproducible fixture libraries; no benchmark numbers exist yet.

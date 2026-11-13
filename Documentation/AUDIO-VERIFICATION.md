# Audio validation plan

Automated evidence now includes domain policy, actual offline production-graph rendering for WAV/ALAC and FLAC 16-bit/44.1 kHz and 24-bit/96 kHz, plus simulator transport/lifecycle assertions. See PHASE-3-VERIFICATION.md and the current phase report for exact source commits, test counts and CI results. These tests do not establish physical iPhone, external digital loopback, USB DAC, background or bit-perfect behavior. The wider matrix below remains a validation plan rather than a tested support claim.

## Automated fixtures, Phase 3–5

Executable offline reference/comparison infrastructure is now in Scripts/audio_reference.py. See PCM-CAPTURE-TOOLS.md for commands and PHASE-5-QUALITY.md for matrix, negative-control and scope details. Consult PHASE-5-VERIFICATION.md only for results actually executed on its explicit commit; implementation alone is not evidence of device support.

Generate deterministic original integer PCM (16/24-bit; 44.1/48/88.2/96/176.4/192 kHz) with impulses on separate channels, silence, low-level bit patterns, signed boundaries, a sweep and a clipping-adjacent sequence. Generate WAV/AIFF and encode FLAC/ALAC losslessly with recorded encoder versions. Keep generator seed, frame count and canonical interleaved signed little-endian decoded-PCM SHA-256. Distinguish storage width/sign extension from valid bit depth. Never compare compressed file hashes to device output.

Decode each fixture and compare the canonical PCM before playback; record processing format and any conversion. Seek at deterministic frame positions, cancel/import malformed files, and exercise interrupted decode. Test corrupt/truncated files without registering playable library entries. Format/rate claims are per fixture and route, not extension-based blanket support.

## External capture, hardware required

Record iPhone model, iOS version, Soundly commit, DAC/interface model exposed or manually provided by the tester, cable/route, source/decoder/engine/session formats, application gain, system volume, output routing and DSP settings. Capture digital output with hardware capable of observing the tested signal. An analog recording cannot prove digital bit identity.

Capture a synchronization prefix, align at whole-sample boundaries, preserve channel order and valid-bit sign convention. Compare every sample across the test window after alignment. Do not normalize, resample, dither, apply gain or time-stretch captured audio to force agreement. Report mismatch count, first mismatch, per-channel peaks, clipping, gain ratio, drift and frame count; use cross-correlation only to find alignment. Test different volumes and channel-specific impulses. Include deliberate resampling and channel-swap controls to prove the comparator detects failures. Exact equality demonstrates only the recorded test configuration.

Until this procedure is implemented and passes on real hardware, the runtime must show **Not Bit-Verified** even at matching rates. Route, track, build, gain or DSP changes invalidate earlier observations.

## Device acceptance

Airplane-mode first launch, import then reboot/relaunch, missing providers, background/lock-screen playback, remote commands, interruptions, unplugged USB/headphones, Bluetooth, AirPlay, media services reset, rapidly changing queue/seek, and memory-pressure artwork handling need device tests. Schedule same-rate adjacent fixtures to measure gapless discontinuities. Measure 100/1,000/10,000-track startup, search, scroll, import throughput, memory and energy using reproducible fixture libraries; no benchmark numbers exist yet.

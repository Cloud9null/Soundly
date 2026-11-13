# Offline PCM reference and digital-capture comparison

`Scripts/audio_reference.py` is a local, standard-library-only Python tool. It is not part of the iOS render path, makes no network calls and never grants Verified Bit-Perfect. Generated references are original test data, not commercial music.

## Generate references

```sh
python3 Scripts/audio_reference.py generate reference-pcm
python3 -m unittest discover -s Scripts/tests -v
```

This produces twelve classic integer WAV files: 16/24-bit stereo at 44.1, 48, 88.2, 96, 176.4 and 192 kHz. Each contains 4,096 frames of deterministic channel-specific signed boundaries, low-bit patterns, silence and nonperiodic data. `manifest.json` records SHA-256 of the **decoded, interleaved signed little-endian PCM bytes**, not of a WAV/FLAC container. File duration therefore varies with rate. These short fixtures test sample integrity, not long-term clock stability or real-library performance.

The references contain full-scale impulses and wideband patterns. Use a digital capture path, rather than listening through speakers/headphones. A physical capture requires equipment capable of observing the tested digital output; analog recordings cannot establish digital bit identity. The CI artifact includes the generated references and manifest for reproducible testing. They are not added to the app's library or Release bundle.

## Compare an externally captured window

Export source and capture as classic integer PCM16/24 little-endian WAV with the same actual rate, valid bit depth and channel order. The tool deliberately rejects float, 32-bit, WAVE_FORMAT_EXTENSIBLE and ambiguous valid-bit layouts; do not silently truncate, normalize, resample or dither to force compatibility.

```sh
python3 Scripts/audio_reference.py compare reference-pcm/pcm24-96000-stereo.wav digital-capture.wav --capture-offset-frames 1200 --metadata equipment.json --report result.json
```

The offset is measured in **whole interleaved frames**, not bytes or individual channel samples. The comparator requires enough capture data for the entire source; it does not call a partial overlap a pass. Leading capture latency and trailing samples outside the comparison window are excluded and are not verified. Source/capture format mismatches fail before sample comparison.

When the unchanged initial 256-frame anchor is unique within a known latency range:

```sh
python3 Scripts/audio_reference.py compare reference-pcm/pcm24-96000-stereo.wav digital-capture.wav --auto-align-max-frames 48000 --report result.json
```

Missing or repeated anchors fail alignment. There is no correlation-based gain adjustment, sample-rate conversion, channel swapping or time stretching. If processing altered the anchor, use a separately established manual offset and inspect the mismatches; do not transform data to obtain equality.

Reports include complete-source frame coverage, canonical source/capture-window PCM hashes, mismatched samples/frames, first differing frame/channel, per-channel peaks, full-scale sample counts and a least-squares gain estimate. Extra rail samples indicate **possible** clipping, not a diagnosis. A rate mismatch is reported explicitly; sample differences at equal rates do not identify their cause automatically. Dropped/duplicated samples or clock drift may cause mismatches; this tool does not estimate or repair a drift curve.

Exit codes: `0` PCM window equal; `1` mismatch/incompatible format/incomplete capture/alignment failure; `2` invalid input or I/O error. Input WAVs are limited to 64 MiB each; metadata JSON to 64 KiB. This is a bounded offline reference-window tool, not a whole-library analyzer.

## Equipment record and privacy

Optional metadata uses only these keys:

```json
{
  "iphone_model": "<tested model>",
  "ios_version": "<tested version>",
  "dac": "<model supplied by tester>",
  "route": "<observed route>",
  "soundly_commit": "<tested application commit>",
  "application_gain": 1,
  "system_volume": "<observed value>",
  "capture_method": "<actual digital capture procedure>"
}
```

These are placeholders, not measurements. Do not include account credentials, serial numbers, personal track names or medical information. Other metadata keys are discarded; source/capture filenames are not emitted in the normal JSON report. Nothing uploads automatically.

`pcm_equal` demonstrates equality only of the supplied PCM window. The tool cannot authenticate the capture equipment, provenance, iPhone, DAC or route. Its `bit_perfect_verified` field therefore remains **false**, including when comparing a file with itself. The app does not import this JSON as a physical-verification entitlement. Keep the complete independent capture procedure and evidence with the equipment-specific result, and invalidate conclusions after changes to route, build, DSP, rate or gain.

## Automated negative controls

Tests deliberately change a least-significant bit, swap channels, halve gain, add full-scale samples, change rate/width, downsample and repeat at unchanged reported rate, drop a frame, truncate a container and use ambiguous silence for alignment. All must fail equality appropriately. A separate test changes container metadata while preserving PCM, proving that compressed/container file hashes are unsuitable output-identity evidence.

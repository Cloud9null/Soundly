"""Offline PCM reference generation/comparison. Standard library only; never grants DAC verification."""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import struct
import sys
import wave

RATES = (44100, 48000, 88200, 96000, 176400, 192000)
MAX_BYTES = 64 * 1024 * 1024  # Short reference windows, not unbounded music analysis.


@dataclass(frozen=True)
class PCM:
    rate: int
    channels: int
    bits: int
    data: bytes

    @property
    def stride(self): return self.channels * (self.bits // 8)

    @property
    def frames(self): return len(self.data) // self.stride

    @property
    def digest(self): return hashlib.sha256(self.data).hexdigest()

    @classmethod
    def read(cls, path):
        with Path(path).open('rb') as stream:
            blob = stream.read(MAX_BYTES + 1)
        if len(blob) > MAX_BYTES: raise ValueError('Reference WAV exceeds the 64 MiB limit')
        if len(blob) < 12 or blob[:4] != b'RIFF' or blob[8:12] != b'WAVE':
            raise ValueError('Only little-endian RIFF/WAVE integer PCM is supported')
        if struct.unpack_from('<I', blob, 4)[0] + 8 != len(blob):
            raise ValueError('Truncated or inconsistent RIFF size')
        offset, fmt, raw = 12, None, None
        while offset < len(blob):
            if offset + 8 > len(blob): raise ValueError('Truncated chunk header')
            tag, size = struct.unpack_from('<4sI', blob, offset)
            start = offset + 8
            if start + size > len(blob): raise ValueError('Truncated chunk')
            payload = blob[start:start + size]
            if tag == b'fmt ':
                if fmt is not None or size < 16: raise ValueError('Invalid/duplicate format chunk')
                fmt = struct.unpack_from('<HHIIHH', payload)
            elif tag == b'data':
                if raw is not None: raise ValueError('Multiple data chunks are not supported')
                raw = payload
            offset = start + size + (size & 1)
        if offset != len(blob) or fmt is None or raw is None: raise ValueError('Incomplete WAV')
        tag, channels, rate, byte_rate, align, bits = fmt
        if tag != 1 or bits not in (16, 24) or not 1 <= channels <= 8 or not 0 < rate <= 384000:
            raise ValueError('Require classic signed integer PCM16/24; float/extensible/32-bit need explicit canonicalization')
        if align != channels * (bits // 8) or byte_rate != rate * align or not raw or len(raw) % align:
            raise ValueError('Invalid PCM layout or empty/incomplete frames')
        return cls(rate, channels, bits, raw)

    def write(self, path):
        with wave.open(str(path), 'wb') as output:
            output.setparams((self.channels, self.bits // 8, self.rate, 0, 'NONE', 'not compressed'))
            output.writeframes(self.data)


def reference(bits=24, rate=96000, frames=4096):
    """Deterministic channel-specific boundaries, low bits, silence and nonperiodic PCM."""
    if bits not in (16, 24) or frames < 256: raise ValueError('Use PCM16/24 and at least 256 frames')
    scale, state = 1 << (bits - 1), 0x534E444C
    edges = (0, 1, -1, scale - 1, -scale, scale - 2, 1 - scale, 0)
    raw = bytearray()
    for i in range(frames):
        for channel in range(2):
            state ^= (state << 13) & 0xffffffff
            state ^= state >> 17
            state ^= (state << 5) & 0xffffffff
            state &= 0xffffffff
            value = edges[(i + 3 * channel) % len(edges)] if i < 8 else state % (2 * scale) - scale
            raw.extend(value.to_bytes(bits // 8, 'little', signed=True))
    return PCM(rate, 2, bits, bytes(raw))


def generate(directory):
    directory = Path(directory); directory.mkdir(parents=True, exist_ok=True)
    entries = []
    for bits in (16, 24):
        for rate in RATES:
            pcm = reference(bits, rate)
            name = f'pcm{bits}-{rate}-stereo.wav'
            pcm.write(directory / name)
            entries.append(dict(file=name, bits=bits, rate=rate, channels=2, frames=pcm.frames,
                                decoded_pcm_sha256=pcm.digest, canonical='interleaved signed little-endian integer PCM'))
    (directory / 'manifest.json').write_text(json.dumps(entries, indent=2) + '\n')
    return entries


def compare(source, capture, offset=0, auto_max=None):
    report = dict(bit_perfect_verified=False, scope='PCM window only; capture provenance and physical route are not validated',
                  source_pcm_sha256=source.digest, source_frames=source.frames, capture_frames=capture.frames,
                  source_format=dict(rate=source.rate, channels=source.channels, bits=source.bits),
                  capture_format=dict(rate=capture.rate, channels=capture.channels, bits=capture.bits))
    if (source.rate, source.channels, source.bits) != (capture.rate, capture.channels, capture.bits):
        return dict(report, status='format_mismatch', rate_mismatch=source.rate != capture.rate)
    if offset < 0 or (auto_max is not None and auto_max < 0): raise ValueError('Offsets must be nonnegative')
    if auto_max is not None:
        anchor = source.data[:min(256, source.frames) * source.stride]
        search = capture.data[:auto_max * source.stride + len(anchor)]
        candidates, cursor = [], 0
        while len(candidates) < 2:
            index = search.find(anchor, cursor)
            if index < 0: break
            if index % source.stride == 0: candidates.append(index // source.stride)
            cursor = index + 1
        if len(candidates) != 1:
            return dict(report, status='alignment_not_unique' if candidates else 'alignment_not_found')
        offset = candidates[0]
    report['capture_offset_frames'] = offset
    start = offset * capture.stride
    window = capture.data[start:start + len(source.data)]
    if len(window) != len(source.data): return dict(report, status='insufficient_capture')
    width, scale = source.bits // 8, 1 << (source.bits - 1)
    stats = [dict(source_peak=0, capture_peak=0, source_at_rails=0, capture_at_rails=0,
                  dot=0, energy=0) for _ in range(source.channels)]
    first, mismatches, mismatch_frames = None, 0, 0
    for frame in range(source.frames):
        changed = False
        for channel in range(source.channels):
            index = frame * source.stride + channel * width
            a = int.from_bytes(source.data[index:index + width], 'little', signed=True)
            b = int.from_bytes(window[index:index + width], 'little', signed=True)
            s = stats[channel]
            s['source_peak'] = max(s['source_peak'], abs(a) / scale)
            s['capture_peak'] = max(s['capture_peak'], abs(b) / scale)
            s['source_at_rails'] += a in (-scale, scale - 1)
            s['capture_at_rails'] += b in (-scale, scale - 1)
            s['dot'] += a * b; s['energy'] += a * a
            if a != b:
                mismatches += 1; changed = True
                if first is None: first = dict(frame=frame, channel=channel, source=a, capture=b)
        mismatch_frames += changed
    for s in stats:
        s['gain_ratio_estimate'] = s.pop('dot') / s['energy'] if s['energy'] else None
        s.pop('energy')
        s['possible_extra_clipping'] = s['capture_at_rails'] > s['source_at_rails']
    return dict(report, status='pcm_equal' if mismatches == 0 else 'pcm_mismatch',
                compared_frames=source.frames, capture_window_pcm_sha256=hashlib.sha256(window).hexdigest(),
                mismatch_samples=mismatches, mismatch_frames=mismatch_frames, first_mismatch=first, channels=stats)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='command', required=True)
    gen = commands.add_parser('generate'); gen.add_argument('directory', type=Path)
    cmp = commands.add_parser('compare'); cmp.add_argument('source', type=Path); cmp.add_argument('capture', type=Path)
    alignment = cmp.add_mutually_exclusive_group()
    alignment.add_argument('--capture-offset-frames', type=int, default=0)
    alignment.add_argument('--auto-align-max-frames', type=int)
    cmp.add_argument('--metadata', type=Path, help='Optional JSON with non-identifying device/route test details')
    cmp.add_argument('--report', type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == 'generate': result = generate(args.directory); code = 0
        else:
            result = compare(PCM.read(args.source), PCM.read(args.capture), args.capture_offset_frames, args.auto_align_max_frames)
            if args.metadata:
                with args.metadata.open('rb') as stream: content = stream.read(65537)
                if len(content) > 65536: raise ValueError('Metadata JSON exceeds 64 KiB')
                metadata = json.loads(content)
                if not isinstance(metadata, dict): raise ValueError('Metadata must be a JSON object')
                allowed = ('iphone_model', 'ios_version', 'dac', 'route', 'soundly_commit', 'application_gain', 'system_volume', 'capture_method')
                result['test_configuration'] = {key: metadata[key] for key in allowed if key in metadata}
            code = 0 if result['status'] == 'pcm_equal' else 1
        rendered = json.dumps(result, indent=2) + '\n'
        if getattr(args, 'report', None): args.report.write_text(rendered)
        print(rendered, end=''); return code
    except (OSError, ValueError, struct.error) as error:
        message = error.strerror if isinstance(error, OSError) else str(error)
        print(json.dumps(dict(status='invalid_input', error=message)), file=sys.stderr); return 2


if __name__ == '__main__': sys.exit(main())

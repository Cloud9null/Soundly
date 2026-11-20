import hashlib
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from audio_reference import PCM, RATES, compare, generate, reference


class ReferenceTests(unittest.TestCase):
    def setUp(self): self.pcm = reference()

    def changed(self, data, **kw):
        return PCM(kw.get('rate', self.pcm.rate), kw.get('channels', 2), kw.get('bits', 24), bytes(data))

    def test_complete_generated_rate_depth_matrix_and_pcm_hashes(self):
        with tempfile.TemporaryDirectory() as directory:
            entries = generate(directory)
            self.assertEqual(len(entries), 12)
            self.assertEqual({e['rate'] for e in entries}, set(RATES))
            for e in entries:
                pcm = PCM.read(Path(directory) / e['file'])
                self.assertEqual(pcm.digest, e['decoded_pcm_sha256'])
                self.assertEqual(pcm.frames, 4096)
                self.assertEqual(compare(pcm, pcm)['status'], 'pcm_equal')

    def test_one_least_significant_bit_is_detected(self):
        data = bytearray(self.pcm.data); data[3000] ^= 1
        result = compare(self.pcm, self.changed(data))
        self.assertEqual(result['status'], 'pcm_mismatch')
        self.assertEqual(result['mismatch_samples'], 1)
        self.assertEqual(result['first_mismatch']['frame'], 500)

    def test_channel_swap_is_detected(self):
        raw = b''.join(self.pcm.data[i+3:i+6] + self.pcm.data[i:i+3] for i in range(0, len(self.pcm.data), 6))
        self.assertGreater(compare(self.pcm, self.changed(raw))['mismatch_frames'], 4000)

    def test_gain_processing_is_detected(self):
        raw = b''.join((int.from_bytes(self.pcm.data[i:i+3], 'little', signed=True) // 2).to_bytes(3, 'little', signed=True)
                       for i in range(0, len(self.pcm.data), 3))
        result = compare(self.pcm, self.changed(raw))
        self.assertEqual(result['status'], 'pcm_mismatch')
        self.assertAlmostEqual(result['channels'][0]['gain_ratio_estimate'], .5, places=5)

    def test_full_scale_and_additional_clipping_are_reported(self):
        data = bytearray(self.pcm.data); data[3000:3003] = (2**23-1).to_bytes(3, 'little', signed=True)
        result = compare(self.pcm, self.changed(data))
        self.assertTrue(result['channels'][0]['possible_extra_clipping'])
        self.assertEqual(result['channels'][0]['capture_peak'], 1)

    def test_rate_change_is_rejected_without_resampling(self):
        result = compare(self.pcm, self.changed(self.pcm.data, rate=48000))
        self.assertEqual(result['status'], 'format_mismatch'); self.assertTrue(result['rate_mismatch'])

    def test_width_change_is_not_silently_normalized(self):
        self.assertEqual(compare(self.pcm, reference(16))['status'], 'format_mismatch')

    def test_resampling_changes_are_detected_even_at_equal_reported_rates(self):
        # Downsample by averaging adjacent frames, then repeat to restore length/rate metadata.
        raw = bytearray()
        for frame in range(0, self.pcm.frames, 2):
            values = []
            for channel in range(2):
                index = frame*6 + channel*3
                a = int.from_bytes(self.pcm.data[index:index+3], 'little', signed=True)
                b = int.from_bytes(self.pcm.data[index+6:index+9], 'little', signed=True)
                values.append(((a+b)//2).to_bytes(3, 'little', signed=True))
            raw.extend(b''.join(values)*2)
        self.assertEqual(compare(self.pcm, self.changed(raw))['status'], 'pcm_mismatch')

    def test_explicit_latency_alignment_compares_full_source(self):
        delayed = self.changed(bytes(6 * 37) + self.pcm.data + bytes(6 * 20))
        result = compare(self.pcm, delayed, offset=37)
        self.assertEqual(result['status'], 'pcm_equal'); self.assertEqual(result['compared_frames'], self.pcm.frames)
        self.assertEqual(result['source_pcm_sha256'], result['capture_window_pcm_sha256'])

    def test_unique_anchor_alignment(self):
        delayed = self.changed(bytes(6 * 37) + self.pcm.data)
        result = compare(self.pcm, delayed, auto_max=100)
        self.assertEqual(result['status'], 'pcm_equal'); self.assertEqual(result['capture_offset_frames'], 37)

    def test_ambiguous_anchor_refuses_alignment(self):
        silence = self.changed(bytes(len(self.pcm.data)))
        longer = self.changed(bytes(len(self.pcm.data) + 60))
        self.assertEqual(compare(silence, longer, auto_max=10)['status'], 'alignment_not_unique')

    def test_missing_or_dropped_frame_is_not_hidden(self):
        missing = self.pcm.data[:6000] + self.pcm.data[6006:]
        self.assertEqual(compare(self.pcm, self.changed(missing))['status'], 'insufficient_capture')
        padded = missing + bytes(6)
        self.assertEqual(compare(self.pcm, self.changed(padded))['status'], 'pcm_mismatch')

    def test_wav_container_hash_is_not_pcm_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'unicode-音.wav'; self.pcm.write(path)
            original = path.read_bytes()
            extra = b'JUNK' + struct.pack('<I', 4) + b'test'
            altered = original[:12] + extra + original[12:]
            altered = altered[:4] + struct.pack('<I', len(altered)-8) + altered[8:]
            path.write_bytes(altered)
            self.assertNotEqual(hashlib.sha256(original).hexdigest(), hashlib.sha256(altered).hexdigest())
            self.assertEqual(PCM.read(path).digest, self.pcm.digest)

    def test_truncated_and_unsupported_input_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'bad.wav'; self.pcm.write(path)
            original = path.read_bytes(); path.write_bytes(original[:-1])
            with self.assertRaises(ValueError): PCM.read(path)
            data = bytearray(original); struct.pack_into('<H', data, 20, 3); path.write_bytes(data)
            with self.assertRaises(ValueError): PCM.read(path)

    def test_sample_equality_never_grants_physical_verification(self):
        result = compare(self.pcm, self.pcm)
        self.assertEqual(result['status'], 'pcm_equal'); self.assertFalse(result['bit_perfect_verified'])
        with self.assertRaises(ValueError): compare(self.pcm, self.pcm, offset=-1)


if __name__ == '__main__': unittest.main()

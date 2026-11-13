import Foundation
import AVFoundation

struct SourceAudioInfo: Sendable {
    var codec = "Unknown"
    var pcm: PCMFormat?
    var lossless: Bool?
    var note = "Source properties are unavailable."
}

enum SourceFormatInspector {
    /// Runs once on the transport actor at file open, never in render or progress callbacks.
    static func inspect(_ file:AVAudioFile,url:URL) throws -> SourceAudioInfo {
        let description = file.fileFormat.streamDescription.pointee
        var info = SourceAudioInfo()
        switch description.mFormatID {
        case kAudioFormatFLAC:
            info.codec = "FLAC"; info.lossless = true
            let handle = try FileHandle(forReadingFrom:url); defer { try? handle.close() }
            let header = Array(try handle.read(upToCount:8) ?? Data())
            guard header.count == 8, Array(header[0..<4]) == Array("fLaC".utf8),
                  header[4] & 0x7f == 0, header[5] == 0, header[6] == 0, header[7] == 34 else { throw CocoaError(.fileReadCorruptFile) }
            let bytes = Array(try handle.read(upToCount:34) ?? Data())
            guard bytes.count == 34 else { throw CocoaError(.fileReadCorruptFile) }
            let rate = Double(Int(bytes[10]) << 12 | Int(bytes[11]) << 4 | Int(bytes[12]) >> 4)
            let channels = Int((bytes[12] >> 1) & 7) + 1
            let bits = Int((bytes[12] & 1) << 4 | bytes[13] >> 4) + 1
            info.pcm = try PCMFormat(sampleRate:rate,channels:channels,bitDepth:bits,representation:.signedInteger)
            info.note = "Read directly from FLAC STREAMINFO; this is the source, not the decoder's float width."
        case kAudioFormatAppleLossless:
            info.codec = "ALAC"; info.lossless = true
            info.pcm = try? PCMFormat(sampleRate:description.mSampleRate,channels:Int(description.mChannelsPerFrame),bitDepth:[1:16,2:20,3:24,4:32][Int(description.mFormatFlags)],representation:.signedInteger)
            info.note = "Reported ALAC stream format and source-depth flags. Unavailable fields remain unknown."
        case kAudioFormatLinearPCM:
            info.codec = "Linear PCM"; info.lossless = true
            info.pcm = pcm(file.fileFormat)
            info.note = "Reported file PCM stream description, including integer/float representation."
        default: break
        }
        return info
    }
    static func pcm(_ format:AVAudioFormat)->PCMFormat? {
        let description = format.streamDescription.pointee
        guard description.mFormatID == kAudioFormatLinearPCM else { return nil }
        let representation: PCMFormat.Representation
        if description.mFormatFlags & kAudioFormatFlagIsFloat != 0 { representation = .floatingPoint }
        else if description.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0 { representation = .signedInteger }
        else { representation = .unknown }
        return try? PCMFormat(sampleRate:format.sampleRate,channels:Int(format.channelCount),bitDepth:description.mBitsPerChannel > 0 ? Int(description.mBitsPerChannel) : nil,representation:representation)
    }
}

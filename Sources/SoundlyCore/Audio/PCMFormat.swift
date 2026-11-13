import Foundation

/// Observed PCM properties, not a declaration of device support.
public struct PCMFormat: Equatable, Sendable {
    public enum Representation: String, Sendable {
        case signedInteger, floatingPoint, unknown
    }

    public enum ValidationError: Error {
        case invalidSampleRate, invalidChannelCount, invalidBitDepth
    }

    public let sampleRate: Double
    public let channels: Int
    /// Nil means unavailable. Never substitute the decoder's float width for source depth.
    public let bitDepth: Int?
    public let representation: Representation

    public init(sampleRate: Double, channels: Int, bitDepth: Int?,
                representation: Representation) throws {
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw ValidationError.invalidSampleRate
        }
        guard channels > 0 else { throw ValidationError.invalidChannelCount }
        if let bitDepth, !(1...64).contains(bitDepth) {
            throw ValidationError.invalidBitDepth
        }
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitDepth = bitDepth
        self.representation = representation
    }
}

import Foundation
import AVFoundation

struct PlaybackTrack: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let filename: String
    let title: String
    let artist: String
    let album: String
    let artwork: String?
    let sourceQuality: String
}

struct AudioObservation: Sendable {
    var elapsed = 0.0
    var duration = 0.0
    var playing = false
    var ended = false
    var sessionRate = 0.0
    var decoderRate = 0.0
    var mixerRate = 0.0
    var decoderChannels = 0
    var sessionChannels = 0
    var decoderRepresentation = "Not observed"
    var route = "Not observed"
    var routeTypes: [String] = []
}

/// Serialized control plane. AVFoundation schedules/decodes the file on its own workers.
/// No custom realtime render callback, whole-file PCM allocation, EQ, gain or crossfade.
actor AudioTransport {
    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private var file: AVAudioFile?
    private var offset: AVAudioFramePosition = 0
    private var generation: UInt64 = 0
    private var active = false
    private var ended = false
    private var playing = false
    private var attached = false

    func load(_ track: PlaybackTrack, position: Double = 0, autoplay: Bool = true) throws -> AudioObservation {
        guard track.filename == URL(fileURLWithPath:track.filename).lastPathComponent,
              !track.filename.contains("\\"), track.filename != ".", track.filename != ".." else { throw CocoaError(.fileReadInvalidFileName) }
        let url = try LibraryPaths.directory("Music").appendingPathComponent(track.filename)
        return try open(url,position:position,autoplay:autoplay)
    }

    private func open(_ url: URL, position: Double, autoplay: Bool) throws -> AudioObservation {
        generation &+= 1; playing = false; ended = false
        player.stop(); engine.stop(); file = nil
        let source = try AVAudioFile(forReading:url)
        guard source.length > 0, source.processingFormat.channelCount > 0,
              source.processingFormat.sampleRate > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let session = AVAudioSession.sharedInstance()
        if active { try session.setActive(false); active = false }
        try session.setCategory(.playback,mode:.default,options:[])
        try session.setPreferredSampleRate(source.processingFormat.sampleRate)
        try session.setActive(true); active = true
        if !attached { engine.attach(player); attached = true }
        engine.disconnectNodeOutput(player)
        PCMGraph.connect(engine:engine,player:player,format:source.processingFormat)
        player.volume = 1; engine.mainMixerNode.outputVolume = 1
        file = source
        offset = Self.frame(position,rate:source.processingFormat.sampleRate,length:source.length)
        if autoplay { try resume() }
        return observation()
    }

    static func frame(_ seconds: Double, rate: Double, length: AVAudioFramePosition) -> AVAudioFramePosition {
        guard seconds.isFinite, rate.isFinite, rate > 0, length > 0 else { return 0 }
        let value = min(max(0,seconds * rate),Double(length - 1))
        return AVAudioFramePosition(value)
    }

    func resume() throws {
        guard file != nil, !playing else { return }
        if ended { offset = 0; ended = false }
        try AVAudioSession.sharedInstance().setActive(true); active = true
        try engine.start()
        schedule()
        player.play(); playing = true
    }

    private func schedule() {
        guard let file else { return }
        generation &+= 1
        let token = generation
        let count = AVAudioFrameCount(min(file.length-offset,Int64(UInt32.max)))
        guard count > 0 else { ended = true; playing = false; return }
        let end = offset + Int64(count)
        player.scheduleSegment(file,startingFrame:offset,frameCount:count,at:nil,completionCallbackType:.dataPlayedBack) { [weak self] _ in
            // Completion notification, not a user render callback. Never mutate UI here.
            Task { await self?.finished(token:token,end:end) }
        }
    }

    private func finished(token:UInt64,end:AVAudioFramePosition) {
        guard token == generation, let file else { return }
        if end < file.length {
            generation &+= 1; player.stop(); offset = end; schedule(); player.play()
        } else { offset = file.length; ended = true; playing = false; engine.pause() }
    }

    func pause() {
        let position = observation().elapsed
        generation &+= 1
        player.stop(); engine.pause(); playing = false
        if let file { offset = Self.frame(position,rate:file.processingFormat.sampleRate,length:file.length) }
    }
    func seek(_ seconds:Double) throws {
        guard let file else { return }
        let shouldPlay = playing
        generation &+= 1; player.stop(); playing = false; ended = false
        offset = Self.frame(seconds,rate:file.processingFormat.sampleRate,length:file.length)
        if shouldPlay { try resume() }
    }
    func stop() {
        generation &+= 1; player.stop(); engine.stop(); offset = 0; playing = false; ended = false
        try? AVAudioSession.sharedInstance().setActive(false,options:.notifyOthersOnDeactivation)
        active = false
    }
    func resetServices() {
        stop(); engine = AVAudioEngine(); player = AVAudioPlayerNode(); file = nil; attached = false
    }
    func observation() -> AudioObservation {
        var value = AudioObservation()
        value.playing = playing; value.ended = ended
        if let file {
            let format = file.processingFormat
            value.duration = Double(file.length)/format.sampleRate
            var frames = offset
            if playing, let time = player.lastRenderTime, let clock = player.playerTime(forNodeTime:time) { frames += max(0,clock.sampleTime) }
            value.elapsed = min(value.duration,Double(frames)/format.sampleRate)
            value.decoderRate = format.sampleRate; value.decoderChannels = Int(format.channelCount)
            value.decoderRepresentation = "\(format.commonFormat == .pcmFormatFloat32 ? "Float32" : String(describing:format.commonFormat)) PCM"
            value.mixerRate = engine.mainMixerNode.outputFormat(forBus:0).sampleRate
        }
        if active {
            let session = AVAudioSession.sharedInstance()
            value.sessionRate = session.sampleRate; value.sessionChannels = session.outputNumberOfChannels
            value.route = session.currentRoute.outputs.map(\.portName).joined(separator:", ")
            value.routeTypes = session.currentRoute.outputs.map { $0.portType.rawValue }
        }
        return value
    }
}

/// Shared by production playback and offline PCM regression tests.
enum PCMGraph {
    static func connect(engine:AVAudioEngine,player:AVAudioPlayerNode,format:AVAudioFormat) {
        engine.connect(player,to:engine.mainMixerNode,format:format)
        player.volume = 1
        engine.mainMixerNode.outputVolume = 1
    }
}

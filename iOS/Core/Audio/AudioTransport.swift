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
    var rateRequestNote: String?
    var signalPath = LiveSignalPath()
}

/// Serialized control plane. AVFoundation schedules/decodes the file on its own workers.
/// No custom realtime render callback, whole-file PCM allocation, EQ, gain or crossfade.
actor AudioTransport {
    private var engine = AVAudioEngine()
    private var player = AVAudioPlayerNode()
    private var sourceInfo = SourceAudioInfo()
    private var file: AVAudioFile?
    private var offset: AVAudioFramePosition = 0
    private var generation: UInt64 = 0
    private var active = false
    private var ended = false
    private var playing = false
    private var attached = false
    private var configured = false
    private var rateRequestNote: String?
    private var graphPath = AudioGraphPath.unknown
    private var requestedRate: Double?

    func load(_ track: PlaybackTrack, position: Double = 0, autoplay: Bool = true) throws -> AudioObservation {
        guard track.filename == URL(fileURLWithPath:track.filename).lastPathComponent,
              !track.filename.contains("\\"), track.filename != ".", track.filename != ".." else { throw CocoaError(.fileReadInvalidFileName) }
        let url = try LibraryPaths.directory("Music").appendingPathComponent(track.filename)
        return try open(url,position:position,autoplay:autoplay)
    }

    private func open(_ url: URL, position: Double, autoplay: Bool) throws -> AudioObservation {
        generation &+= 1; playing = false; ended = false
        player.stop(); engine.stop(); file = nil; sourceInfo = SourceAudioInfo()
        let source = try AVAudioFile(forReading:url)
        guard source.length > 0, source.processingFormat.channelCount > 0,
              source.processingFormat.sampleRate > 0 else { throw CocoaError(.fileReadCorruptFile) }
        if active { try AVAudioSession.sharedInstance().setActive(false); active = false }
        configured = false; rateRequestNote = nil
        graphPath = .unknown; requestedRate = nil
        sourceInfo = try SourceFormatInspector.inspect(source,url:url)
        file = source
        offset = Self.frame(position,rate:source.processingFormat.sampleRate,length:source.length)
        if autoplay { try resume() }
        return observation()
    }

    private func configureOutput(_ source:AVAudioFile) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback,mode:.default,options:[])
        rateRequestNote = nil
        let requested = sourceInfo.pcm?.sampleRate ?? source.processingFormat.sampleRate
        requestedRate = requested
        do { try session.setPreferredSampleRate(requested) }
        catch { rateRequestNote = "The native-rate request was rejected. Playback uses the session rate reported below." }
        try session.setActive(true); active = true
        // A fresh graph prevents an old main-mixer connection surviving a direct-path switch.
        engine = AVAudioEngine(); player = AVAudioPlayerNode(); attached = false
        let hardware = engine.outputNode.outputFormat(forBus:0)
        guard hardware.sampleRate > 0, hardware.channelCount > 0 else {
            throw NSError(domain:"Soundly.Audio",code:1,userInfo:[NSLocalizedDescriptionKey:"No active audio output format is available."])
        }
        if session.sampleRate != requested {
            rateRequestNote = "Requested \(String(format:"%.1f",requested/1000)) kHz; iOS activated \(String(format:"%.1f",session.sampleRate/1000)) kHz. The selected route did not provide the requested rate."
        }
        if !attached { engine.attach(player); attached = true }
        graphPath = PCMGraph.connect(engine:engine,player:player,format:source.processingFormat,matchingOutput:hardware)
        configured = true
    }

    static func frame(_ seconds: Double, rate: Double, length: AVAudioFramePosition) -> AVAudioFramePosition {
        guard seconds.isFinite, rate.isFinite, rate > 0, length > 0 else { return 0 }
        let value = min(max(0,seconds * rate),Double(length - 1))
        return AVAudioFramePosition(value)
    }

    func resume() throws {
        guard let file, !playing else { return }
        if ended { offset = 0; ended = false }
        if !configured { try configureOutput(file) }
        else {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(true); active = true
            let output = engine.outputNode.outputFormat(forBus:0)
            guard output.sampleRate > 0,output.channelCount > 0 else {
                throw NSError(domain:"Soundly.Audio",code:1,userInfo:[NSLocalizedDescriptionKey:"The audio output is unavailable. Select an output and try again."])
            }
            if graphPath == .direct,PCMGraph.path(source:file.processingFormat,output:output) != .direct {
                try session.setActive(false); active = false; configured = false
                try configureOutput(file)
            }
        }
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
    func interrupted() { pause(); active = false }
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
        stop(); engine = AVAudioEngine(); player = AVAudioPlayerNode(); file = nil; sourceInfo = SourceAudioInfo(); attached = false; configured = false; graphPath = .unknown; requestedRate = nil
    }
    func observation() -> AudioObservation {
        var value = AudioObservation()
        value.rateRequestNote = rateRequestNote
        value.signalPath.source = sourceInfo
        value.signalPath.graphPath = graphPath
        value.signalPath.requestedRate = requestedRate
        value.signalPath.snapshot.source = sourceInfo.pcm
        value.signalPath.snapshot.sourceIsLossless = sourceInfo.lossless
        value.playing = playing; value.ended = ended
        if let file {
            let format = file.processingFormat
            value.duration = Double(file.length)/format.sampleRate
            var frames = offset
            if playing, let time = player.lastRenderTime, let clock = player.playerTime(forNodeTime:time) { frames += max(0,clock.sampleTime) }
            value.elapsed = min(value.duration,Double(frames)/format.sampleRate)
            value.signalPath.snapshot.decoderOutput = SourceFormatInspector.pcm(format)
            value.decoderRate = format.sampleRate; value.decoderChannels = Int(format.channelCount)
            value.decoderRepresentation = "\(format.commonFormat == .pcmFormatFloat32 ? "Float32" : String(describing:format.commonFormat)) PCM"
            if configured {
                let mixerFormat = graphPath == .direct ? engine.outputNode.inputFormat(forBus:0) : engine.mainMixerNode.outputFormat(forBus:0)
                value.mixerRate = mixerFormat.sampleRate
                value.signalPath.snapshot.engineOutput = SourceFormatInspector.pcm(mixerFormat)
                value.signalPath.snapshot.engineGain = Double(player.volume) * (graphPath == .direct ? 1 : Double(engine.mainMixerNode.outputVolume))
                value.signalPath.snapshot.processing = .bypassed
            }
        }
        if active {
            let session = AVAudioSession.sharedInstance()
            value.signalPath.snapshot.sessionIsActive = true
            value.signalPath.systemVolume = session.outputVolume
            value.signalPath.bufferDuration = session.ioBufferDuration
            value.sessionRate = session.sampleRate; value.sessionChannels = session.outputNumberOfChannels
            value.route = session.currentRoute.outputs.map(\.portName).joined(separator:", ")
            value.routeTypes = session.currentRoute.outputs.map { $0.portType.rawValue }
            value.signalPath.snapshot.sessionSampleRate = value.sessionRate
            value.signalPath.snapshot.sessionChannels = value.sessionChannels
            value.signalPath.snapshot.route = LiveSignalPath.route(value.routeTypes)
        }
        return value
    }
}

/// Shared by production playback and offline PCM regression tests.
enum PCMGraph {
    static func path(source:AVAudioFormat,output:AVAudioFormat?)->AudioGraphPath {
        guard let output, output.sampleRate > 0, output.channelCount > 0,
              source.sampleRate == output.sampleRate, source.channelCount == output.channelCount,
              source.commonFormat == .pcmFormatFloat32, output.commonFormat == source.commonFormat,
              source.isInterleaved == output.isInterleaved else { return .systemMixer }
        return .direct
    }
    @discardableResult
    static func connect(engine:AVAudioEngine,player:AVAudioPlayerNode,format:AVAudioFormat,matchingOutput:AVAudioFormat? = nil)->AudioGraphPath {
        let selected = path(source:format,output:matchingOutput)
        if selected == .direct { engine.connect(player,to:engine.outputNode,format:format) }
        else { engine.connect(player,to:engine.mainMixerNode,format:format); engine.mainMixerNode.outputVolume = 1 }
        player.volume = 1
        return selected
    }
}

enum AudioGraphPath: String, Sendable {
    case unknown, direct, systemMixer
    var description:String {
        switch self {
        case .unknown: "Engine path not observed"
        case .direct: "AVAudioPlayerNode → output (main mixer bypassed)"
        case .systemMixer: "AVAudioPlayerNode → Apple main mixer → output"
        }
    }
}

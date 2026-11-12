import Foundation
import Observation
import AVFoundation
import MediaPlayer
import SwiftData

@MainActor @Observable
final class PlaybackController {
    private(set) var queue = PlaybackQueue()
    private(set) var audio = AudioObservation()
    private(set) var busy = false
    var error: String?
    private let transport = AudioTransport()
    private var operation: Task<Void,Never>?
    private var saveTask: Task<Void,Never>?
    private var revision = 0
    private var poller: Task<Void,Never>?
    private var observers: [NSObjectProtocol] = []
    private var remoteTokens: [(MPRemoteCommand,Any)] = []
    private var resumeAfterInterruption = false
    private var lastPersisted = Date.distantPast
    private var lastConfigured = Date.distantPast
    private var pendingRouteChange: UInt?
    private var systemSecond = -1
    private var systemTrack: UUID?
    private var systemPlaying = false
    private var context: ModelContext?
    var current: PlaybackTrack? { queue.current }

    init() {}

    func attach(_ context:ModelContext) {
        guard self.context == nil else { return }
        self.context = context
        registerSystemEvents()
        Task {
            if let saved = await Self.readSession(), queue.current == nil {
                queue = saved.queue
                if current != nil { load(position:saved.position,autoplay:false,recordPlay:false) }
            }
        }
    }
    func play(_ song:Song,within songs:[Song]) {
        resumeAfterInterruption = false
        let tracks = songs.filter(\.available).map(Self.track)
        guard tracks.contains(where:{$0.id == song.id}) else { error = "The local file is missing. Reimport it to restore the copy."; return }
        queue.replace(tracks,starting:song.id)
        load()
    }
    private static func track(_ song:Song) -> PlaybackTrack {
        PlaybackTrack(id:song.id,filename:song.filename,title:song.title,artist:song.artist,album:song.album,artwork:song.artwork,sourceQuality:song.quality)
    }
    func toggle() { if audio.playing { pause() } else { resume() } }
    func resume() {
        guard current != nil else { return }
        resumeAfterInterruption = false
        if audio.duration == 0 { load(); return }
        submit { [transport] in try await transport.resume() }
    }
    func pause() {
        resumeAfterInterruption = false
        submit { [transport] in await transport.pause() }
    }
    func stop() {
        resumeAfterInterruption = false
        submit { [transport] in await transport.stop() }
    }
    func seek(_ seconds:Double) {
        guard seconds.isFinite else { return }
        submit { [transport] in try await transport.seek(seconds) }
    }
    func next(automatic:Bool = false) {
        if queue.advance(automatic:automatic) { load() }
        else { stop() }
    }
    func previous() {
        if audio.elapsed > 3 { seek(0) }
        else { queue.previous(); load() }
    }
    func choose(_ id:UUID) { queue.select(id); load() }
    func toggleShuffle() { queue.shuffle.toggle(); persist() }
    func cycleRepeat() {
        switch queue.repeatMode { case .off: queue.repeatMode = .all; case .all: queue.repeatMode = .one; case .one: queue.repeatMode = .off }
        persist()
    }
    private func load(position:Double = 0,autoplay:Bool = true,recordPlay:Bool = true) {
        guard let track = current else { return }
        audio = AudioObservation(); error = nil
        lastConfigured = Date()
        submit({ [transport] in _ = try await transport.load(track,position:position,autoplay:autoplay) },onSuccess: { [weak self] in
            guard autoplay, recordPlay, let context = self?.context else { return }
            let id = track.id
            var q = FetchDescriptor<Song>(predicate:#Predicate { $0.id == id }); q.fetchLimit = 1
            if let song = try? context.fetch(q).first {
                // A successful engine start, not proof that a complete song was heard.
                song.lastPlayed = Date(); song.playCount += 1
                do { try context.save() } catch { context.rollback() }
            }
        })
        startPolling()
    }
    private func submit(_ action:@escaping @Sendable () async throws -> Void,onSuccess:(@MainActor ()->Void)? = nil) {
        let previous = operation
        revision += 1
        let token = revision
        busy = true
        operation = Task {
            await previous?.value
            var succeeded = false
            do { try await action(); succeeded = true }
            catch {
                await transport.stop()
                self.error = "Playback could not start or continue: \(error.localizedDescription)"
            }
            guard token == revision else { return }
            audio = await transport.observation()
            busy = false
            if succeeded { onSuccess?() }
            updateSystemMetadata(); persist()
            if let pending = pendingRouteChange { pendingRouteChange = nil; routeChanged(pending) }
        }
    }
    private func startPolling() {
        guard poller == nil else { return }
        poller = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for:.milliseconds(self?.audio.playing == true ? 500 : 2000))
                guard let self else { return }
                guard !busy else { continue }
                let value = await transport.observation()
                audio = value
                if value.ended { next(automatic:true) }
                else { updateSystemMetadata() }
                if Date().timeIntervalSince(lastPersisted) > 5 { persist() }
            }
        }
    }

    private func updateSystemMetadata() {
        let commands = MPRemoteCommandCenter.shared()
        [commands.playCommand,commands.pauseCommand,commands.togglePlayPauseCommand,commands.nextTrackCommand,commands.previousTrackCommand,commands.changePlaybackPositionCommand,commands.stopCommand].forEach { $0.isEnabled = current != nil }
        guard let current else { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; return }
        let second = Int(max(0,audio.elapsed))
        guard current.id != systemTrack || second != systemSecond || audio.playing != systemPlaying else { return }
        systemTrack = current.id; systemSecond = second; systemPlaying = audio.playing
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle:current.title, MPMediaItemPropertyArtist:current.artist,
            MPMediaItemPropertyAlbumTitle:current.album, MPMediaItemPropertyPlaybackDuration:audio.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime:audio.elapsed,
            MPNowPlayingInfoPropertyPlaybackRate:audio.playing ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyExcludeFromSuggestions:true
        ]
    }
    private func registerSystemEvents() {
        let center = MPRemoteCommandCenter.shared()
        func command(_ command:MPRemoteCommand,_ action:@escaping @MainActor @Sendable (PlaybackController)->Void) {
            let token = command.addTarget { [weak self] _ in
                Task { @MainActor in if let self { action(self) } }
                return .success
            }
            remoteTokens.append((command,token))
        }
        command(center.playCommand) { $0.resume() }
        command(center.pauseCommand) { $0.pause() }
        command(center.togglePlayPauseCommand) { $0.toggle() }
        command(center.nextTrackCommand) { $0.next() }
        command(center.previousTrackCommand) { $0.previous() }
        command(center.stopCommand) { $0.stop() }
        let token = center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in self?.seek(position) }; return .success
        }
        remoteTokens.append((center.changePlaybackPositionCommand,token))
        let notifications = NotificationCenter.default
        observers.append(notifications.addObserver(forName:AVAudioSession.interruptionNotification,object:nil,queue:nil) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in self?.interrupted(type:type,options:options) }
        })
        observers.append(notifications.addObserver(forName:AVAudioSession.routeChangeNotification,object:nil,queue:nil) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt ?? 0
            Task { @MainActor in self?.routeChanged(reason) }
        })
        observers.append(notifications.addObserver(forName:AVAudioSession.mediaServicesWereResetNotification,object:nil,queue:nil) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let position = self.audio.elapsed
                self.submit { [transport = self.transport] in await transport.resetServices() }
                self.load(position:position,autoplay:false,recordPlay:false)
            }
        })
        observers.append(notifications.addObserver(forName:.AVAudioEngineConfigurationChange,object:nil,queue:nil) { [weak self] _ in
            Task { @MainActor in
                guard let self, Date().timeIntervalSince(self.lastConfigured) > 2 else { return }
                self.load(position:self.audio.elapsed,autoplay:self.audio.playing,recordPlay:false)
            }
        })
        updateSystemMetadata()
    }
    private func interrupted(type:UInt,options:UInt) {
        if type == AVAudioSession.InterruptionType.began.rawValue {
            let wasPlaying = audio.playing
            submit { [transport] in await transport.interrupted() }
            resumeAfterInterruption = wasPlaying
        } else {
            let allowed = options & AVAudioSession.InterruptionOptions.shouldResume.rawValue != 0
            if resumeAfterInterruption, allowed { resumeAfterInterruption = false; resume() }
            else { resumeAfterInterruption = false }
        }
    }
    private func routeChanged(_ reason:UInt) {
        guard current != nil, reason != AVAudioSession.RouteChangeReason.categoryChange.rawValue,
              reason != AVAudioSession.RouteChangeReason.unknown.rawValue else { return }
        if busy { pendingRouteChange = reason; return }
        let disconnected = reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
        load(position:audio.elapsed,autoplay:audio.playing && !disconnected,recordPlay:false)
    }

    private static func readSession() async -> SavedPlaybackSession? {
        await Task.detached {
            guard let url = try? LibraryPaths.base().appendingPathComponent("Playback.json"),
                  let bytes = try? Data(contentsOf:url), bytes.count < 4*1024*1024 else { return nil }
            return try? JSONDecoder().decode(SavedPlaybackSession.self,from:bytes)
        }.value
    }
    private func persist() {
        lastPersisted = Date()
        let saved = SavedPlaybackSession(queue:queue,position:audio.elapsed)
        let previous = saveTask
        saveTask = Task {
            await previous?.value
            await Task.detached {
                guard let url = try? LibraryPaths.base().appendingPathComponent("Playback.json"),
                      let data = try? JSONEncoder().encode(saved) else { return }
                try? data.write(to:url,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
            }.value
        }
    }
}

struct SavedPlaybackSession: Codable, Sendable {
    var queue:PlaybackQueue
    var position:Double
}

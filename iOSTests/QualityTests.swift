import XCTest
import AVFoundation
import SwiftData
@testable import Soundly

/// Handwritten integer containers avoid an encoder round-trip defining the expected PCM.
/// Tests execute the production graph offline, never a physical DAC.
final class PCMMatrixTests: XCTestCase {
    func testWAV16And24BitAcrossSixNativeRates() throws { try matrix(aiff:false) }
    func testAIFF16And24BitAcrossSixNativeRates() throws { try matrix(aiff:true) }
    func testDirectWAV16And24BitAcrossSixNativeRates() throws { try matrix(aiff:false,direct:true) }
    func testDirectAIFF16And24BitAcrossSixNativeRates() throws { try matrix(aiff:true,direct:true) }

    private func matrix(aiff:Bool,direct:Bool = false) throws {
        let rates = [44100,48000,88200,96000,176400,192000]
        let frames = 2048
        var records:[String] = []
        for bits in [16,24] {
            let scale = 1 << (bits-1)
            let edges = [0,1,-1,scale-1,-scale,scale-2,1-scale,0]
            var samples:[Int32] = []; var state:UInt32 = 0x534E444C
            for frame in 0..<frames {
                for channel in 0..<2 {
                    state ^= state << 13; state ^= state >> 17; state ^= state << 5
                    samples.append(Int32(frame < 8 ? edges[(frame+3*channel)%8] : Int(state % UInt32(2*scale))-scale))
                }
            }
            for rate in rates {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(aiff ? "aiff" : "wav")
                defer { try? FileManager.default.removeItem(at:url) }
                try IntegerContainer.encode(samples,bits:bits,rate:rate,aiff:aiff).write(to:url)
                let file = try AVAudioFile(forReading:url)
                XCTAssertEqual(file.length,Int64(frames))
                let source = try SourceFormatInspector.inspect(file,url:url)
                XCTAssertEqual(source.pcm?.bitDepth,bits)
                XCTAssertEqual(source.pcm?.sampleRate,Double(rate))
                XCTAssertEqual(source.pcm?.representation,.signedInteger)
                let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate:Double(rate),channels:2))
                let engine = AVAudioEngine(); let player = AVAudioPlayerNode(); engine.attach(player)
                try engine.enableManualRenderingMode(.offline,format:format,maximumFrameCount:AVAudioFrameCount(frames))
                let path = PCMGraph.connect(engine:engine,player:player,format:file.processingFormat,matchingOutput:direct ? format : nil)
                XCTAssertEqual(path,direct ? .direct : .systemMixer)
                defer { player.stop(); engine.stop() }
                player.scheduleFile(file,at:nil)
                try engine.start(); player.play()
                let output = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(frames)))
                var succeeded = false
                for _ in 0..<20 { if try engine.renderOffline(AVAudioFrameCount(frames),to:output) == .success { succeeded = true; break } }
                XCTAssertTrue(succeeded); XCTAssertEqual(output.frameLength,AVAudioFrameCount(frames))
                guard output.frameLength == AVAudioFrameCount(frames) else { return }
                let values = try XCTUnwrap(output.floatChannelData)
                var mismatches = 0
                for frame in 0..<frames {
                    for channel in 0..<2 {
                        if values[channel][frame] != Float(samples[frame*2+channel])/Float(scale) { mismatches += 1 }
                    }
                }
                let description = "\(path.rawValue) / \(aiff ? "AIFF" : "WAV") / \(bits)-bit / \(rate) Hz / stereo / \(frames) frames"
                XCTAssertEqual(mismatches,0,"Exact numeric PCM mismatch: \(description)")
                records.append("\(description): \(mismatches) mismatched samples")
            }
        }
        let evidence = XCTAttachment(string:records.joined(separator:"\n"))
        evidence.name = (direct ? "Direct " : "Mixer ") + (aiff ? "AIFF offline matrix" : "WAV offline matrix")
        evidence.lifetime = .keepAlways; add(evidence)
    }
}

private enum IntegerContainer {
    static func encode(_ samples:[Int32],bits:Int,rate:Int,aiff:Bool)->Data {
        var pcm = Data()
        func append(_ value:UInt64,bytes:Int,big:Bool,to data:inout Data) {
            for i in 0..<bytes {
                data.append(UInt8(truncatingIfNeeded:value >> (8*(big ? bytes-1-i : i))))
            }
        }
        for sample in samples { append(UInt64(bitPattern:Int64(sample)),bytes:bits/8,big:aiff,to:&pcm) }
        var data = Data()
        func text(_ value:String) { data.append(contentsOf:value.utf8) }
        func number(_ value:Int,_ bytes:Int) { append(UInt64(value),bytes:bytes,big:aiff,to:&data) }
        if aiff {
            text("FORM"); number(46+pcm.count,4); text("AIFFCOMM"); number(18,4)
            number(2,2); number(samples.count/2,4); number(bits,2)
            let exponent = 63-UInt64(rate).leadingZeroBitCount
            number(16383+exponent,2)
            append(UInt64(rate) << (63-exponent),bytes:8,big:true,to:&data)
            text("SSND"); number(8+pcm.count,4); number(0,4); number(0,4)
        } else {
            text("RIFF"); number(36+pcm.count,4); text("WAVEfmt "); number(16,4)
            number(1,2); number(2,2); number(rate,4); number(rate*2*bits/8,4)
            number(2*bits/8,2); number(bits,2); text("data"); number(pcm.count,4)
        }
        data.append(pcm); return data
    }
}

final class AudioBoundaryTests: XCTestCase {
    func testTransportRejectsPathsOutsidePrivateMusicDirectory() async {
        let transport = AudioTransport()
        for filename in ["../outside.wav","/outside.wav","nested/file.wav","nested\\file.wav",".","..",""] {
            let track = PlaybackTrack(id:UUID(),filename:filename,title:"Reference",artist:"Test",album:"Test",artwork:nil,sourceQuality:"PCM")
            do { _ = try await transport.load(track); XCTFail("Unsafe filename was accepted") }
            catch { XCTAssertEqual((error as NSError).code,CocoaError.Code.fileReadInvalidFileName.rawValue) }
        }
        let report = await transport.observation()
        XCTAssertFalse(report.playing); XCTAssertEqual(report.signalPath.assessment.status,.unknown)
    }
    func testFLACInspectorRejectsTruncatedStreamInfo() throws {
        let good = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".flac")
        let bad = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".flac")
        defer { try? FileManager.default.removeItem(at:good); try? FileManager.default.removeItem(at:bad) }
        let bytes = try XCTUnwrap(Data(base64Encoded:FLACFixtures.pcm24)); try bytes.write(to:good)
        let file = try AVAudioFile(forReading:good)
        for length in [0,7,8,41] {
            try Data(bytes.prefix(length)).write(to:bad)
            XCTAssertThrowsError(try SourceFormatInspector.inspect(file,url:bad))
        }
    }
}

@MainActor
final class LibraryScaleTests: XCTestCase {
    func testSearchWith100MetadataRecords() throws { try check(100) }
    func testSearchWith1000MetadataRecords() throws { try check(1000) }
    func testSearchWith10000MetadataRecords() throws { try check(10000) }
    private func check(_ count:Int) throws {
        let db = try ModelContainer(for:Song.self,configurations:ModelConfiguration(isStoredInMemoryOnly:true,cloudKitDatabase:.none))
        let context = db.mainContext; context.autosaveEnabled = false
        for index in 0..<count {
            let metadata = MusicMetadata(title:String(format:"Track %05d",index),artist:"音楽 / Reference",album:"Synthetic metadata")
            let song = Song(ImportedSong(hash:"test-\(index)",filename:"\(index).wav",metadata:metadata,size:0,artwork:nil,folder:"Test fixture"))
            song.favorite = index%10 == 0; song.available = false // No audio files or playable rows are fabricated.
            context.insert(song)
        }
        try context.save()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Song>()),count)
        let target = "Track 00099"
        let exact = FetchDescriptor<Song>(predicate:#Predicate { $0.title == target })
        XCTAssertEqual(try context.fetchCount(exact),1)
        let favorites = FetchDescriptor<Song>(predicate:#Predicate { $0.favorite })
        XCTAssertEqual(try context.fetchCount(favorites),count/10)
        var page = FetchDescriptor<Song>(sortBy:[SortDescriptor(\Song.title)]); page.fetchLimit = 10
        let rows = try context.fetch(page)
        XCTAssertEqual(rows.count,10); XCTAssertEqual(rows.first?.title,"Track 00000"); XCTAssertEqual(rows.last?.title,"Track 00009")
    }
}

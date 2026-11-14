import Foundation

public struct LyricCue:Equatable,Sendable,Identifiable {
    public var id:Double { time }
    public let time:Double
    public let text:String
}
public struct LyricsDocument:Equatable,Sendable {
    public let text:String
    public let cues:[LyricCue]
    public func cue(at seconds:Double)->LyricCue? {
        guard seconds.isFinite else { return nil }
        var low = 0; var high = cues.count
        while low < high { let mid = (low+high)/2; if cues[mid].time <= seconds { low = mid+1 } else { high = mid } }
        return low > 0 ? cues[low-1] : nil
    }
    public static func parse(_ input:String,synchronized:Bool)throws->Self {
        guard input.utf8.count <= 1_048_576 else { throw LyricsError.tooLarge }
        let text = input.replacingOccurrences(of:"\r\n",with:"\n").trimmingCharacters(in:CharacterSet(charactersIn:"\u{feff}"))
        guard synchronized else { return Self(text:text,cues:[]) }
        let expression = try NSRegularExpression(pattern:#"\[(\d{1,5}):([0-5]\d)(?:[.:](\d{1,3}))?\]"#)
        let offsetExpression = try NSRegularExpression(pattern:#"(?i)^\[offset:([+-]?\d+)\]$"#)
        let lines = text.components(separatedBy:"\n")
        var offset = 0.0
        for line in lines {
            let s = line.trimmingCharacters(in:.whitespaces)
            if let match = offsetExpression.firstMatch(in:s,range:NSRange(s.startIndex...,in:s)),let r = Range(match.range(at:1),in:s),let value = Double(s[r]),abs(value) <= 3_600_000 { offset = value/1000 }
        }
        var groups:[Double:[String]] = [:];var plain:[String] = [];var count = 0
        for line in lines {
            let range = NSRange(line.startIndex...,in:line)
            let matches = expression.matches(in:line,range:range)
            if matches.isEmpty {
                if !line.hasPrefix("[ar:") && !line.hasPrefix("[ti:") && !line.hasPrefix("[al:") && !line.hasPrefix("[by:") && !line.lowercased().hasPrefix("[offset:") && !line.hasPrefix("[length:") { plain.append(line) }
                continue
            }
            let words = expression.stringByReplacingMatches(in:line,range:range,withTemplate:"").trimmingCharacters(in:.whitespaces)
            for match in matches {
                count += 1; guard count <= 20000 else { throw LyricsError.tooLarge }
                func part(_ index:Int)->String { Range(match.range(at:index),in:line).map { String(line[$0]) } ?? "" }
                let fraction = part(3)
                let time = max(0,(Double(part(1)) ?? 0)*60+(Double(part(2)) ?? 0)+(fraction.isEmpty ? 0 : (Double(fraction) ?? 0)/pow(10,Double(fraction.count)))+offset)
                groups[time,default:[]].append(words)
            }
        }
        let cues = groups.keys.sorted().map { LyricCue(time:$0,text:groups[$0]!.joined(separator:"\n")) }
        return Self(text:cues.isEmpty ? plain.joined(separator:"\n") : cues.map(\.text).joined(separator:"\n"),cues:cues)
    }
}
public enum LyricsError:Error { case tooLarge, invalidEncoding }

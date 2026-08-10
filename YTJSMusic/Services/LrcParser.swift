// YTJSMusic/Services/LrcParser.swift
import Foundation

public struct LrcParser {
    
    /// Parses a raw LRC string into a sorted array of LyricLine models.
    /// Supports multi-timestamp lines like `[00:12.00][00:45.00]Chorus line`.
    public static func parseSyncedLyrics(_ rawLrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        let rawLines = rawLrc.components(separatedBy: .newlines)
        
        // Regex matching [mm:ss.xx] or [mm:ss:xx] or [mm:ss]
        let timestampRegex = try? NSRegularExpression(pattern: "\\[(\\d+):(\\d+)(?:[\\.:](\\d+))?\\]", options: [])
        
        for rawLine in rawLines {
            let nsLine = rawLine as NSString
            let matches = timestampRegex?.matches(in: rawLine, options: [], range: NSRange(location: 0, length: nsLine.length)) ?? []
            
            guard !matches.isEmpty else { continue }
            
            // Extract the lyric text after all trailing timestamp brackets
            guard let lastMatch = matches.last else { continue }
            let textStartIndex = lastMatch.range.location + lastMatch.range.length
            let lyricText = textStartIndex < nsLine.length ? nsLine.substring(from: textStartIndex).trimmingCharacters(in: .whitespaces) : ""
            
            // Skip metadata tags like [title: ...] or [artist: ...]
            if lyricText.hasPrefix(":") || lyricText.hasPrefix("by:") || lyricText.hasPrefix("al:") {
                continue
            }
            
            // Create a LyricLine for each timestamp tag on this line
            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                
                let minStr = nsLine.substring(with: match.range(at: 1))
                let secStr = nsLine.substring(with: match.range(at: 2))
                
                let mins = Double(minStr) ?? 0.0
                let secs = Double(secStr) ?? 0.0
                
                var frac = 0.0
                if match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound {
                    let fracStr = nsLine.substring(with: match.range(at: 3))
                    if let fracVal = Double(fracStr) {
                        frac = fracVal / (fracStr.count == 3 ? 1000.0 : 100.0)
                    }
                }
                
                let totalSeconds = (mins * 60.0) + secs + frac
                lines.append(LyricLine(timestamp: totalSeconds, text: lyricText))
            }
        }
        
        // Filter out empty lines if desired, or retain for pauses, then sort by timestamp
        return lines.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Parses plain, unsynced text lines into pseudo LyricLine models.
    public static func parsePlainLyrics(_ plainText: String) -> [LyricLine] {
        let rawLines = plainText.components(separatedBy: .newlines)
        var result: [LyricLine] = []
        var dummyTime = 0.0
        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                result.append(LyricLine(timestamp: dummyTime, text: trimmed))
                dummyTime += 4.0 // Spaced 4s apart for reading layout
            }
        }
        return result
    }
}

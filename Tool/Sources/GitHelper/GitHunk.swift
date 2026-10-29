import Foundation

public struct GitHunk {
    public let startDeletedLine: Int // 1-based
    public let deletedLines: Int
    public let startAddedLine: Int // 1-based
    public let addedLines: Int
    public let additions: [(start: Int, length: Int)]
    public let diffText: String
    
    public init(
        startDeletedLine: Int,
        deletedLines: Int,
        startAddedLine: Int,
        addedLines: Int,
        additions: [(start: Int, length: Int)],
        diffText: String
    ) {
        self.startDeletedLine = startDeletedLine
        self.deletedLines = deletedLines
        self.startAddedLine = startAddedLine
        self.addedLines = addedLines
        self.additions = additions
        self.diffText = diffText
    }
}

public extension GitHunk {
    static func parseDiff(_ diff: String) -> [GitHunk] {
        var hunkTexts = diff.components(separatedBy: "\n@@")
        
        if !hunkTexts.isEmpty, hunkTexts.last?.hasSuffix("\n") == true {
            hunkTexts[hunkTexts.count - 1] = String(hunkTexts.last!.dropLast())
        }
        
        let hunks: [GitHunk] = hunkTexts.compactMap { chunk -> GitHunk? in
            let rangePattern = #"-(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))?"#
            let regex = try! NSRegularExpression(pattern: rangePattern)
            let nsString = chunk as NSString
            
            guard let match = regex.firstMatch(
                in: chunk,
                options: [],
                range: NSRange(location: 0, length: nsString.length)
            )
            else { return nil }
            
            var startDeletedLine = Int(nsString.substring(with: match.range(at: 1))) ?? 0
            let deletedLines = match.range(at: 2).location != NSNotFound
                ? Int(nsString.substring(with: match.range(at: 2))) ?? 1
                : 1
            var startAddedLine = Int(nsString.substring(with: match.range(at: 3))) ?? 0
            let addedLines = match.range(at: 4).location != NSNotFound
                ? Int(nsString.substring(with: match.range(at: 4))) ?? 1
                : 1
            
            var additions: [(start: Int, length: Int)] = []
            let lines = Array(chunk.components(separatedBy: "\n").dropFirst())
            var d = 0
            var addStart: Int?
            
            for line in lines {
                let ch = line.first ?? Character(" ")
                
                if ch == "+" {
                    if addStart == nil {
                        addStart = startAddedLine + d
                    }
                    d += 1
                } else {
                    if let start = addStart {
                        additions.append((start: start, length: startAddedLine + d - start))
                        addStart = nil
                    }
                    if ch == " " {
                        d += 1
                    }
                }
            }
            
            if let start = addStart {
                additions.append((start: start, length: startAddedLine + d - start))
            }
            
            if startDeletedLine == 0 {
                startDeletedLine = 1
            }
            
            if startAddedLine == 0 {
                startAddedLine = 1
            }
            
            return GitHunk(
                startDeletedLine: startDeletedLine,
                deletedLines: deletedLines,
                startAddedLine: startAddedLine,
                addedLines: addedLines,
                additions: additions,
                diffText: lines.joined(separator: "\n")
            )
        }
        
        return hunks
    }
}

import Foundation
import SystemUtils

public enum UntrackedFilesOption: String {
    case all, no, normal
}

public struct GitStatus {
    static let unTrackedFilePrefix = "?? "
    
    public static func getStatus(repositoryURL: URL, untrackedFilesOption: UntrackedFilesOption = .all) -> [GitChange] {
        let arguments = ["status", "--porcelain", "--untracked-files=\(untrackedFilesOption.rawValue)"]
        
        let result = try? SystemUtils.executeCommand(
            inDirectory: repositoryURL.path,
            path: GitPath,
            arguments: arguments
        )
        
        if let result = result {
            return Self.parseStatus(statusOutput: result, repositoryURL: repositoryURL)
        } else {
            return []
        }
    }
    
    private static func parseStatus(statusOutput: String, repositoryURL: URL) -> [GitChange] {
        var changes: [GitChange] = []
        let fileManager = FileManager.default
        
        let lines = statusOutput.components(separatedBy: .newlines)
        for line in lines {
            if line.hasPrefix(unTrackedFilePrefix) {
                let fileRelativePath = String(line.dropFirst(unTrackedFilePrefix.count))
                let fileURL = repositoryURL.appendingPathComponent(fileRelativePath)
                
                guard fileManager.fileExists(atPath: fileURL.path) else { continue }
                
                changes.append(
                    .init(url: fileURL, originalURL: fileURL, status: .untracked)
                )
            }
        }
        
        return changes
    }
}

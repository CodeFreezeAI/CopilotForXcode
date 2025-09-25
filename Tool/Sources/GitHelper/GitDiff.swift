import Foundation
import SystemUtils

public enum GitDiffGroup {
    case index // Staged
    case workingTree // Unstaged
}

public struct GitDiff {
    public static func getDiff(of filePath: String, repositoryURL: URL, group: GitDiffGroup) async -> String {
        var arguments = ["diff"]
        if group == .index {
            arguments.append("--cached")
        }
        arguments.append(contentsOf: ["--", filePath])
        
        let result = try? SystemUtils.executeCommand(
            inDirectory: repositoryURL.path, 
            path: GitPath, 
            arguments: arguments
        )
        
        return result ?? ""
    }
    
    public static func getDiffFiles(repositoryURL: URL, group: GitDiffGroup) async -> [GitChange] {
        var arguments = ["diff", "--name-status", "-z", "--diff-filter=ADMR"]
        if group == .index {
            arguments.append("--cached")
        }
        
        let result = try? SystemUtils.executeCommand(
            inDirectory: repositoryURL.path, 
            path: GitPath, 
            arguments: arguments
        )
        
        return result == nil
            ? []
            : Self.parseDiff(repositoryURL: repositoryURL, raw: result!)
    }
    
    private static func parseDiff(repositoryURL: URL, raw: String) -> [GitChange] {
        var index = 0
        var result: [GitChange] = []
        let segments = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "\0")
            .map(String.init)
            .filter { !$0.isEmpty }
        
        segmentsLoop: while index < segments.count - 1 {
            let change = segments[index]
            index += 1
            
            let resourcePath = segments[index]
            index += 1
            
            if change.isEmpty || resourcePath.isEmpty {
                break
            }
            
            let originalURL: URL
            if resourcePath.hasPrefix("/") {
                originalURL = URL(fileURLWithPath: resourcePath)
            } else {
                originalURL = repositoryURL.appendingPathComponent(resourcePath)
            }
            
            var url = originalURL
            var status = GitFileStatus.untracked
            
            // Copy or Rename status comes with a number (ex: 'R100').
            // We don't need the number, we use only first character of the status.
            switch change.first {
            case "A":
                status = .indexAdded

            case "M":
                status = .modified

            case "D":
                status = .deleted
                
            // Rename contains two paths, the second one is what the file is renamed/copied to.
            case "R":
                if index >= segments.count {
                    break
                }
                
                let newPath = segments[index]
                index += 1
                
                if newPath.isEmpty {
                    break
                }
                
                status = .indexRenamed
                if newPath.hasPrefix("/") {
                    url = URL(fileURLWithPath: newPath)
                } else {
                    url = repositoryURL.appendingPathComponent(newPath)
                }
                
            default:
                // Unknown status
                break segmentsLoop
            }
            
            result.append(.init(url: url, originalURL: originalURL, status: status))
        }
        
        return result
    }
}

import Foundation
import LanguageServerProtocol

public struct PRChange: Equatable, Codable {
    public let uri: DocumentUri
    public let path: String
    public let baseContent: String
    public let headContent: String
    
    public var originalContent: String { headContent }
}

public enum CurrentChangeService {
    public static func getPRChanges(
        _ repositoryURL: URL, 
        group: GitDiffGroup,
        shouldIncludeFile: (URL) -> Bool
    ) async -> [PRChange] {
        let gitStats = await GitDiff.getDiffFiles(repositoryURL: repositoryURL, group: group)
        
        var changes: [PRChange] = []
        
        for stat in gitStats {
            guard shouldIncludeFile(stat.url) else { continue }
            
            guard let content = try? String(contentsOf: stat.url, encoding: .utf8)
            else { continue }
            let uri = stat.url.absoluteString
            
            let relativePath = Self.getRelativePath(fileURL: stat.url, repositoryURL: repositoryURL)
            
            switch stat.status {
            case .untracked, .indexAdded:
                changes.append(.init(uri: uri, path: relativePath, baseContent: "", headContent: content))
                
            case .modified:
                guard let originalContent = GitShow.showHeadContent(of: relativePath, repositoryURL: repositoryURL) else {
                    continue
                }
                changes.append(.init(uri: uri, path: relativePath, baseContent: originalContent, headContent: content))
                
            case .deleted, .indexRenamed:
                continue
            }
        }
        
        // Include untracked files
        if group == .workingTree {
            let untrackedGitStats = GitStatus.getStatus(repositoryURL: repositoryURL, untrackedFilesOption: .all)
            for stat in untrackedGitStats {
                guard !changes.contains(where: { $0.uri == stat.url.absoluteString }),
                      let content = try? String(contentsOf: stat.url, encoding: .utf8) 
                else { continue }
                
                let relativePath = Self.getRelativePath(fileURL: stat.url, repositoryURL: repositoryURL)
                changes.append(
                    .init(uri: stat.url.absoluteString, path: relativePath, baseContent: "", headContent: content)
                )
            }
        }
        
        return changes
    }
    
    // TODO: Handle cases of multi-project and referenced file 
    private static func getRelativePath(fileURL: URL, repositoryURL: URL) -> String {
        var relativePath = fileURL.path.replacingOccurrences(of: repositoryURL.path, with: "")
        if relativePath.starts(with: "/") {
            relativePath = String(relativePath.dropFirst())
        }
        
        return relativePath
    }
}

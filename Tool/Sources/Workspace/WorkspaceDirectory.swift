import Foundation
import Logger
import ConversationServiceProvider

/// Directory operations in workspace contexts
public struct WorkspaceDirectory {
    
    /// Determines if a directory should be skipped based on its path
    /// - Parameter url: The URL of the directory to check
    /// - Returns: `true` if the directory should be skipped, `false` otherwise
    public static func shouldSkipDirectory(_ url: URL) -> Bool {
        let path = url.path
        let normalizedPath = path.hasPrefix("/") ? path: "/" + path
        
        for skipPattern in skipPatterns {
            // Pattern: /skipPattern/ (directory anywhere in path)
            if normalizedPath.contains("/\(skipPattern)/") {
                return true
            }
            
            // Pattern: /skipPattern (directory at end of path)
            if normalizedPath.hasSuffix("/\(skipPattern)") {
                return true
            }
            
            // Pattern: skipPattern at root
            if normalizedPath == "/\(skipPattern)" {
                return true
            }
        }
        
        return false
    }
    
    /// Validates if a URL represents a valid directory for workspace operations
    /// - Parameter url: The URL to validate
    /// - Returns: `true` if the directory is valid for processing, `false` otherwise
    public static func isValidDirectory(_ url: URL) -> Bool {
        guard !WorkspaceFile.shouldSkipURL(url) else { 
            return false 
        }
        
        guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
              resourceValues.isDirectory == true else {
            return false
        }
        
        guard !shouldSkipDirectory(url) else {
            return false
        }
        
        return true
    }
    
    /// Retrieves all valid directories within the active workspace
    /// - Parameters:
    ///   - workspaceURL: The URL of the workspace
    ///   - workspaceRootURL: The root URL of the workspace
    /// - Returns: An array of `ConversationDirectoryReference` objects representing valid directories
    public static func getDirectoriesInActiveWorkspace(
        workspaceURL: URL,
        workspaceRootURL: URL
    ) -> [ConversationDirectoryReference] {
        var directories: [ConversationDirectoryReference] = []
        let fileManager = FileManager.default
        var subprojects: [URL] = []
        
        if WorkspaceFile.isXCWorkspace(workspaceURL) {
            subprojects = WorkspaceFile.getSubprojectURLs(in: workspaceURL)
        } else {
            subprojects.append(workspaceRootURL)
        }
        
        for subproject in subprojects {
            guard FileManager.default.fileExists(atPath: subproject.path) else {
                continue
            }
            
            let enumerator = fileManager.enumerator(
                at: subproject,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            while let directoryURL = enumerator?.nextObject() as? URL {
                // Skip items matching the specified pattern
                if WorkspaceFile.shouldSkipURL(directoryURL) {
                    enumerator?.skipDescendants()
                    continue
                }
                
                guard isValidDirectory(directoryURL) else { continue }
                
                let directory = ConversationDirectoryReference(
                    url: directoryURL,
                    projectURL: workspaceRootURL
                )
                directories.append(directory)
            }
        }
        
        return directories
    }
}

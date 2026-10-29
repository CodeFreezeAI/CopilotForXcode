import Foundation
import ConversationServiceProvider

public class WorkspaceDirectoryIndex {
    public static let shared = WorkspaceDirectoryIndex()
    /// Maximum number of directories allowed per workspace
    public static let maxDirectoriesPerWorkspace = 100_000
    
    private var workspaceIndex: [URL: [ConversationDirectoryReference]] = [:]
    private let queue = DispatchQueue(label: "com.copilot.workspace-directory-index")
    
    /// Reset directories for a specific workspace URL
    public func setDirectories(_ directories: [ConversationDirectoryReference], for workspaceURL: URL) {
        queue.sync {
            // Enforce the directory limit when setting directories
            if directories.count > Self.maxDirectoriesPerWorkspace {
                self.workspaceIndex[workspaceURL] = Array(directories.prefix(Self.maxDirectoriesPerWorkspace))
            } else {
                self.workspaceIndex[workspaceURL] = directories
            }
        }
    }
    
    /// Get all directories for a specific workspace URL
    public func getDirectories(for workspaceURL: URL) -> [ConversationDirectoryReference]? {
        return queue.sync {
            return workspaceIndex[workspaceURL]?.map { $0 }
        }
    }
    
    /// Add a directory to the workspace index
    /// - Returns: true if the directory was added successfully, false if the workspace has reached the maximum directory limit
    @discardableResult
    public func addDirectory(_ directory: ConversationDirectoryReference, to workspaceURL: URL) -> Bool {
        return queue.sync {
            if self.workspaceIndex[workspaceURL] == nil {
                self.workspaceIndex[workspaceURL] = []
            }
            
            guard var directories = self.workspaceIndex[workspaceURL] else {
                return false
            }
            
            // Check if we've reached the maximum directory limit
            let currentDirectoryCount = directories.count
            if currentDirectoryCount >= Self.maxDirectoriesPerWorkspace {
                return false
            }
            
            // Avoid duplicates by checking if directory already exists
            if !directories.contains(directory) {
                directories.append(directory)
                self.workspaceIndex[workspaceURL] = directories
            }
            
            return true // Directory already exists, so we consider this a successful "add"
        }
    }
    
    /// Remove a directory from the workspace index
    public func removeDirectory(_ directory: ConversationDirectoryReference, from workspaceURL: URL) {
        queue.sync {
            self.workspaceIndex[workspaceURL]?.removeAll { $0 == directory }
        }
    }
    
    /// Init index for workspace
    public func initIndexFor(_ workspaceURL: URL, projectURL: URL) {
        let directories = WorkspaceDirectory.getDirectoriesInActiveWorkspace(
            workspaceURL: workspaceURL,
            workspaceRootURL: projectURL
        )
        setDirectories(directories, for: workspaceURL)
    }
}

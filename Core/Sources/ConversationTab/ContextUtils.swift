import ConversationServiceProvider
import XcodeInspector
import Foundation
import Logger
import Workspace
import SystemUtils

public struct ContextUtils {

    public static func getFilesFromWorkspaceIndex(workspaceURL: URL?) -> [ConversationAttachedReference]? {
        guard let workspaceURL = workspaceURL else { return nil }
        
        var references: [ConversationAttachedReference]?
        
        if let directories = WorkspaceDirectoryIndex.shared.getDirectories(for: workspaceURL) {
            references = directories
                .sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
                .map { .directory($0) }
        }
        
        if let files = WorkspaceFileIndex.shared.getFiles(for: workspaceURL) {
            references = (references ?? []) + files
                .sorted { $0.url.lastPathComponent < $1.url.lastPathComponent }
                .map { .file($0) }
        }
        
        
        return references
    }

    public static func getFilesInActiveWorkspace(workspaceURL: URL?) -> [ConversationFileReference] {
        if let workspaceURL = workspaceURL, let info = WorkspaceFile.getWorkspaceInfo(workspaceURL: workspaceURL) {
            return WorkspaceFile.getFilesInActiveWorkspace(workspaceURL: info.workspaceURL, workspaceRootURL: info.projectURL)
        }

        guard let workspaceURL = XcodeInspector.shared.realtimeActiveWorkspaceURL,
              let workspaceRootURL = XcodeInspector.shared.realtimeActiveProjectURL else {
            return []
        }
        
        let files = WorkspaceFile.getFilesInActiveWorkspace(workspaceURL: workspaceURL, workspaceRootURL: workspaceRootURL)
        
        return files
    }
    
    public static let workspaceReadabilityErrorMessageProvider: FileUtils.ReadabilityErrorMessageProvider = { status in
        switch status {
        case .readable: return nil
        case .notFound: 
            return "Copilot can't access this workspace. It may have been removed or is temporarily unavailable."
        case .permissionDenied: 
            return "Copilot can't access this workspace. Enable \"Files & Folders\" access in [System Settings](x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders)"
        }
    }
}

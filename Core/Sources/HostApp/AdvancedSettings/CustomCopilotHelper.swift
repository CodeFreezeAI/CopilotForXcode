import AppKit
import Client
import Foundation
import SwiftUI
import Toast
import XcodeInspector
import SystemUtils

public enum PromptType: String, CaseIterable, Equatable {
    case instructions = "instructions"
    case prompt = "prompt"
    
    /// The directory name under .github where files of this type are stored
    var directoryName: String {
        switch self {
        case .instructions:
            return "instructions"
        case .prompt:
            return "prompts"
        }
    }
    
    /// The file extension for this prompt type
    var fileExtension: String {
        switch self {
        case .instructions:
            return ".instructions.md"
        case .prompt:
            return ".prompt.md"
        }
    }
    
    /// Human-readable name for display purposes
    var displayName: String {
        switch self {
        case .instructions:
            return "Instruction File"
        case .prompt:
            return "Prompt File"
        }
    }
    
    /// Human-readable name for settings
    var settingTitle: String {
        switch self {
        case .instructions:
            return "Custom Instructions"
        case .prompt:
            return "Prompt Files"
        }
    }
    
    /// Description for the prompt type
    var description: String {
        switch self {
        case .instructions:
            return "Configure `.github/instructions/*.instructions.md` files scoped to specific file patterns or tasks."
        case .prompt:
            return "Configure `.github/prompts/*.prompt.md` files for reusable prompts. Trigger with '/' commands in the Chat view."
        }
    }
    
    /// Default template content for new files
    var defaultTemplate: String {
        switch self {
        case .instructions:
            return """
            ---
            applyTo: '**'
            ---
            Provide project context and coding guidelines that AI should follow when generating code, or answering questions.

            """
        case .prompt:
            return """
            ---
            description: Prompt Description
            ---
            Define the task to achieve, including specific requirements, constraints, and success criteria.

            """
        }
    }
    
    var helpLink: String {
        var editorPluginVersion = SystemUtils.editorPluginVersionString
        if editorPluginVersion == "0.0.0" {
            editorPluginVersion = "main"
        }
        
        switch self {
        case .instructions:
            return "https://github.com/github/CopilotForXcode/blob/\(editorPluginVersion)/Docs/CustomInstructions.md"
        case .prompt:
            return "https://github.com/github/CopilotForXcode/blob/\(editorPluginVersion)/Docs/PromptFiles.md"
        }
    }
    
    /// Get the full file path for a given name and project URL
    func getFilePath(fileName: String, projectURL: URL) -> URL {
        let directory = getDirectoryPath(projectURL: projectURL)
        return directory.appendingPathComponent("\(fileName)\(fileExtension)")
    }
    
    /// Get the directory path for this prompt type
    func getDirectoryPath(projectURL: URL) -> URL {
        return projectURL.appendingPathComponent(".github/\(directoryName)")
    }
}

func getCurrentProjectURL() async -> URL? {
    let service = try? getService()
    let inspectorData = try? await service?.getXcodeInspectorData()
    var currentWorkspace: URL?

    if let url = inspectorData?.realtimeActiveWorkspaceURL,
       let workspaceURL = URL(string: url),
       workspaceURL.path != "/" {
        currentWorkspace = workspaceURL
    } else if let url = inspectorData?.latestNonRootWorkspaceURL {
        currentWorkspace = URL(string: url)
    }

    guard let workspaceURL = currentWorkspace,
          let projectURL = WorkspaceXcodeWindowInspector.extractProjectURL(
              workspaceURL: workspaceURL,
              documentURL: nil
          ) else {
        return nil
    }

    return projectURL
}

func ensureDirectoryExists(at url: URL) throws {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: url.path) {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
}

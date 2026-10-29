import ConversationServiceProvider
import Foundation
import GitHubCopilotService
import JSONRPC
import SystemUtils
import LanguageServerProtocol

public class CurrentEditorSkill: ConversationSkill {
    public static let ID = "current-editor"
    public let currentFile: ConversationFileReference
    public var id: String {
        return CurrentEditorSkill.ID
    }
    public var currentFilePath: String { currentFile.url.path }
    
    public init(
        currentFile: ConversationFileReference
    ) {
        self.currentFile = currentFile
    }

    public func applies(params: ConversationContextParams) -> Bool {
        return params.skillId == self.id
    }
    
    public static let readabilityErrorMessageProvider: FileUtils.ReadabilityErrorMessageProvider = { status in
        switch status {
        case .readable:
            return nil
        case .notFound:
            return "Copilot can’t find the current file, so it's not included."
        case .permissionDenied:
            return "Copilot can't access the current file. Enable \"Files & Folders\" access in [System Settings](x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders)."
        }
    }
    
    public func resolveSkill(request: ConversationContextRequest, completion: JSONRPCResponseHandler){
        let uri: String? = self.currentFile.url.absoluteString
        let response: JSONValue
        
        if let fileSelection = currentFile.selection {
            let start = fileSelection.start
            let end = fileSelection.end
            response = .hash([
                "uri": .string(uri ?? ""),
                "selection": .hash([
                    "start": .hash(["line": .number(Double(start.line)), "character": .number(Double(start.character))]),
                    "end": .hash(["line": .number(Double(end.line)), "character": .number(Double(end.character))])
                ])
            ])
        } else {
            // No text selection - only include file URI without selection metadata
            response = .hash(["uri": .string(uri ?? "")])
        }
        
        completion(
            AnyJSONRPCResponse(
                id: request.id,
                result: JSONValue.array([response, JSONValue.null]))
        )
    }
}

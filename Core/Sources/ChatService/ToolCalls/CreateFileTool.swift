import JSONRPC
import AppKit
import ConversationServiceProvider
import Foundation
import Logger

public class CreateFileTool: ICopilotTool {
    public static let name = ToolName.createFile
    
    public func invokeTool(
        _ request: InvokeClientToolRequest,
        completion: @escaping (AnyJSONRPCResponse) -> Void,
        chatHistoryUpdater: ChatHistoryUpdater?,
        contextProvider: (any ToolContextProvider)?
    ) -> Bool {
        guard let params = request.params,
              let input = params.input,
              let filePath = input["filePath"]?.value as? String,
              let content = input["content"]?.value as? String
        else {
            completeResponse(request, status: .error, response: "Invalid parameters", completion: completion)
            return true
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        
        guard !FileManager.default.fileExists(atPath: filePath)
        else {
            Logger.client.info("CreateFileTool: File already exists at \(filePath)")
            completeResponse(request, status: .error, response: "File already exists at \(filePath)", completion: completion)
            return true
        }
        
        do {
            // Create intermediate directories if they don't exist
            let parentDirectory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            Logger.client.error("CreateFileTool: Failed to write content to file at \(filePath): \(error)")
            completeResponse(request, status: .error, response: "Failed to write content to file: \(error)", completion: completion)
            return true
        }
        
        guard FileManager.default.fileExists(atPath: filePath),
              let writtenContent = try? String(contentsOf: fileURL, encoding: .utf8)
        else {
            Logger.client.info("CreateFileTool: Failed to verify file creation at \(filePath)")
            completeResponse(request, status: .error, response: "Failed to verify file creation.", completion: completion)
            return true
        }
        
        contextProvider?.updateFileEdits(by: .init(
            fileURL: URL(fileURLWithPath: filePath),
            originalContent: "",
            modifiedContent: writtenContent,
            toolName: CreateFileTool.name
        ))
        
        NSWorkspace.openFileInXcode(fileURL: URL(fileURLWithPath: filePath)) { _, error in
            if let error = error {
                Logger.client.info("Failed to open file at \(filePath), \(error)")
            }
        }
        
        let editAgentRounds: [AgentRound] = [
            .init(
                roundId: params.roundId,
                reply: "",
                toolCalls: [
                    .init(
                        id: params.toolCallId,
                        name: params.name,
                        status: .completed,
                        invokeParams: params
                    )
                ]
            )
        ]

        if let chatHistoryUpdater {
            chatHistoryUpdater(params.turnId, editAgentRounds)
        }
        
        completeResponse(
            request,
            response: "File created at \(filePath).",
            completion: completion
        )
        return true
    }
    
    public static func undo(for fileURL: URL) throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
              !isDirectory.boolValue
        else { return }
        
        try FileManager.default.removeItem(at: fileURL)
    }
}

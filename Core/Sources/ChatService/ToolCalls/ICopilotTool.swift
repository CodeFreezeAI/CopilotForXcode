import ChatTab
import ConversationServiceProvider
import Foundation
import JSONRPC

public protocol ToolContextProvider {
    // MARK: insert_edit_into_file
    var chatTabInfo: ChatTabInfo { get }
    func updateFileEdits(by fileEdit: FileEdit) -> Void
    func notifyChangeTextDocument(fileURL: URL, content: String, version: Int) async throws
}

public typealias ChatHistoryUpdater = (String, [AgentRound]) -> Void

public protocol ICopilotTool {
    /**
      * Invokes the Copilot tool with the given request.
      *  - Parameters:
      *      - request: The tool invocation request.
      *      - completion: Closure called with JSON-RPC response when tool execution completes.
      *      - chatHistoryUpdater: Optional closure to update chat history during tool execution.
      *      - contextProvider: Optional provider that supplies additional context information
      *                         needed for tool execution, such as chat tab data and file editing capabilities.
      *  - Returns: Boolean indicating if the tool call has completed. True if the tool call is completed, false otherwise.
     */
    func invokeTool(
        _ request: InvokeClientToolRequest,
        completion: @escaping (AnyJSONRPCResponse) -> Void,
        chatHistoryUpdater: ChatHistoryUpdater?,
        contextProvider: ToolContextProvider?
    ) -> Bool
}

extension ICopilotTool {
    /**
     * Completes a tool response.
     * - Parameters:
     *   - request: The original tool invocation request.
     *   - status: The completion status of the tool execution (success, error, or cancelled).
     *   - response: The string value to include in the response content.
     *   - completion: The completion handler to call with the response.
     */
    func completeResponse(
        _ request: InvokeClientToolRequest,
        status: ToolInvocationStatus = .success,
        response: String = "",
        completion: @escaping (AnyJSONRPCResponse) -> Void
    ) {
        completeResponses(
            request,
            status: status,
            responses: [response],
            completion: completion
        )
    }

    ///
    /// Completes a tool response with multiple data entries.
    /// - Parameters:
    ///   - request: The original tool invocation request.
    ///   - status: The completion status of the tool execution (success, error, or cancelled).
    ///   - responses: Array of string values to include in the response content.
    ///   - completion: The completion handler to call with the response.
    ///
    func completeResponses(
        _ request: InvokeClientToolRequest,
        status: ToolInvocationStatus = .success,
        responses: [String],
        completion: @escaping (AnyJSONRPCResponse) -> Void
    ) {
        let toolResult = LanguageModelToolResult(status: status, content: responses.map { response in
            LanguageModelToolResult.Content(value: response)
        })
        let jsonResult = try? JSONEncoder().encode(toolResult)
        let jsonValue = (try? JSONDecoder().decode(JSONValue.self, from: jsonResult ?? Data())) ?? JSONValue.null
        completion(
            AnyJSONRPCResponse(
                id: request.id,
                result: JSONValue.array([
                    jsonValue,
                    JSONValue.null,
                ])
            )
        )
    }
}

extension ChatService: ToolContextProvider { }

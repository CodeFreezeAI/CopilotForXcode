import Foundation
import ConversationServiceProvider
import Combine
import JSONRPC
import LanguageClient
import LanguageServerProtocol
import Logger

public typealias ResponseHandler = ServerRequest.Handler<JSONValue>
public typealias LegacyResponseHandler = (AnyJSONRPCResponse) -> Void

protocol ServerRequestHandler {
    func handleRequest(_ request: AnyJSONRPCRequest, workspaceURL: URL, callback: @escaping ResponseHandler, service: GitHubCopilotService?)
}

class ServerRequestHandlerImpl : ServerRequestHandler {
    public static let shared = ServerRequestHandlerImpl()
    private let conversationContextHandler: ConversationContextHandler = ConversationContextHandlerImpl.shared
    private let watchedFilesHandler: WatchedFilesHandler = WatchedFilesHandlerImpl.shared
    private let showMessageRequestHandler: ShowMessageRequestHandler = ShowMessageRequestHandlerImpl.shared
    private let mcpOAuthRequestHandler: MCPOAuthRequestHandler = MCPOAuthRequestHandlerImpl.shared

    func handleRequest(_ request: AnyJSONRPCRequest, workspaceURL: URL, callback: @escaping ResponseHandler, service: GitHubCopilotService?) {
        let methodName = request.method
        let legacyResponseHandler = toLegacyResponseHandler(callback)
        do {
            switch methodName {
            case "conversation/context":
                let params = try JSONEncoder().encode(request.params)
                let contextParams = try JSONDecoder().decode(ConversationContextParams.self, from: params)
                conversationContextHandler.handleConversationContext(
                    ConversationContextRequest(id: request.id, method: request.method, params: contextParams),
                    completion: legacyResponseHandler)
                
            case "copilot/watchedFiles":
                let params = try JSONEncoder().encode(request.params)
                let watchedFilesParams = try JSONDecoder().decode(WatchedFilesParams.self, from: params)
                watchedFilesHandler.handleWatchedFiles(WatchedFilesRequest(id: request.id, method: request.method, params: watchedFilesParams), workspaceURL: workspaceURL, completion: legacyResponseHandler, service: service)
                
            case "window/showMessageRequest":
                let params = try JSONEncoder().encode(request.params)
                let showMessageRequestParams = try JSONDecoder().decode(ShowMessageRequestParams.self, from: params)
                showMessageRequestHandler
                    .handleShowMessage(
                        ShowMessageRequest(
                            id: request.id,
                            method: request.method,
                            params: showMessageRequestParams
                        ),
                        completion: legacyResponseHandler
                    )

            case "conversation/invokeClientTool":
                let params = try JSONEncoder().encode(request.params)
                let invokeParams = try JSONDecoder().decode(InvokeClientToolParams.self, from: params)
                ClientToolHandlerImpl.shared.invokeClientTool(InvokeClientToolRequest(id: request.id, method: request.method, params: invokeParams), completion: legacyResponseHandler)

            case "conversation/invokeClientToolConfirmation":
                let params = try JSONEncoder().encode(request.params)
                let invokeParams = try JSONDecoder().decode(InvokeClientToolParams.self, from: params)
                ClientToolHandlerImpl.shared.invokeClientToolConfirmation(InvokeClientToolConfirmationRequest(id: request.id, method: request.method, params: invokeParams), completion: legacyResponseHandler)

            case "copilot/mcpOAuth":
                let params = try JSONEncoder().encode(request.params)
                let mcpOAuthRequestParams = try JSONDecoder().decode(MCPOAuthRequestParams.self, from: params)
                mcpOAuthRequestHandler.handleShowOAuthMessage(
                    MCPOAuthRequest(
                        id: request.id,
                        method: request.method,
                        params: mcpOAuthRequestParams
                    ),
                    completion: legacyResponseHandler
                )

            default:
                break
            }
        } catch {
            handleError(request, error: error, callback: legacyResponseHandler)
        }
    }
    
    private func handleError(_ request: AnyJSONRPCRequest, error: Error, callback: @escaping (AnyJSONRPCResponse) -> Void) {
        callback(
            AnyJSONRPCResponse(
                id: request.id,
                result: JSONValue.array([
                    JSONValue.null,
                    JSONValue.hash([
                        "code": .number(-32602/* Invalid params */),
                        "message": .string("Error: \(error.localizedDescription)")])
                ])
            )
        )
        Logger.gitHubCopilot.error(error)
    }
    
    /// Converts a new Handler to work with old code that expects LegacyResponseHandler
    private func toLegacyResponseHandler(
        _ newHandler: @escaping ResponseHandler
    ) -> LegacyResponseHandler {
        return { response in
            Task {
                if let error = response.error {
                    await newHandler(.failure(error))
                } else if let result = response.result {
                    await newHandler(.success(result))
                }
            }
        }
    }
}

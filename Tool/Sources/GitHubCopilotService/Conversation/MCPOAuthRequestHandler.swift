import JSONRPC
import Foundation
import Combine
import Logger
import AppKit

public protocol MCPOAuthRequestHandler {
    func handleShowOAuthMessage(
        _ request: MCPOAuthRequest,
        completion: @escaping (
            AnyJSONRPCResponse
        ) -> Void
    )
}

public final class MCPOAuthRequestHandlerImpl: MCPOAuthRequestHandler {
    public static let shared = MCPOAuthRequestHandlerImpl()

    public func handleShowOAuthMessage(_ request: MCPOAuthRequest, completion: @escaping (AnyJSONRPCResponse) -> Void) {
        guard let params = request.params else { return }
        Logger.gitHubCopilot.debug("Received MCP OAuth Request: \(params)")
        Task { @MainActor in
            let confirmResult = showMCPOAuthAlert(params)
            let jsonResult = try? JSONEncoder().encode(MCPOAuthResponse(confirm: confirmResult))
            let jsonValue = (try? JSONDecoder().decode(JSONValue.self, from: jsonResult ?? Data())) ?? JSONValue.null
            completion(AnyJSONRPCResponse(id: request.id, result: jsonValue))
        }
    }
    
    @MainActor
    func showMCPOAuthAlert(_ params: MCPOAuthRequestParams) -> Bool {
        let alert = NSAlert()
        let mcpConfigString = UserDefaults.shared.value(for: \.gitHubCopilotMCPConfig)
        
        var serverName = params.mcpServer // Default fallback
        
        if let mcpConfigData = mcpConfigString.data(using: .utf8),
           let mcpConfig = try? JSONDecoder().decode(JSONValue.self, from: mcpConfigData) {
            // Iterate through the servers to find a match for the mcpServer URL
            if case .hash(let serversDict) = mcpConfig {
                for (userDefinedName, serverConfig) in serversDict {
                    if let url = serverConfig["url"]?.stringValue {
                        // Check if the mcpServer URL matches the configured URL
                        if params.mcpServer.contains(url) || url.contains(params.mcpServer) {
                            serverName = userDefinedName
                            break
                        }
                    }
                }
            }
        }

        alert.messageText = "GitHub Copilot"
        alert.informativeText = "The MCP Server Definition '\(serverName)' wants to authenticate to \(params.authLabel)."
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return true
        } else {
            return false
        }
    }
}

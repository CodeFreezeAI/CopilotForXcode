import ConversationServiceProvider
import Foundation
import JSONRPC
import Terminal

public class GetTerminalOutputTool: ICopilotTool {
    public func invokeTool(_ request: InvokeClientToolRequest, completion: @escaping (AnyJSONRPCResponse) -> Void, contextProvider: (any ToolContextProvider)?) -> Bool {
        var result: String = ""
        if let input = request.params?.input as? [String: AnyCodable], let terminalId = input["id"]?.value as? String{
            let session = TerminalSessionManager.shared.getSession(for: terminalId)
            result = session?.getCommandOutput() ?? "Terminal id \(terminalId) not found"
        } else {
            result = "Invalid arguments for \(ToolName.getTerminalOutput.rawValue) tool call"
        }

        let toolResult = LanguageModelToolResult(content: [
            .init(value: result)
        ])
        let jsonResult = try? JSONEncoder().encode(toolResult)
        let jsonValue = (try? JSONDecoder().decode(JSONValue.self, from: jsonResult ?? Data())) ?? JSONValue.null
        completion(
            AnyJSONRPCResponse(
                id: request.id,
                result: JSONValue.array([
                    jsonValue,
                    JSONValue.null
                ])
            )
        )

        return true
    }
}

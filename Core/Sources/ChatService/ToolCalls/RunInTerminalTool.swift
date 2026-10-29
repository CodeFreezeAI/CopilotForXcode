import ConversationServiceProvider
import Terminal
import XcodeInspector
import JSONRPC

public class RunInTerminalTool: ICopilotTool {
    public func invokeTool(_ request: InvokeClientToolRequest, completion: @escaping (AnyJSONRPCResponse) -> Void, contextProvider: (any ToolContextProvider)?) -> Bool {
        let params = request.params!
        
        Task {
            var currentDirectory: String = ""
            if let workspacePath = contextProvider?.chatTabInfo.workspacePath,
               let xcodeIntance = Utils.getXcode(by: workspacePath) {
                currentDirectory = xcodeIntance.realtimeProjectURL?.path ?? xcodeIntance.projectRootURL?.path ?? ""
            } else {
                currentDirectory = await XcodeInspector.shared.safe.realtimeActiveProjectURL?.path ?? ""
            }
            if let input = params.input {
                let command = input["command"]?.value as? String
                let isBackground = input["isBackground"]?.value as? Bool
                let toolId = params.toolCallId
                let session = TerminalSessionManager.shared.createSession(for: toolId)
                if isBackground == true {
                    session.executeCommand(
                        currentDirectory: currentDirectory,
                        command: command!) { result in
                            // do nothing
                        }
                    completeResponse(request, response: "Command is running in terminal with ID=\(toolId)", completion: completion)
                } else {
                    session.executeCommand(
                        currentDirectory: currentDirectory,
                        command: command!) { result in
                            self.completeResponse(request, response: result.output, completion: completion)
                        }
                }
            }
        }

        return true
    }
}

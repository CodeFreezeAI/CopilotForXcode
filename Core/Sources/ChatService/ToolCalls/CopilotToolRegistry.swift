import ConversationServiceProvider

public class CopilotToolRegistry {
    public static let shared = CopilotToolRegistry()
    private var tools: [String: ICopilotTool] = [:]

    private init() {
        tools[ToolName.runInTerminal.rawValue] = RunInTerminalTool()
        tools[ToolName.getTerminalOutput.rawValue] = GetTerminalOutputTool()
        tools[ToolName.getErrors.rawValue] = GetErrorsTool()
        tools[ToolName.insertEditIntoFile.rawValue] = InsertEditIntoFileTool()
        tools[ToolName.createFile.rawValue] = CreateFileTool()
        tools[ToolName.fetchWebPage.rawValue] = FetchWebPageTool()
    }

    public func getTool(name: String) -> ICopilotTool? {
        return tools[name]
    }
}

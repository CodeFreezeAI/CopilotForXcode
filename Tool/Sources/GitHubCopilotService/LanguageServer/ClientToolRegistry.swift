
import ConversationServiceProvider

func registerClientTools(server: GitHubCopilotConversationServiceType) async -> [LanguageModelTool] {
    var tools: [LanguageModelToolInformation] = []
    let runInTerminalTool = LanguageModelToolInformation(
        name: ToolName.runInTerminal.rawValue,
        description: "Run a shell command in a terminal. State is persistent across tool calls.\n- Use this tool instead of printing a shell codeblock and asking the user to run it.\n- If the command is a long-running background process, you MUST pass isBackground=true. Background terminals will return a terminal ID which you can use to check the output of a background process with get_terminal_output.\n- If a command may use a pager, you must something to disable it. For example, you can use `git --no-pager`. Otherwise you should add something like ` | cat`. Examples: git, less, man, etc.",
        inputSchema: LanguageModelToolSchema(
            type: "object",
            properties: [
                "command": ToolInputPropertySchema(
                    type: "string",
                    description: "The command to run in the terminal."),
                "explanation": ToolInputPropertySchema(
                    type: "string",
                    description: "A one-sentence description of what the command does. This will be shown to the user before the command is run."),
                "isBackground": ToolInputPropertySchema(
                    type: "boolean",
                    description: "Whether the command starts a background process. If true, the command will run in the background and you will not see the output. If false, the tool call will block on the command finishing, and then you will get the output. Examples of background processes: building in watch mode, starting a server. You can check the output of a background process later on by using get_terminal_output.")
            ],
            required: [
                "command",
                "explanation",
                "isBackground"
            ]),
        confirmationMessages: LanguageModelToolConfirmationMessages(
            title: "Run command In Terminal",
            message: "Run command In Terminal"
        )
    )
    let getErrorsTool: LanguageModelToolInformation = .init(
        name: ToolName.getErrors.rawValue,
        description: "Get any compile or lint errors in a code file. If the user mentions errors or problems in a file, they may be referring to these. Use the tool to see the same errors that the user is seeing. Also use this tool after editing a file to validate the change.",
        inputSchema: .init(
            type: "object",
            properties: [
                "filePaths": .init(
                    type: "array",
                    description: "The absolute paths to the files to check for errors.",
                    items: .init(type: "string")
                )
            ],
            required: ["filePaths"]
        )
    )

    let getTerminalOutputTool = LanguageModelToolInformation(
        name: ToolName.getTerminalOutput.rawValue,
        description: "Get the output of a terminal command previously started using run_in_terminal",
        inputSchema: LanguageModelToolSchema(
            type: "object",
            properties: [
                "id": ToolInputPropertySchema(
                    type: "string",
                    description: "The ID of the terminal command output to check."
                )
            ],
            required: [
                "id"
            ])
        )
    
    let createFileTool: LanguageModelToolInformation = .init(
        name: ToolName.createFile.rawValue,
        description: "This is a tool for creating a new file in the workspace. The file will be created with the specified content.",
        inputSchema: .init(
            type: "object",
            properties: [
                "filePath": .init(
                    type: "string",
                    description: "The absolute path to the file to create."
                ),
                "content": .init(
                    type: "string",
                    description: "The content to write to the file."
                )
            ],
            required: ["filePath", "content"]
        )
    )

    let insertEditIntoFileTool: LanguageModelToolInformation = .init(
        name: ToolName.insertEditIntoFile.rawValue,
        description: "Insert new code into an existing file in the workspace. Use this tool once per file that needs to be modified, even if there are multiple changes for a file. Generate the \"explanation\" property first.\nThe system is very smart and can understand how to apply your edits to the files, you just need to provide minimal hints.\nAvoid repeating existing code, instead use comments to represent regions of unchanged code. Be as concise as possible. For example:\n// ...existing code...\n{ changed code }\n// ...existing code...\n{ changed code }\n// ...existing code...\n\nHere is an example of how you should use format an edit to an existing Person class:\nclass Person {\n\t// ...existing code...\n\tage: number;\n\t// ...existing code...\n\tgetAge() {\n\treturn this.age;\n\t}\n}",
        inputSchema: .init(
            type: "object",
            properties: [
                "filePath": .init(type: "string", description: "An absolute path to the file to edit."),
                "code": .init(type: "string", description: "The code change to apply to the file.\nThe system is very smart and can understand how to apply your edits to the files, you just need to provide minimal hints.\nAvoid repeating existing code, instead use comments to represent regions of unchanged code. Be as concise as possible. For example:\n// ...existing code...\n{ changed code }\n// ...existing code...\n{ changed code }\n// ...existing code...\n\nHere is an example of how you should use format an edit to an existing Person class:\nclass Person {\n\t// ...existing code...\n\tage: number;\n\t// ...existing code...\n\tgetAge() {\n\t\treturn this.age;\n\t}\n}"),
                "explanation": .init(type: "string", description: "A short explanation of the edit being made.")
            ],
            required: ["filePath", "code", "explanation"]
        )
    )

    let fetchWebPageTool: LanguageModelToolInformation = .init(
        name: ToolName.fetchWebPage.rawValue,
        description: "Fetches the main content from a web page. This tool is useful for summarizing or analyzing the content of a webpage.",
        inputSchema: .init(
            type: "object",
            properties: [
                "urls": .init(
                    type: "array",
                    description: "An array of web page URLs to fetch content from.",
                    items: .init(type: "string")
                ),
            ],
            required: ["urls"]
        ),
        confirmationMessages: LanguageModelToolConfirmationMessages(
            title: "Fetch Web Page",
            message: "Web content may contain malicious code or attempt prompt injection attacks."
        )
    )
    
    tools.append(runInTerminalTool)
    tools.append(getTerminalOutputTool)
    tools.append(getErrorsTool)
    tools.append(insertEditIntoFileTool)
    tools.append(createFileTool)
    tools.append(fetchWebPageTool)

    if !tools.isEmpty {
        let response = try? await server.registerTools(tools: tools)
        return response ?? []
    }
    
    return []
}

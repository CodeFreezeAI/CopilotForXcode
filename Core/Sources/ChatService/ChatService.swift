import ChatAPIService
import Combine
import Foundation
import GitHubCopilotService
import Preferences
import ConversationServiceProvider
import BuiltinExtension
import JSONRPC
import Status
import Persist
import PersistMiddleware
import ChatTab
import Logger
import Workspace
import XcodeInspector
import OrderedCollections
import SystemUtils
import GitHelper
import LanguageServerProtocol
import SuggestionBasic

public protocol ChatServiceType {
    var memory: ContextAwareAutoManagedChatMemory { get set }
    func send(
        _ id: String,
        content: String,
        contentImages: [ChatCompletionContentPartImage],
        contentImageReferences: [ImageReference],
        skillSet: [ConversationSkill],
        references: [ConversationAttachedReference],
        model: String?,
        modelProviderName: String?,
        agentMode: Bool,
        userLanguage: String?,
        turnId: String?
    ) async throws
    func stopReceivingMessage() async
    func upvote(_ id: String, _ rating: ConversationRating) async
    func downvote(_ id: String, _ rating: ConversationRating) async
    func copyCode(_ id: String) async
}

struct ToolCallRequest {
    let requestId: JSONId
    let turnId: String
    let roundId: Int
    let toolCallId: String
    let completion: (AnyJSONRPCResponse) -> Void
}

public struct FileEdit: Equatable {
    
    public enum Status: String {
        case none = "none"
        case kept = "kept"
        case undone = "undone"
    }
    
    public let fileURL: URL
    public let originalContent: String
    public var modifiedContent: String
    public var status: Status
    
    /// Different toolName, the different undo logic. Like `insert_edit_into_file` and `create_file`
    public var toolName: ToolName
    
    public init(
        fileURL: URL,
        originalContent: String,
        modifiedContent: String,
        status: Status = .none,
        toolName: ToolName
    ) {
        self.fileURL = fileURL
        self.originalContent = originalContent
        self.modifiedContent = modifiedContent
        self.status = status
        self.toolName = toolName
    }
}

public final class ChatService: ChatServiceType, ObservableObject {
    
    public enum RequestType: String, Equatable {
        case conversation, codeReview
    }
    
    public var memory: ContextAwareAutoManagedChatMemory
    @Published public internal(set) var chatHistory: [ChatMessage] = []
    @Published public internal(set) var isReceivingMessage = false
    @Published public internal(set) var fileEditMap: OrderedDictionary<URL, FileEdit> = [:]
    public internal(set) var requestType: RequestType? = nil
    public private(set) var chatTabInfo: ChatTabInfo
    private let conversationProvider: ConversationServiceProvider?
    private let conversationProgressHandler: ConversationProgressHandler
    private let conversationContextHandler: ConversationContextHandler = ConversationContextHandlerImpl.shared
    // sync all the files in the workspace to watch for changes.
    private let watchedFilesHandler: WatchedFilesHandler = WatchedFilesHandlerImpl.shared
    private var cancellables = Set<AnyCancellable>()
    private var activeRequestId: String?
    private(set) public var conversationId: String?
    private var skillSet: [ConversationSkill] = []
    private var lastUserRequest: ConversationRequest?
    private var isRestored: Bool = false
    private var pendingToolCallRequests: [String: ToolCallRequest] = [:]
    init(provider: any ConversationServiceProvider,
         memory: ContextAwareAutoManagedChatMemory = ContextAwareAutoManagedChatMemory(),
         conversationProgressHandler: ConversationProgressHandler = ConversationProgressHandlerImpl.shared,
         chatTabInfo: ChatTabInfo) {
        self.memory = memory
        self.conversationProvider = provider
        self.conversationProgressHandler = conversationProgressHandler
        self.chatTabInfo = chatTabInfo
        memory.chatService = self
        
        subscribeToNotifications()
        subscribeToConversationContextRequest()
        subscribeToClientToolInvokeEvent()
        subscribeToClientToolConfirmationEvent()
    }
    
    deinit {
        Task { [weak self] in
            await self?.stopReceivingMessage()
        }
        
        // Clear all subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // Memory will be deallocated automatically
    }
    
    public func updateChatTabInfo(_ tabInfo: ChatTabInfo) {
        // Only isSelected need to be updated
        chatTabInfo.isSelected = tabInfo.isSelected
    }
    
    private func subscribeToNotifications() {
        memory.observeHistoryChange { [weak self] in
            Task { [weak self] in
                guard let memory = self?.memory else { return }
                self?.chatHistory = await memory.history
            }
        }
        
        conversationProgressHandler.onBegin.sink { [weak self] (token, progress) in
            self?.handleProgressBegin(token: token, progress: progress)
        }.store(in: &cancellables)
        
        conversationProgressHandler.onProgress.sink { [weak self] (token, progress) in
            self?.handleProgressReport(token: token, progress: progress)
        }.store(in: &cancellables)
        
        conversationProgressHandler.onEnd.sink { [weak self] (token, progress) in
            self?.handleProgressEnd(token: token, progress: progress)
        }.store(in: &cancellables)
    }
    
    private func subscribeToConversationContextRequest() {
        self.conversationContextHandler.onConversationContext.sink(receiveValue: { [weak self] (request, completion) in
            guard let skills = self?.skillSet, !skills.isEmpty, request.params!.conversationId == self?.conversationId else { return }
            skills.forEach { skill in
                if (skill.applies(params: request.params!)) {
                    skill.resolveSkill(request: request, completion: completion)
                }
            }
        }).store(in: &cancellables)
    }

    private func subscribeToClientToolConfirmationEvent() {
        ClientToolHandlerImpl.shared.onClientToolConfirmationEvent.sink(receiveValue: { [weak self] (request, completion) in
            guard let params = request.params, params.conversationId == self?.conversationId else { return }
            let editAgentRounds: [AgentRound] = [
                AgentRound(roundId: params.roundId,
                           reply: "",
                           toolCalls: [
                            AgentToolCall(id: params.toolCallId, name: params.name, status: .waitForConfirmation, invokeParams: params)
                           ]
                          )
            ]
            self?.appendToolCallHistory(turnId: params.turnId, editAgentRounds: editAgentRounds)
            self?.pendingToolCallRequests[params.toolCallId] = ToolCallRequest(
                requestId: request.id,
                turnId: params.turnId,
                roundId: params.roundId,
                toolCallId: params.toolCallId,
                completion: completion)
        }).store(in: &cancellables)
    }

    private func subscribeToClientToolInvokeEvent() {
        ClientToolHandlerImpl.shared.onClientToolInvokeEvent.sink(receiveValue: { [weak self] (request, completion) in
            guard let params = request.params, params.conversationId == self?.conversationId else { return }
            guard let copilotTool = CopilotToolRegistry.shared.getTool(name: params.name) else {
                completion(AnyJSONRPCResponse(id: request.id,
                                              result: JSONValue.array([
                                                  JSONValue.null,
                                                  JSONValue.hash(
                                                    [
                                                        "code": .number(-32601),
                                                        "message": .string("Tool function not found")
                                                    ])
                                              ])
                                             )
                )
                return
            }

            copilotTool.invokeTool(request, completion: completion, chatHistoryUpdater: self?.appendToolCallHistory, contextProvider: self)
        }).store(in: &cancellables)
    }

    private func appendToolCallHistory(turnId: String, editAgentRounds: [AgentRound]) {
        let chatTabId = self.chatTabInfo.id
        Task {
            let message = ChatMessage(
                assistantMessageWithId: turnId,
                chatTabID: chatTabId,
                editAgentRounds: editAgentRounds
            )

            await self.memory.appendMessage(message)
        }
    }
    
    public func updateFileEdits(by fileEdit: FileEdit) {
        if let existingFileEdit = self.fileEditMap[fileEdit.fileURL] {
            self.fileEditMap[fileEdit.fileURL] = .init(
                fileURL: fileEdit.fileURL,
                originalContent: existingFileEdit.originalContent,
                modifiedContent: fileEdit.modifiedContent,
                toolName: existingFileEdit.toolName
            )
        } else {
            self.fileEditMap[fileEdit.fileURL] = fileEdit
        }
    }

    public func notifyChangeTextDocument(fileURL: URL, content: String, version: Int) async throws {
        try await conversationProvider?.notifyChangeTextDocument(fileURL: fileURL, content: content, version: version, workspaceURL: getWorkspaceURL())
    }

    public static func service(for chatTabInfo: ChatTabInfo) -> ChatService {
        let provider = BuiltinExtensionConversationServiceProvider(
            extension: GitHubCopilotExtension.self
        )
        return ChatService(provider: provider, chatTabInfo: chatTabInfo)
    }
    
    // this will be triggerred in conversation tab if needed
    public func restoreIfNeeded() {
        guard self.isRestored == false else { return }
        
        Task {
            let storedChatMessages = fetchAllChatMessagesFromStorage()
            await mutateHistory { history in
                history.append(contentsOf: storedChatMessages)
            }
        }
        
        self.isRestored = true
    }

    public func updateToolCallStatus(toolCallId: String, status: AgentToolCall.ToolCallStatus, payload: Any? = nil) {
        if status == .cancelled {
            resetOngoingRequest()
            return
        }

        // Send the tool call result back to the server
        if let toolCallRequest = self.pendingToolCallRequests[toolCallId], status == .accepted {
            self.pendingToolCallRequests.removeValue(forKey: toolCallId)
            let toolResult = LanguageModelToolConfirmationResult(result: .Accept)
            let jsonResult = try? JSONEncoder().encode(toolResult)
            let jsonValue = (try? JSONDecoder().decode(JSONValue.self, from: jsonResult ?? Data())) ?? JSONValue.null
            toolCallRequest.completion(
                AnyJSONRPCResponse(
                    id: toolCallRequest.requestId,
                    result: JSONValue.array([
                        jsonValue,
                        JSONValue.null
                    ])
                )
            )
        }

        // Update the tool call status in the chat history
        Task {
            guard let lastMessage = await memory.history.last, lastMessage.role == .assistant else {
                return
            }

            var updatedAgentRounds: [AgentRound] = []
            for i in 0..<lastMessage.editAgentRounds.count {
                if lastMessage.editAgentRounds[i].toolCalls == nil {
                    continue
                }
                for j in 0..<lastMessage.editAgentRounds[i].toolCalls!.count {
                    if lastMessage.editAgentRounds[i].toolCalls![j].id == toolCallId {
                        updatedAgentRounds.append(
                            AgentRound(roundId: lastMessage.editAgentRounds[i].roundId,
                                       reply: "",
                                       toolCalls: [
                                        AgentToolCall(id: toolCallId,
                                                      name: lastMessage.editAgentRounds[i].toolCalls![j].name,
                                                      status: status)
                                       ]
                                      )
                        )
                        break
                    }
                }
                if !updatedAgentRounds.isEmpty {
                    break
                }
            }

            if !updatedAgentRounds.isEmpty {
                let message = ChatMessage(
                    id: lastMessage.id,
                    chatTabID: lastMessage.chatTabID,
                    clsTurnID: lastMessage.clsTurnID,
                    role: .assistant,
                    content: "",
                    references: [],
                    steps: [],
                    editAgentRounds: updatedAgentRounds
                )

                await self.memory.appendMessage(message)
            }
        }
    }
    
    public enum ChatServiceError: Error, LocalizedError {
        case conflictingImageFormats(String)
        
        public var errorDescription: String? {
            switch self {
            case .conflictingImageFormats(let message):
                return message
            }
        }
    }

    public func send(
        _ id: String,
        content: String,
        contentImages: Array<ChatCompletionContentPartImage> = [],
        contentImageReferences: Array<ImageReference> = [],
        skillSet: Array<ConversationSkill>,
        references: [ConversationAttachedReference],
        model: String? = nil,
        modelProviderName: String? = nil,
        agentMode: Bool = false,
        userLanguage: String? = nil,
        turnId: String? = nil
    ) async throws {
        guard activeRequestId == nil else { return }
        let workDoneToken = UUID().uuidString
        activeRequestId = workDoneToken
        
        let finalImageReferences: [ImageReference]
        let finalContentImages: [ChatCompletionContentPartImage]
        
        if !contentImageReferences.isEmpty {
            // User attached images are all parsed as ImageReference
            finalImageReferences = contentImageReferences
            finalContentImages = contentImageReferences
                .map {
                    ChatCompletionContentPartImage(
                        url: $0.dataURL(imageType: $0.source == .screenshot ? "png" : "")
                    )
                }
        } else {
            // In current implementation, only resend message will have contentImageReferences
            // No need to convert ChatCompletionContentPartImage to ImageReference for persistence
            finalImageReferences = []
            finalContentImages = contentImages
        }
        
        var chatMessage = ChatMessage(
            userMessageWithId: id,
            chatTabId: chatTabInfo.id,
            content: content,
            contentImageReferences: finalImageReferences,
            references: references.toConversationReferences()
        )
        
        let currentEditorSkill = skillSet.first(where: { $0.id == CurrentEditorSkill.ID }) as? CurrentEditorSkill
        let currentFileReadability = currentEditorSkill == nil
            ? nil
            : FileUtils.checkFileReadability(at: currentEditorSkill!.currentFilePath)
        var errorMessage: ChatMessage?
        
        var currentTurnId: String? = turnId
        // If turnId is provided, it is used to update the existing message, no need to append the user message
        if turnId == nil {
            if let currentFileReadability, !currentFileReadability.isReadable {
                // For associating error message with user message
                currentTurnId = UUID().uuidString
                chatMessage.clsTurnID = currentTurnId
                errorMessage = ChatMessage(
                    errorMessageWithId: currentTurnId!,
                    chatTabID: chatTabInfo.id,
                    errorMessages: [
                        currentFileReadability.errorMessage(
                            using: CurrentEditorSkill.readabilityErrorMessageProvider
                        )
                    ].compactMap { $0 }.filter { !$0.isEmpty }
                )
            }
            await memory.appendMessage(chatMessage)
        }
        
        // reset file edits
        self.resetFileEdits()
        
        // persist
        saveChatMessageToStorage(chatMessage)
        
        if content.hasPrefix("/releaseNotes") {
            if let fileURL = Bundle.main.url(forResource: "ReleaseNotes", withExtension: "md"),
                let whatsNewContent = try? String(contentsOf: fileURL)
            {
                // will be persist in resetOngoingRequest()
                // there is no turn id from CLS, just set it as id
                let clsTurnID = UUID().uuidString
                let progressMessage = ChatMessage(
                    assistantMessageWithId: clsTurnID,
                    chatTabID: chatTabInfo.id,
                    content: whatsNewContent
                )
                await memory.appendMessage(progressMessage)
            }
            resetOngoingRequest()
            return
        }
        
        if let errorMessage {
            Task { await memory.appendMessage(errorMessage) }
        }
        
        var activeDoc: Doc?
        var validSkillSet: [ConversationSkill] = skillSet
        if let currentEditorSkill, currentFileReadability?.isReadable == true {
            activeDoc = Doc(uri: currentEditorSkill.currentFile.url.absoluteString)
        } else {
            validSkillSet.removeAll(where: { $0.id == CurrentEditorSkill.ID || $0.id == ProblemsInActiveDocumentSkill.ID })
        }
        
        let request = createConversationRequest(
            workDoneToken: workDoneToken,
            content: content,
            contentImages: finalContentImages,
            activeDoc: activeDoc,
            references: references,
            model: model,
            modelProviderName: modelProviderName,
            agentMode: agentMode,
            userLanguage: userLanguage,
            turnId: currentTurnId,
            skillSet: validSkillSet
        )
        
        self.lastUserRequest = request
        self.skillSet = validSkillSet
        try await sendConversationRequest(request)
    }
    
    private func createConversationRequest(
        workDoneToken: String, 
        content: String,
        contentImages: [ChatCompletionContentPartImage] = [],
        activeDoc: Doc?,
        references: [ConversationAttachedReference],
        model: String? = nil,
        modelProviderName: String? = nil,
        agentMode: Bool = false,
        userLanguage: String? = nil,
        turnId: String? = nil,
        skillSet: [ConversationSkill]
    ) -> ConversationRequest {
        let skillCapabilities: [String] = [CurrentEditorSkill.ID, ProblemsInActiveDocumentSkill.ID]
        let supportedSkills: [String] = skillSet.map { $0.id }
        let ignoredSkills: [String] = skillCapabilities.filter {
            !supportedSkills.contains($0)
        }
        
        /// replace the `@workspace` to `@project`
        let newContent = replaceFirstWord(in: content, from: "@workspace", to: "@project")
        
        return ConversationRequest(
            workDoneToken: workDoneToken,
            content: newContent,
            contentImages: contentImages,
            workspaceFolder: "",
            activeDoc: activeDoc,
            skills: skillCapabilities,
            ignoredSkills: ignoredSkills,
            references: references,
            model: model,
            modelProviderName: modelProviderName,
            agentMode: agentMode,
            userLanguage: userLanguage,
            turnId: turnId
        )
    }

    public func sendAndWait(_ id: String, content: String) async throws -> String {
        try await send(id, content: content, skillSet: [], references: [])
        if let reply = await memory.history.last(where: { $0.role == .assistant })?.content {
            return reply
        }
        return ""
    }

    public func stopReceivingMessage() async {
        if let activeRequestId = activeRequestId {
            do {
                try await conversationProvider?.stopReceivingMessage(activeRequestId, workspaceURL: getWorkspaceURL())
            } catch {
                print("Failed to cancel ongoing request with WDT: \(activeRequestId)")
            }
        }
        resetOngoingRequest()
    }

    public func clearHistory() async {
        let messageIds = await memory.history.map { $0.id }
        
        await memory.clearHistory()
        if let activeRequestId = activeRequestId {
            do {
                try await conversationProvider?.stopReceivingMessage(activeRequestId, workspaceURL: getWorkspaceURL())
            } catch {
                print("Failed to cancel ongoing request with WDT: \(activeRequestId)")
            }
        }
        
        deleteAllChatMessagesFromStorage(messageIds)
        resetOngoingRequest()
    }

    public func deleteMessage(id: String) async {
        await memory.removeMessage(id)
        deleteChatMessageFromStorage(id)
    }

    public func resendMessage(id: String, model: String? = nil, modelProviderName: String? = nil) async throws {
        if let _ = (await memory.history).first(where: { $0.id == id }),
           let lastUserRequest
        {
            // TODO: clean up contents for resend message
            activeRequestId = nil
            try await send(
                id,
                content: lastUserRequest.content,
                contentImages: lastUserRequest.contentImages,
                skillSet: skillSet,
                references: lastUserRequest.references ?? [],
                model: model != nil ? model : lastUserRequest.model,
                modelProviderName: modelProviderName,
                agentMode: lastUserRequest.agentMode,
                userLanguage: lastUserRequest.userLanguage,
                turnId: id
            )
        }
    }

    public func setMessageAsExtraPrompt(id: String) async {
        if let message = (await memory.history).first(where: { $0.id == id })
        {
            await mutateHistory { history in
                let chatMessage: ChatMessage = .init(
                    chatTabID: self.chatTabInfo.id,
                    role: .assistant,
                    content: message.content
                )
                
                history.append(chatMessage)
                self.saveChatMessageToStorage(chatMessage)
            }
        }
    }

    public func mutateHistory(_ mutator: @escaping (inout [ChatMessage]) -> Void) async {
        await memory.mutateHistory(mutator)
    }

    public func handleCustomCommand(_ command: CustomCommand) async throws {
        struct CustomCommandInfo {
            var specifiedSystemPrompt: String?
            var extraSystemPrompt: String?
            var sendingMessageImmediately: String?
            var name: String?
        }

        let info: CustomCommandInfo? = {
            switch command.feature {
            case let .chatWithSelection(extraSystemPrompt, prompt, useExtraSystemPrompt):
                let updatePrompt = useExtraSystemPrompt ?? true
                return .init(
                    extraSystemPrompt: updatePrompt ? extraSystemPrompt : nil,
                    sendingMessageImmediately: prompt,
                    name: command.name
                )
            case let .customChat(systemPrompt, prompt):
                return .init(
                    specifiedSystemPrompt: systemPrompt,
                    extraSystemPrompt: "",
                    sendingMessageImmediately: prompt,
                    name: command.name
                )
            case .promptToCode: return nil
            case .singleRoundDialog: return nil
            }
        }()

        guard let info else { return }

        let templateProcessor = CustomCommandTemplateProcessor()

        if info.specifiedSystemPrompt != nil || info.extraSystemPrompt != nil {
            await mutateHistory { history in
                let chatMessage: ChatMessage = .init(
                    chatTabID: self.chatTabInfo.id,
                    role: .assistant,
                    content: ""
                )
                history.append(chatMessage)
                self.saveChatMessageToStorage(chatMessage)
            }
        }

        if let sendingMessageImmediately = info.sendingMessageImmediately,
           !sendingMessageImmediately.isEmpty
        {
            try await send(UUID().uuidString, content: templateProcessor.process(sendingMessageImmediately), skillSet: [], references: [])
        }
    }

    public func getWorkspaceURL() -> URL? {
        guard !chatTabInfo.workspacePath.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: chatTabInfo.workspacePath)
    }
    
    public func getProjectRootURL() -> URL? {
        guard let workspaceURL = getWorkspaceURL() else { return nil }
        return WorkspaceXcodeWindowInspector.extractProjectURL(
            workspaceURL: workspaceURL, 
            documentURL: nil
        )
    }
    
    public func upvote(_ id: String, _ rating: ConversationRating) async {
        try? await conversationProvider?.rateConversation(turnId: id, rating: rating, workspaceURL: getWorkspaceURL())
    }
    
    public func downvote(_ id: String, _ rating: ConversationRating) async {
        try? await conversationProvider?.rateConversation(turnId: id, rating: rating, workspaceURL: getWorkspaceURL())
    }
    
    public func copyCode(_ id: String) async {
        // TODO: pass copy code info to Copilot server
    }

    // not used
    public func handleSingleRoundDialogCommand(
        systemPrompt: String?,
        overwriteSystemPrompt: Bool,
        prompt: String
    ) async throws -> String {
        let templateProcessor = CustomCommandTemplateProcessor()
        return try await sendAndWait(UUID().uuidString, content: templateProcessor.process(prompt))
    }
    
    private func handleProgressBegin(token: String, progress: ConversationProgressBegin) {
        guard let workDoneToken = activeRequestId, workDoneToken == token else { return }
        conversationId = progress.conversationId
        let turnId = progress.turnId
        
        Task {
            if var lastUserMessage = await memory.history.last(where: { $0.role == .user }) {
                
                // Case: New conversation where error message was generated before CLS request
                // Using clsTurnId to associate this error message with the corresponding user message
                // When merging error messages with bot responses from CLS, these properties need to be updated
                await memory.mutateHistory { history in 
                    if let existingBotIndex = history.lastIndex(where: {
                        $0.role == .assistant && $0.clsTurnID == lastUserMessage.clsTurnID
                    }) {
                        history[existingBotIndex].id = turnId
                        history[existingBotIndex].clsTurnID = turnId
                    }
                }
                
                lastUserMessage.clsTurnID = progress.turnId
                saveChatMessageToStorage(lastUserMessage)
            }
            
            /// Display an initial assistant message immediately after the user sends a message.
            /// This improves perceived responsiveness, especially in Agent Mode where the first
            /// ProgressReport may take long time.
            let message = ChatMessage(assistantMessageWithId: turnId, chatTabID: chatTabInfo.id)

            // will persist in resetOngoingRequest()
            await memory.appendMessage(message)
        }
    }

    private func handleProgressReport(token: String, progress: ConversationProgressReport) {
        guard let workDownToken = activeRequestId, workDownToken == token else {
            return
        }
        
        let id = progress.turnId
        var content = ""
        var references: [ConversationReference] = []
        var steps: [ConversationProgressStep] = []
        var editAgentRounds: [AgentRound] = []

        if let reply = progress.reply {
            content = reply
        }
        
        if let progressReferences = progress.references, !progressReferences.isEmpty {
            references = progressReferences.toConversationReferences()
        }
        
        if let progressSteps = progress.steps, !progressSteps.isEmpty {
            steps = progressSteps
        }
        
        if let progressAgentRounds = progress.editAgentRounds, !progressAgentRounds.isEmpty {
            editAgentRounds = progressAgentRounds
        }
        
        if content.isEmpty && references.isEmpty && steps.isEmpty && editAgentRounds.isEmpty {
            return
        }
        
        // create immutable copies
        let messageContent = content
        let messageReferences = references
        let messageSteps = steps
        let messageAgentRounds = editAgentRounds

        Task {
            let message = ChatMessage(
                assistantMessageWithId: id,
                chatTabID: chatTabInfo.id,
                content: messageContent,
                references: messageReferences,
                steps: messageSteps,
                editAgentRounds: messageAgentRounds
            )

            // will persist in resetOngoingRequest()
            await memory.appendMessage(message)
        }
    }

    private func handleProgressEnd(token: String, progress: ConversationProgressEnd) {
        guard let workDoneToken = activeRequestId, workDoneToken == token else { return }
        let followUp = progress.followUp
        
        if let CLSError = progress.error {
            // CLS Error Code 402: reached monthly chat messages limit
            if CLSError.code == 402 {
                Task {
                    await Status.shared
                        .updateCLSStatus(.warning, busy: false, message: CLSError.message)
                    let errorMessage = ChatMessage(
                        errorMessageWithId: progress.turnId,
                        chatTabID: chatTabInfo.id,
                        panelMessages: [.init(type: .error, title: String(CLSError.code ?? 0), message: CLSError.message, location: .Panel)]
                    )
                    // will persist in resetongoingRequest()
                    await memory.appendMessage(errorMessage)
                    
                    if let lastUserRequest,
                       let currentUserPlan = await Status.shared.currentUserPlan(),
                       currentUserPlan != "free" {
                        guard let fallbackModel = CopilotModelManager.getFallbackLLM(
                            scope: lastUserRequest.agentMode ? .agentPanel : .chatPanel
                        ) else {
                            resetOngoingRequest()
                            return
                        }
                        do {
                            CopilotModelManager.switchToFallbackModel()
                            try await resendMessage(
                                id: progress.turnId,
                                model: fallbackModel.id,
                                modelProviderName: nil
                            )
                        } catch {
                            Logger.gitHubCopilot.error(error)
                            resetOngoingRequest()
                        }
                        return
                    }
                }
            } else if CLSError.code == 400 && CLSError.message.contains("model is not supported") {
                Task {
                    let errorMessage = ChatMessage(
                        errorMessageWithId: progress.turnId,
                        chatTabID: chatTabInfo.id,
                        errorMessages: ["Oops, the model is not supported. Please enable it first in [GitHub Copilot settings](https://github.com/settings/copilot)."]
                    )
                    await memory.appendMessage(errorMessage)
                    resetOngoingRequest()
                    return
                }
            } else {
                Task {
                    let errorMessage = ChatMessage(
                        errorMessageWithId: progress.turnId,
                        chatTabID: chatTabInfo.id,
                        errorMessages: [CLSError.message]
                    )
                    // will persist in resetOngoingRequest()
                    await memory.appendMessage(errorMessage)
                    resetOngoingRequest()
                    return
                }
            }
        }
        
        Task {
            let message = ChatMessage(
                assistantMessageWithId: progress.turnId, 
                chatTabID: chatTabInfo.id,
                followUp: followUp,
                suggestedTitle: progress.suggestedTitle
            )
            // will persist in resetOngoingRequest()
            await memory.appendMessage(message)
            resetOngoingRequest()
        }
    }
    
    private func resetOngoingRequest() {
        activeRequestId = nil
        isReceivingMessage = false
        requestType = nil

        // cancel all pending tool call requests
        for (_, request) in pendingToolCallRequests {
            pendingToolCallRequests.removeValue(forKey: request.toolCallId)
            let toolResult = LanguageModelToolConfirmationResult(result: .Dismiss)
            let jsonResult = try? JSONEncoder().encode(toolResult)
            let jsonValue = (try? JSONDecoder().decode(JSONValue.self, from: jsonResult ?? Data())) ?? JSONValue.null
            request.completion(
                AnyJSONRPCResponse(
                    id: request.requestId,
                    result: JSONValue.array([
                        jsonValue,
                        JSONValue.null
                    ])
                )
            )
        }
        
        Task {
            // mark running steps to cancelled
            await mutateHistory({ history in
                guard !history.isEmpty,
                      let lastIndex = history.indices.last,
                      history[lastIndex].role == .assistant else { return }
                
                for i in 0..<history[lastIndex].steps.count {
                    if history[lastIndex].steps[i].status == .running {
                        history[lastIndex].steps[i].status = .cancelled
                    }
                }
                
                for i in 0..<history[lastIndex].editAgentRounds.count {
                    if history[lastIndex].editAgentRounds[i].toolCalls == nil {
                        continue
                    }

                    for j in 0..<history[lastIndex].editAgentRounds[i].toolCalls!.count {
                        if history[lastIndex].editAgentRounds[i].toolCalls![j].status == .running
                            || history[lastIndex].editAgentRounds[i].toolCalls![j].status == .waitForConfirmation {
                            history[lastIndex].editAgentRounds[i].toolCalls![j].status = .cancelled
                        }
                    }
                }
                
                if history[lastIndex].codeReviewRound != nil,
                   (
                    history[lastIndex].codeReviewRound!.status == .waitForConfirmation
                    || history[lastIndex].codeReviewRound!.status == .running
                   )
                {
                    history[lastIndex].codeReviewRound!.status = .cancelled
                }
            })

            // The message of progress report could change rapidly
            // Directly upsert the last chat message of history here
            // Possible repeat upsert, but no harm.
            if let message = await memory.history.last {
                saveChatMessageToStorage(message)
            }
        }
    }
    
    private func sendConversationRequest(_ request: ConversationRequest) async throws {
        guard !isReceivingMessage else { throw CancellationError() }
        isReceivingMessage = true
        requestType = .conversation
        
        do {
            if let conversationId = conversationId {
                try await conversationProvider?
                    .createTurn(
                        with: conversationId,
                        request: request,
                        workspaceURL: getWorkspaceURL()
                    )
            } else {
                var requestWithTurns = request
                
                var chatHistory = self.chatHistory
                // remove the last user message
                let _ = chatHistory.popLast()
                if chatHistory.count > 0 {
                    // invoke history turns
                    let turns = chatHistory.toTurns()
                    requestWithTurns.turns = turns
                }
                
                try await conversationProvider?.createConversation(requestWithTurns, workspaceURL: getWorkspaceURL())
            }
        } catch {
            resetOngoingRequest()
            throw error
        }
    }
    
    // MARK: - File Edit
    public func undoFileEdit(for fileURL: URL) throws {
        guard let fileEdit = self.fileEditMap[fileURL],
              fileEdit.status == .none
        else { return }
        
        switch fileEdit.toolName {
        case .insertEditIntoFile:
            InsertEditIntoFileTool.applyEdit(for: fileURL, content: fileEdit.originalContent, contextProvider: self)
        case .createFile:
            try CreateFileTool.undo(for: fileURL)
        default:
            return
        }
        
        self.fileEditMap[fileURL]!.status = .undone
    }
    
    public func keepFileEdit(for fileURL: URL) {
        guard let fileEdit = self.fileEditMap[fileURL], fileEdit.status == .none
        else { return }
        self.fileEditMap[fileURL]!.status = .kept
    }
    
    public func resetFileEdits() {
        self.fileEditMap = [:]
    }
    
    public func discardFileEdit(for fileURL: URL) throws {
        try self.undoFileEdit(for: fileURL)
        self.fileEditMap.removeValue(forKey: fileURL)
    }
}


public final class SharedChatService {
    public var chatTemplates: [ChatTemplate]? = nil
    public var chatAgents: [ChatAgent]? = nil
    private let conversationProvider: ConversationServiceProvider?
    
    public static let shared = SharedChatService.service()
    
    init(provider: any ConversationServiceProvider) {
        self.conversationProvider = provider
    }
    
    public static func service() -> SharedChatService {
        let provider = BuiltinExtensionConversationServiceProvider(
            extension: GitHubCopilotExtension.self
        )
        return SharedChatService(provider: provider)
    }
    
    public func loadChatTemplates() async -> [ChatTemplate]? {
        do {
            if let templates = (try await conversationProvider?.templates()) {
                self.chatTemplates = templates
                return templates
            }
        } catch {
            // handle error if desired
        }

        return nil
    }
    
    public func copilotModels() async -> [CopilotModel] {
        guard let models = try? await conversationProvider?.models() else { return [] }
        return models
    }
    
    public func loadChatAgents() async -> [ChatAgent]? {
        guard self.chatAgents == nil else { return self.chatAgents }
        
        do {
            if let chatAgents = (try await conversationProvider?.agents()) {
                self.chatAgents = chatAgents
                return chatAgents
            }
        } catch {
            // handle error if desired
        }

        return nil
    }
}


extension ChatService {
    
    // do storage operatoin in the background
    private func runInBackground(_ operation: @escaping () -> Void) {
        Task.detached(priority: .utility) {
            operation()
        }
    }
    
    func saveChatMessageToStorage(_ message: ChatMessage) {
        runInBackground {
            ChatMessageStore.save(message, with: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
        }
    }
    
    func deleteChatMessageFromStorage(_ id: String) {
        runInBackground {
                ChatMessageStore.delete(by: id, with: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
        }
    }
    func deleteAllChatMessagesFromStorage(_ ids: [String]) {
        runInBackground {
            ChatMessageStore.deleteAll(by: ids, with: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
        }
    }
    
    func fetchAllChatMessagesFromStorage() -> [ChatMessage] {
        return ChatMessageStore.getAll(by: self.chatTabInfo.id, metadata: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
    }
}

func replaceFirstWord(in content: String, from oldWord: String, to newWord: String) -> String {
    let pattern = "^\(oldWord)\\b"
    
    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
        let range = NSRange(location: 0, length: content.utf16.count)
        return regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: newWord)
    }
    
    return content
}

extension Array where Element == FileReference {
    func toConversationReferences() -> [ConversationReference] {
        return self.map {
            .init(uri: $0.uri, status: .included, kind: .reference($0), referenceType: .file)
        }
    }
}

extension Array where Element == ConversationAttachedReference {
    func toConversationReferences() -> [ConversationReference] {
        return self.map {
            switch $0 {
            case .file(let fileRef): 
                    .init(
                        uri: fileRef.url.path,
                        status: .included,
                        kind: .fileReference($0),
                        referenceType: .file)
            case .directory(let directoryRef): 
                    .init(
                        uri: directoryRef.url.path,
                        status: .included,
                        kind: .fileReference($0),
                        referenceType: .directory)
            }
        }
    }
}

extension [ChatMessage] {
    // transfer chat messages to turns
    // used to restore chat history for CLS
    func toTurns() -> [TurnSchema] {
        var turns: [TurnSchema] = []
        let count = self.count
        var index = 0
        
        while index < count {
            let message = self[index]
            if case .user = message.role {
                var turn = TurnSchema(request: message.content, turnId: message.clsTurnID)
                // has next message
                if index + 1 < count {
                    let nextMessage = self[index + 1]
                    if nextMessage.role == .assistant {
                        turn.response = nextMessage.content + extractContentFromEditAgentRounds(nextMessage.editAgentRounds)
                        index += 1
                    }
                }
                turns.append(turn)
            }
            index += 1
        }
        
        return turns
    }
    
    private func extractContentFromEditAgentRounds(_ editAgentRounds: [AgentRound]) -> String {
        var content = ""
        for round in editAgentRounds {
            if !round.reply.isEmpty {
                content += round.reply
            }
        }
        return content
    }
}

// MARK: Copilot Code Review

extension ChatService {
    
    public func requestCodeReview(_ group: GitDiffGroup) async throws {
        guard activeRequestId == nil else { return }
        activeRequestId = UUID().uuidString
        
        guard !isReceivingMessage else {
            activeRequestId = nil
            throw CancellationError() 
        }
        isReceivingMessage = true
        requestType = .codeReview
        
        do {
            await CodeReviewService.shared.resetComments()
            
            let turnId = UUID().uuidString
            
            await addCodeReviewUserMessage(id: UUID().uuidString, turnId: turnId, group: group)
            
            let initialBotMessage = ChatMessage(
                assistantMessageWithId: turnId, 
                chatTabID: chatTabInfo.id
            )
            await memory.appendMessage(initialBotMessage)
            
            guard let projectRootURL = getProjectRootURL()
            else {
                let round = CodeReviewRound.fromError(turnId: turnId, error: "Invalid git repository.")
                await appendCodeReviewRound(round)
                resetOngoingRequest()
                return
            }
            
            let prChanges = await CurrentChangeService.getPRChanges(
                projectRootURL, 
                group: group,
                shouldIncludeFile: shouldIncludeFileForReview
            )
            guard !prChanges.isEmpty else {
                let round = CodeReviewRound.fromError(
                    turnId: turnId, 
                    error: group == .index ? "No staged changes found to review." : "No unstaged changes found to review."
                )
                await appendCodeReviewRound(round)
                resetOngoingRequest()
                return
            }
                        
            let round: CodeReviewRound = .init(
                turnId: turnId,
                status: .waitForConfirmation,
                request: .from(prChanges)
            )
            await appendCodeReviewRound(round)
        } catch {
            resetOngoingRequest()
            throw error
        }
    }
    
    private func shouldIncludeFileForReview(url: URL) -> Bool {
        let codeLanguage = CodeLanguage(fileURL: url)
        
        if case .builtIn = codeLanguage {
            return true
        } else {
            return false
        }
    }

    private func appendCodeReviewRound(_ round: CodeReviewRound) async {
        let message = ChatMessage(
            assistantMessageWithId: round.turnId, chatTabID: chatTabInfo.id, codeReviewRound: round
        )
        
        await memory.appendMessage(message)
    }
    
    private func getCurrentCodeReviewRound(_ id: String) async -> CodeReviewRound? {
        guard let lastBotMessage = await memory.history.last, 
              lastBotMessage.role == .assistant,
              let codeReviewRound = lastBotMessage.codeReviewRound,
              codeReviewRound.id == id
        else {
            return nil
        }
        
        return codeReviewRound
    }
    
    public func acceptCodeReview(_ id: String, selectedFileUris: [DocumentUri]) async {
        guard activeRequestId != nil, isReceivingMessage else { return }
        
        guard var round = await getCurrentCodeReviewRound(id),
              var request = round.request,
              round.status.canTransitionTo(.accepted)
        else { return }
        
        guard selectedFileUris.count > 0 else {
            round = round.withError("No files are selected to review.")
            await appendCodeReviewRound(round)
            resetOngoingRequest()
            return
        }
        
        round.status = .accepted
        request.updateSelectedChanges(by: selectedFileUris)
        round.request = request
        await appendCodeReviewRound(round)
        
        round.status = .running
        await appendCodeReviewRound(round)
        
        let (fileComments, errorMessage) = await CodeReviewProvider.invoke(
            request,
            context: CodeReviewServiceProvider(conversationServiceProvider: conversationProvider)
        )
        
        if let errorMessage = errorMessage {
            round = round.withError(errorMessage)
            await appendCodeReviewRound(round)
            resetOngoingRequest()
            return
        } 
        
        round = round.withResponse(.init(fileComments: fileComments))
        await CodeReviewService.shared.updateComments(fileComments)
        await appendCodeReviewRound(round)
        
        round.status = .completed
        await appendCodeReviewRound(round)
        
        resetOngoingRequest()
    }
    
    public func cancelCodeReview(_ id: String) async {
        guard activeRequestId != nil, isReceivingMessage else { return }
        
        guard var round = await getCurrentCodeReviewRound(id),
              round.status.canTransitionTo(.cancelled)
        else { return }
        
        round.status = .cancelled
        await appendCodeReviewRound(round)
        
        resetOngoingRequest()
    }
    
    private func addCodeReviewUserMessage(id: String, turnId: String, group: GitDiffGroup) async {
        let content = group == .index
            ? "Code review for staged changes."
            : "Code review for unstaged changes."
        let chatMessage = ChatMessage(userMessageWithId: id, chatTabId: chatTabInfo.id, content: content)
        await memory.appendMessage(chatMessage)
        saveChatMessageToStorage(chatMessage)
    }
}

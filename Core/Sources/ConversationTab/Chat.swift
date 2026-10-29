import ChatService
import ComposableArchitecture
import Foundation
import ChatAPIService
import Preferences
import Terminal
import ConversationServiceProvider
import Persist
import GitHubCopilotService
import Logger
import OrderedCollections
import SwiftUI
import GitHelper
import SuggestionBasic

public struct DisplayedChatMessage: Equatable {
    public enum Role: Equatable {
        case user
        case assistant
        case ignored
    }

    public var id: String
    public var role: Role
    public var text: String
    public var imageReferences: [ImageReference] = []
    public var references: [ConversationReference] = []
    public var followUp: ConversationFollowUp? = nil
    public var suggestedTitle: String? = nil
    public var errorMessages: [String] = []
    public var steps: [ConversationProgressStep] = []
    public var editAgentRounds: [AgentRound] = []
    public var panelMessages: [CopilotShowMessageParams] = []
    public var codeReviewRound: CodeReviewRound? = nil

    public init(
        id: String,
        role: Role,
        text: String,
        imageReferences: [ImageReference] = [],
        references: [ConversationReference] = [],
        followUp: ConversationFollowUp? = nil,
        suggestedTitle: String? = nil,
        errorMessages: [String] = [],
        steps: [ConversationProgressStep] = [],
        editAgentRounds: [AgentRound] = [],
        panelMessages: [CopilotShowMessageParams] = [],
        codeReviewRound: CodeReviewRound? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.imageReferences = imageReferences
        self.references = references
        self.followUp = followUp
        self.suggestedTitle = suggestedTitle
        self.errorMessages = errorMessages
        self.steps = steps
        self.editAgentRounds = editAgentRounds
        self.panelMessages = panelMessages
        self.codeReviewRound = codeReviewRound
    }
}

private var isPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

struct ChatContext: Equatable {
    var typedMessage: String
    var attachedReferences: [ConversationAttachedReference]
    var attachedImages: [ImageReference]
    
    init(typedMessage: String, attachedReferences: [ConversationAttachedReference] = [], attachedImages: [ImageReference] = []) {
        self.typedMessage = typedMessage
        self.attachedReferences = attachedReferences
        self.attachedImages = attachedImages
    }
    
    static func from(_ message: DisplayedChatMessage, projectURL: URL) -> ChatContext {
        .init(
            typedMessage: message.text, 
            attachedReferences: message.references.compactMap {
                guard let url = $0.url else { return nil }
                if $0.isDirectory {
                    return .directory(.init(url: url))
                } else {
                    let relativePath = url.path.replacingOccurrences(of: projectURL.path, with: "")
                    let fileName = url.lastPathComponent
                    return .file(.init(url: url, relativePath: relativePath, fileName: fileName))
                }
            }, 
            attachedImages: message.imageReferences)
    }
}

struct ChatContextProvider: Equatable {
    var contextStack: [ChatContext]
    
    init(contextStack: [ChatContext] = []) {
        self.contextStack = contextStack
    }
    
    mutating func reset() {
        contextStack = []
    }
    
    mutating func getNextContext() -> ChatContext? { 
        guard !contextStack.isEmpty else {
            return nil
        }
        
        return contextStack.removeLast()
    }
    
    func getPreviousContext(from history: [DisplayedChatMessage], projectURL: URL) -> ChatContext? {
        let previousUserMessage: DisplayedChatMessage? = {
            let userMessages = history.filter { $0.role == .user }
            guard !userMessages.isEmpty else {
                return nil
            }
            
            let stackCount = contextStack.count
            guard userMessages.count > stackCount else {
                return nil
            }
            
            let index = userMessages.count - stackCount - 1
            guard index >= 0 else { return nil }
            
            return userMessages[index]
        }()
        
        var context: ChatContext?
        if let previousUserMessage {
            context = .from(previousUserMessage, projectURL: projectURL)
        }
        
        return context
    }
    
    mutating func pushContext(_ context: ChatContext) { 
        contextStack.append(context) 
    }
}

@Reducer
struct Chat {
    public typealias MessageID = String

    @ObservableState
    struct State: Equatable {
        // Not use anymore. the title of history tab will get from chat tab info
        // Keep this var as `ChatTabItemView` reference this
        var title: String = "New Chat"
        var chatContext: ChatContext = .init(typedMessage: "", attachedReferences: [], attachedImages: [])
        var contextProvider: ChatContextProvider = .init()
        var history: [DisplayedChatMessage] = []
        var isReceivingMessage = false
        var requestType: ChatService.RequestType? = nil
        var chatMenu = ChatMenu.State()
        var focusedField: Field?
        var currentEditor: ConversationFileReference? = nil
        var attachedReferences: [ConversationAttachedReference] {
            chatContext.attachedReferences
        }
        var attachedImages: [ImageReference] {
            chatContext.attachedImages
        }
        var typedMessage: String {
            get { chatContext.typedMessage }
            set { 
                chatContext.typedMessage = newValue
                // User typed in. Need to reset contextProvider
                contextProvider.reset()
            }
        }
        /// Cache the original content
        var fileEditMap: OrderedDictionary<URL, FileEdit> = [:]
        var diffViewerController: DiffViewWindowController? = nil
        var isAgentMode: Bool = AppState.shared.isAgentModeEnabled()
        var workspaceURL: URL? = nil
        enum Field: String, Hashable {
            case textField
            case fileSearchBar
        }
        
        var codeReviewState = ConversationCodeReviewFeature.State()
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)

        case appear
        case refresh
        case sendButtonTapped(String)
        case returnButtonTapped
        case stopRespondingButtonTapped
        case clearButtonTap
        case deleteMessageButtonTapped(MessageID)
        case resendMessageButtonTapped(MessageID)
        case setAsExtraPromptButtonTapped(MessageID)
        case focusOnTextField
        case referenceClicked(ConversationReference)
        case upvote(MessageID, ConversationRating)
        case downvote(MessageID, ConversationRating)
        case copyCode(MessageID)
        case insertCode(String)
        case toolCallAccepted(String)
        case toolCallCompleted(String, String)
        case toolCallCancelled(String)

        case observeChatService
        case observeHistoryChange
        case observeIsReceivingMessageChange
        case observeFileEditChange

        case historyChanged
        case isReceivingMessageChanged
        case fileEditChanged

        case chatMenu(ChatMenu.Action)
        
        // File context
        case resetCurrentEditor
        case setCurrentEditor(ConversationFileReference)
        case addReference(ConversationAttachedReference)
        case removeReference(ConversationAttachedReference)
        
        // Image context
        case addSelectedImage(ImageReference)
        case removeSelectedImage(ImageReference)
        
        case followUpButtonClicked(String, String)
        
        // Agent File Edit
        case undoEdits(fileURLs: [URL])
        case keepEdits(fileURLs: [URL])
        case resetEdits
        case discardFileEdits(fileURLs: [URL])
        case openDiffViewWindow(fileURL: URL)
        case setDiffViewerController(chat: StoreOf<Chat>)

        case agentModeChanged(Bool)
        
        // Code Review
        case codeReview(ConversationCodeReviewFeature.Action)
        
        // Chat Context
        case reloadNextContext
        case reloadPreviousContext
        case resetContextProvider

        // External Action
        case observeFixErrorNotification
        case fixEditorErrorIssue(EditorErrorIssue)
    }

    let service: ChatService
    let id = UUID()

    enum CancelID: Hashable {
        case observeHistoryChange(UUID)
        case observeIsReceivingMessageChange(UUID)
        case sendMessage(UUID)
        case observeFileEditChange(UUID)
        case observeFixErrorNotification(UUID)
    }

    @Dependency(\.openURL) var openURL
    @AppStorage(\.enableCurrentEditorContext) var enableCurrentEditorContext: Bool
    @AppStorage(\.chatResponseLocale) var chatResponseLocale

    var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.chatMenu, action: /Action.chatMenu) {
            ChatMenu(service: service)
        }
        
        Scope(state: \.codeReviewState, action: /Action.codeReview) {
            ConversationCodeReviewFeature(service: service)
        }

        Reduce { state, action in
            switch action {
            case .appear:
                return .run { send in
                    if isPreview { return }
                    await send(.observeChatService)
                    await send(.historyChanged)
                    await send(.isReceivingMessageChanged)
                    await send(.focusOnTextField)
                    await send(.refresh)
                    await send(.observeFixErrorNotification)
                    
                    let publisher = NotificationCenter.default.publisher(for: .gitHubCopilotChatModeDidChange)
                    for await _ in publisher.values {
                        let isAgentMode = AppState.shared.isAgentModeEnabled()
                        await send(.agentModeChanged(isAgentMode))
                    }
                }

            case .refresh:
                return .run { send in
                    await send(.chatMenu(.refresh))
                }

            case let .sendButtonTapped(id):
                guard !state.typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none }
                let message = state.typedMessage
                let skillSet = state.buildSkillSet(
                    isCurrentEditorContextEnabled: enableCurrentEditorContext
                )
                state.typedMessage = ""
                
                let selectedModel = AppState.shared.getSelectedModel()
                let selectedModelFamily = selectedModel?.modelFamily ?? CopilotModelManager.getDefaultChatModel(
                    scope: AppState.shared.modelScope()
                )?.modelFamily
                let agentMode = AppState.shared.isAgentModeEnabled()
                let shouldAttachImages = selectedModel?.supportVision ?? CopilotModelManager.getDefaultChatModel(
                    scope: AppState.shared.modelScope()
                )?.supportVision ?? false
                let attachedImages: [ImageReference] = shouldAttachImages ? state.attachedImages : []

                let references = state.attachedReferences
                state.chatContext.attachedImages = []
                
                return .run { send in
                    await send(.resetContextProvider)
                    
                    try await service
                        .send(
                            id,
                            content: message,
                            contentImageReferences: attachedImages,
                            skillSet: skillSet,
                            references: references,
                            model: selectedModelFamily,
                            modelProviderName: selectedModel?.providerName,
                            agentMode: agentMode,
                            userLanguage: chatResponseLocale
                        )
                }.cancellable(id: CancelID.sendMessage(self.id))
            
            case let .toolCallAccepted(toolCallId):
                guard !toolCallId.isEmpty else { return .none }
                return .run { _ in
                    service.updateToolCallStatus(toolCallId: toolCallId, status: .accepted)
                }.cancellable(id: CancelID.sendMessage(self.id))
            case let .toolCallCancelled(toolCallId):
                guard !toolCallId.isEmpty else { return .none }
                return .run { _ in
                    service.updateToolCallStatus(toolCallId: toolCallId, status: .cancelled)
                }.cancellable(id: CancelID.sendMessage(self.id))
            case let .toolCallCompleted(toolCallId, result):
                guard !toolCallId.isEmpty else { return .none }
                return .run { _ in
                    service.updateToolCallStatus(toolCallId: toolCallId, status: .completed, payload: result)
                }.cancellable(id: CancelID.sendMessage(self.id))
                
            case let .followUpButtonClicked(id, message):
                guard !message.isEmpty else { return .none }
                let skillSet = state.buildSkillSet(
                    isCurrentEditorContextEnabled: enableCurrentEditorContext
                )
                
                let selectedModel = AppState.shared.getSelectedModel()
                let selectedModelFamily = selectedModel?.modelFamily ?? CopilotModelManager.getDefaultChatModel(
                    scope: AppState.shared.modelScope()
                )?.modelFamily
                let references = state.attachedReferences
                let agentMode = AppState.shared.isAgentModeEnabled()
                
                return .run { send in
                    await send(.resetContextProvider)

                    try await service
                        .send(
                            id,
                            content: message,
                            skillSet: skillSet,
                            references: references,
                            model: selectedModelFamily,
                            modelProviderName: selectedModel?.providerName,
                            agentMode: agentMode,
                            userLanguage: chatResponseLocale
                        )
                }.cancellable(id: CancelID.sendMessage(self.id))

            case .returnButtonTapped:
                state.typedMessage += "\n"
                return .none

            case .stopRespondingButtonTapped:
                return .merge(
                    .run { _ in
                        await service.stopReceivingMessage()
                    },
                    .cancel(id: CancelID.sendMessage(id))
                )

            case .clearButtonTap:
                return .run { _ in
                    await service.clearHistory()
                }

            case let .deleteMessageButtonTapped(id):
                return .run { _ in
                    await service.deleteMessage(id: id)
                }

            case let .resendMessageButtonTapped(id):
                return .run { _ in
                    try await service.resendMessage(id: id)
                }

            case let .setAsExtraPromptButtonTapped(id):
                return .run { _ in
                    await service.setMessageAsExtraPrompt(id: id)
                }

            case let .referenceClicked(reference):
                guard let fileURL = reference.url else {
                    return .none
                }
                return .run { _ in
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let terminal = Terminal()
                        do {
                            _ = try await terminal.runCommand(
                                "/bin/bash",
                                arguments: [
                                    "-c",
                                    "xed -l 0 \"\(reference.filePath)\"",
                                ],
                                environment: [:]
                            )
                        } catch {
                            print(error)
                        }
                    } else if let url = URL(string: reference.uri), url.scheme != nil {
                        await openURL(url)
                    }
                }

            case .focusOnTextField:
                state.focusedField = .textField
                return .none

            case .observeChatService:
                return .run { send in
                    await send(.observeHistoryChange)
                    await send(.observeIsReceivingMessageChange)
                    await send(.observeFileEditChange)
                }

            case .observeHistoryChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$chatHistory.sink { _ in
                            continuation.yield()
                        }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    let debouncedHistoryChange = TimedDebounceFunction(duration: 0.2) {
                        await send(.historyChanged)
                    }
                    
                    for await _ in stream {
                        await debouncedHistoryChange()
                    }
                }.cancellable(id: CancelID.observeHistoryChange(id), cancelInFlight: true)

            case .observeIsReceivingMessageChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$isReceivingMessage
                            .sink { _ in
                                continuation.yield()
                            }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.isReceivingMessageChanged)
                    }
                }.cancellable(
                    id: CancelID.observeIsReceivingMessageChange(id),
                    cancelInFlight: true
                )
                
            case .observeFileEditChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$fileEditMap
                            .sink { _ in
                                continuation.yield()
                            }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.fileEditChanged)
                    }
                }.cancellable(
                    id: CancelID.observeFileEditChange(id),
                    cancelInFlight: true
                )

            case .historyChanged:
                state.history = service.chatHistory.flatMap { message in
                    var all = [DisplayedChatMessage]()
                    all.append(.init(
                        id: message.id,
                        role: {
                            switch message.role {
                            case .user: return .user
                            case .assistant: return .assistant
                            case .system: return .ignored
                            }
                        }(),
                        text: message.content,
                        imageReferences: message.contentImageReferences,
                        references: message.references.map {
                            .init(
                                uri: $0.uri,
                                status: $0.status,
                                kind: $0.kind,
                                referenceType: $0.referenceType
                            )
                        },
                        followUp: message.followUp,
                        suggestedTitle: message.suggestedTitle,
                        errorMessages: message.errorMessages,
                        steps: message.steps,
                        editAgentRounds: message.editAgentRounds,
                        panelMessages: message.panelMessages,
                        codeReviewRound: message.codeReviewRound
                    ))

                    return all
                }
                
                return .none

            case .isReceivingMessageChanged:
                state.isReceivingMessage = service.isReceivingMessage
                state.requestType = service.requestType
                return .none
                
            case .fileEditChanged:
                state.fileEditMap = service.fileEditMap
                let fileEditMap = state.fileEditMap
                
                let diffViewerController = state.diffViewerController
                
                return .run { _ in
                    /// refresh diff view
                    
                    guard let diffViewerController,
                          diffViewerController.diffViewerState == .shown
                    else { return }
                    
                    if fileEditMap.isEmpty {
                        await diffViewerController.hideWindow()
                        return
                    }
                    
                    guard let currentFileEdit = diffViewerController.currentFileEdit
                    else { return }
                    
                    if let updatedFileEdit = fileEditMap[currentFileEdit.fileURL] {
                        if updatedFileEdit != currentFileEdit {
                            if updatedFileEdit.status == .undone,
                               updatedFileEdit.toolName == .createFile
                            {
                                await diffViewerController.hideWindow()
                            } else {
                                await diffViewerController.showDiffWindow(fileEdit: updatedFileEdit)
                            }
                        }
                    } else {
                        await diffViewerController.hideWindow()
                    }
                }

            case .binding:
                return .none

            case .chatMenu:
                return .none
            case let .upvote(id, rating):
                return .run { _ in
                    await service.upvote(id, rating)
                }
            case let .downvote(id, rating):
                return .run { _ in
                    await service.downvote(id, rating)
                }
            case let .copyCode(id):
                return .run { _ in
                    await service.copyCode(id)
                }
                
            case let .insertCode(code):
                 ChatInjector().insertCodeBlock(codeBlock: code)
                 return .none

            // MARK: - Context
            case .resetCurrentEditor:
                state.currentEditor = nil
                return .none
            case let .setCurrentEditor(fileReference):
                state.currentEditor = fileReference
                return .none
            case let .addReference(ref):
                guard !state.chatContext.attachedReferences.contains(ref) else { 
                    return .none
                }
                state.chatContext.attachedReferences.append(ref)
                return .none
                
            case let .removeReference(ref):
                guard let index = state.chatContext.attachedReferences.firstIndex(of: ref) else {
                    return .none
                }
                state.chatContext.attachedReferences.remove(at: index)
                return .none
                
            // MARK: - Image Context
            case let .addSelectedImage(imageReference):
                guard !state.attachedImages.contains(imageReference) else { return .none }
                state.chatContext.attachedImages.append(imageReference)
                return .run { send in await send(.resetContextProvider) }
            case let .removeSelectedImage(imageReference):
                guard let index = state.attachedImages.firstIndex(of: imageReference) else { return .none }
                state.chatContext.attachedImages.remove(at: index)
                return .run { send in await send(.resetContextProvider) }
                
            // MARK: - Agent Edits
                
            case let .undoEdits(fileURLs):
                for fileURL in fileURLs {
                    do {
                        try service.undoFileEdit(for: fileURL)
                    } catch {
                        Logger.service.error("Failed to undo edit, \(error)")
                    }
                }
                
                return .none
                
            case let .keepEdits(fileURLs):
                for fileURL in fileURLs {
                    service.keepFileEdit(for: fileURL)
                }
                
                return .none
            
            case .resetEdits:
                service.resetFileEdits()
                
                return .none
                
            case let .discardFileEdits(fileURLs):
                for fileURL in fileURLs {
                    try? service.discardFileEdit(for: fileURL)
                }
                return .none
                
            case let .openDiffViewWindow(fileURL):
                guard let fileEdit = state.fileEditMap[fileURL],
                      let diffViewerController = state.diffViewerController
                else { return .none }
                
                return .run { _ in
                    await diffViewerController.showDiffWindow(fileEdit: fileEdit)
                }
                
            case let .setDiffViewerController(chat):
                state.diffViewerController = .init(chat: chat)
                return .none

            case let .agentModeChanged(isAgentMode):
                state.isAgentMode = isAgentMode
                return .none
                
            case .codeReview:
                return .none
                
            // MARK: Chat Context
            case .reloadNextContext:
                guard let context = state.contextProvider.getNextContext() else {
                    return .none
                }
                
                state.chatContext = context
                
                return .run { send in
                    await send(.focusOnTextField)
                }
                
            case .reloadPreviousContext:
                guard let projectURL = service.getProjectRootURL(),
                      let context = state.contextProvider.getPreviousContext(
                        from: state.history,
                        projectURL: projectURL) 
                else {
                    return .none
                }
                
                let currentContext = state.chatContext
                state.chatContext = context
                state.contextProvider.pushContext(currentContext)
                
                return .run { send in
                    await send(.focusOnTextField)
                }
                
            case .resetContextProvider:
                state.contextProvider.reset()
                return .none

            // MARK: - External action
                
            case .observeFixErrorNotification:
                return .run { send in 
                    let publisher = NotificationCenter.default.publisher(for: .fixEditorErrorIssue)
                    
                    for await notification in publisher.values {
                        guard service.chatTabInfo.isSelected,
                              let issue = notification.userInfo?["editorErrorIssue"] as? EditorErrorIssue
                        else {
                            continue
                        }
                        
                        await send(.fixEditorErrorIssue(issue))
                    }
                }.cancellable(
                    id: CancelID.observeFixErrorNotification(id), 
                    cancelInFlight: true)
                
            case .fixEditorErrorIssue(let issue):
                guard issue.workspaceURL == service.getWorkspaceURL(),
                      !issue.lineAnnotations.isEmpty
                else {
                    return .none
                }
                
                guard !state.isReceivingMessage else {
                    return .run { _ in
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .fixEditorErrorIssueError,
                                object: nil,
                                userInfo: ["error": FixEditorErrorIssueFailure.isReceivingMessage(id: issue.id)]
                            )
                        }
                    }
                }
                
                let errorAnnotationMessage: String = issue.lineAnnotations
                    .map { "❗\($0.originalAnnotation)" }
                    .joined(separator: "\n\n")
                let message = "Analyze and fix the following error(s): \n\n\(errorAnnotationMessage)"
                
                let skillSet = state.buildSkillSet(isCurrentEditorContextEnabled: enableCurrentEditorContext)
                let references: [ConversationAttachedReference] = [.file(.init(url: issue.fileURL))]
                let selectedModel = AppState.shared.getSelectedModel()
                let selectedModelFamily = selectedModel?.modelFamily ?? CopilotModelManager.getDefaultChatModel(
                    scope: AppState.shared.modelScope()
                )?.modelFamily
                let agentMode = AppState.shared.isAgentModeEnabled()
                
                return .run { _ in 
                    try await service.send(
                        UUID().uuidString,
                        content: message,
                        skillSet: skillSet,
                        references: references,
                        model: selectedModelFamily,
                        modelProviderName: selectedModel?.providerName,
                        agentMode: agentMode,
                        userLanguage: chatResponseLocale
                    )
                }.cancellable(id: CancelID.sendMessage(self.id))
            }
        }
    }
}

@Reducer
struct ChatMenu {
    @ObservableState
    struct State: Equatable {
        var systemPrompt: String = ""
        var extraSystemPrompt: String = ""
        var temperatureOverride: Double? = nil
        var chatModelIdOverride: String? = nil
    }

    enum Action: Equatable {
        case appear
        case refresh
        case customCommandButtonTapped(CustomCommand)
    }

    let service: ChatService

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appear:
                return .run {
                    await $0(.refresh)
                }

            case .refresh:
                return .none

            case let .customCommandButtonTapped(command):
                return .run { _ in
                    try await service.handleCustomCommand(command)
                }
            }
        }
    }
}

private actor TimedDebounceFunction {
    let duration: TimeInterval
    let block: () async -> Void

    var task: Task<Void, Error>?
    var lastFireTime: Date = .init(timeIntervalSince1970: 0)

    init(duration: TimeInterval, block: @escaping () async -> Void) {
        self.duration = duration
        self.block = block
    }

    func callAsFunction() async {
        task?.cancel()
        if lastFireTime.timeIntervalSinceNow < -duration {
            await fire()
            task = nil
        } else {
            task = Task.detached { [weak self, duration] in
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await self?.fire()
            }
        }
    }
    
    func fire() async {
        lastFireTime = Date()
        await block()
    }
}

public struct EditorErrorIssue: Equatable {
    public let lineAnnotations: [EditorInformation.LineAnnotation]
    public let fileURL: URL
    public let workspaceURL: URL
    public let id: String
    
    public init(
        lineAnnotations: [EditorInformation.LineAnnotation], 
        fileURL: URL, 
        workspaceURL: URL,
        id: String
    ) {
        self.lineAnnotations = lineAnnotations
        self.fileURL = fileURL
        self.workspaceURL = workspaceURL
        self.id = id
    }
}

public enum FixEditorErrorIssueFailure: Equatable {
    case isReceivingMessage(id: String)
}

public extension Notification.Name {
    static let fixEditorErrorIssue = Notification.Name("com.github.CopilotForXcode.fixEditorErrorIssue")
    static let fixEditorErrorIssueError = Notification.Name("com.github.CopilotForXcode.fixEditorErrorIssueError")
}

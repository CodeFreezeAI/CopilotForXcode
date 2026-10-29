import ComposableArchitecture
import ChatService
import Foundation
import MarkdownUI
import SharedUIComponents
import SwiftUI
import ConversationServiceProvider
import ChatTab
import ChatAPIService

struct BotMessage: View {
    var r: Double { messageBubbleCornerRadius }
    let id: String
    let text: String
    let references: [ConversationReference]
    let followUp: ConversationFollowUp?
    let errorMessages: [String]
    let chat: StoreOf<Chat>
    let steps: [ConversationProgressStep]
    let editAgentRounds: [AgentRound]
    let panelMessages: [CopilotShowMessageParams]
    let codeReviewRound: CodeReviewRound?
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(\.chatFontSize) var chatFontSize

    @State var isReferencesPresented = false
    
    struct ResponseToolBar: View {
        let id: String
        let chat: StoreOf<Chat>
        let text: String
        
        var body: some View {
            HStack(spacing: 4) {
                
                UpvoteButton { rating in
                    chat.send(.upvote(id, rating))
                }
                
                DownvoteButton { rating in
                    chat.send(.downvote(id, rating))
                }
                
                CopyButton {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    chat.send(.copyCode(id))
                }
                
                Spacer() // Pushes the buttons to the left
            }
        }
    }
    
    struct ReferenceButton: View {
        var r: Double { messageBubbleCornerRadius }
        let references: [ConversationReference]
        let chat: StoreOf<Chat>
        
        @Binding var isReferencesPresented: Bool
        
        @State var isReferencesHovered = false
        
        @AppStorage(\.chatFontSize) var chatFontSize
        
        func MakeReferenceTitle(references: [ConversationReference]) -> String {
            guard !references.isEmpty else {
                return ""
            }
            
            let count = references.count
            let title = count > 1 ? "Used \(count) references" : "Used \(count) reference"
            return title
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    isReferencesPresented.toggle()
                }, label: {
                    HStack(spacing: 4) {
                        Image(systemName: isReferencesPresented ? "chevron.down" : "chevron.right")
                            .resizable()
                            .scaledToFit()
                            .scaledFrame(width: 14, height: 14)
                            
                        Text(MakeReferenceTitle(references: references))
                            .scaledFont(size: chatFontSize)
                    }
                    .background {
                        RoundedRectangle(cornerRadius: r - 4)
                            .fill(isReferencesHovered ? Color.gray.opacity(0.1) : Color.clear)
                    }
                    .foregroundStyle(.secondary)
                })
                .buttonStyle(HoverButtonStyle())
                .accessibilityValue(isReferencesPresented ? "Collapse" : "Expand")
                
                if isReferencesPresented {
                    ReferenceList(references: references, chat: chat)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.gray, lineWidth: 0.2)
                        )
                }
            }
        }
    }
    
    private var agentWorkingStatus: some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.small)
                .frame(width: 20, height: 16)
                .scaleEffect(0.7)
            
            Text("Working...")
                .scaledFont(size: chatFontSize)
                .foregroundColor(.secondary)
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                CopilotMessageHeader()
                
                if !references.isEmpty {
                    WithPerceptionTracking {
                        ReferenceButton(
                            references: references,
                            chat: chat,
                            isReferencesPresented: $isReferencesPresented
                        )
                    }
                }
                
                // progress step
                if steps.count > 0 {
                    ProgressStep(steps: steps)
                }
                
                if !panelMessages.isEmpty {
                    WithPerceptionTracking {
                        ForEach(panelMessages.indices, id: \.self) { index in
                            FunctionMessage(text: panelMessages[index].message, chat: chat)
                        }
                    }
                }
                
                if editAgentRounds.count > 0 {
                    ProgressAgentRound(rounds: editAgentRounds, chat: chat)
                }

                if !text.isEmpty {
                    ThemedMarkdownText(text: text, chat: chat)
                }
                
                if let codeReviewRound = codeReviewRound {
                    CodeReviewMainView(
                        store: chat, round: codeReviewRound
                    )
                }

                if !errorMessages.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(errorMessages.indices, id: \.self) { index in 
                            if let attributedString = try? AttributedString(markdown: errorMessages[index]) {
                                NotificationBanner(style: .warning) {
                                    Text(attributedString)
                                }
                            }
                        }
                    }
                }
                
                if shouldShowWorkingStatus() {
                    agentWorkingStatus
                }
                
                if shouldShowToolBar() {
                    ResponseToolBar(id: id, chat: chat, text: text)
                }
            }
            .shadow(color: .black.opacity(0.05), radius: 6)
            .contextMenu {
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .scaledFont(.body)
                
                Button("Set as Extra System Prompt") {
                    chat.send(.setAsExtraPromptButtonTapped(id))
                }
                .scaledFont(.body)
                
                Divider()
                
                Button("Delete") {
                    chat.send(.deleteMessageButtonTapped(id))
                }
                .scaledFont(.body)
            }
        }
    }
    
    private func shouldShowWorkingStatus() -> Bool {
        let hasRunningStep: Bool = steps.contains(where: { $0.status == .running })
        let hasRunningRound: Bool = editAgentRounds.contains(where: { round in
            return round.toolCalls?.contains(where: { $0.status == .running }) ?? false
        })
        
        if hasRunningStep || hasRunningRound {
            return false
        }
        
        // Only show working status for the current bot message being received
        return chat.isReceivingMessage && isLatestAssistantMessage()
    }
    
    private func shouldShowToolBar() -> Bool {
        // Always show toolbar for historical messages
        if !isLatestAssistantMessage() { return true }
        
        // For current message, only show toolbar when message is complete
        return !chat.isReceivingMessage
    }
    
    private func isLatestAssistantMessage() -> Bool {
        let lastMessage = chat.history.last
        return lastMessage?.role == .assistant && lastMessage?.id == id
    }
}

struct ReferenceList: View {
    let references: [ConversationReference]
    let chat: StoreOf<Chat>

    private let maxVisibleItems: Int = 6
    @State private var itemHeight: CGFloat = 16
    
    @AppStorage(\.chatFontSize) var chatFontSize
    
    struct ReferenceView: View {
        let references: [ConversationReference]
        let chat: StoreOf<Chat>
        @AppStorage(\.chatFontSize) var chatFontSize
        @Binding var itemHeight: CGFloat
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<references.endIndex, id: \.self) { index in
                    WithPerceptionTracking {
                        let reference = references[index]

                        Button(action: {
                            chat.send(.referenceClicked(reference))
                        }) {
                            HStack(spacing: 8) {
                                drawFileIcon(reference.url, isDirectory: reference.isDirectory)
                                    .resizable()
                                    .scaledToFit()
                                    .scaledFrame(width: 16, height: 16)
                                Text(reference.fileName)
                                    .truncationMode(.middle)
                                    .lineLimit(1)
                                    .layoutPriority(1)
                                    .scaledFont(size: chatFontSize)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(HoverButtonStyle())
                        .background(GeometryReader { geometry in
                            Color.clear.onAppear {
                                itemHeight = geometry.size.height
                            }
                        })
                        .help(reference.getPathRelativeToHome())
                    }
                }
            }
        }
    }

    var body: some View {
        WithPerceptionTracking {
            if references.count <= maxVisibleItems {
                ReferenceView(references: references,  chat: chat, itemHeight: $itemHeight)
            } else {
                HoverScrollView {
                    ReferenceView(references: references,  chat: chat, itemHeight: $itemHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxViewHeight)

    }
    
    private var maxViewHeight: CGFloat {
        let totalHeight = CGFloat(references.count) * itemHeight
        let maxHeight = CGFloat(maxVisibleItems) * itemHeight
        return min(totalHeight, maxHeight)
    }
}

struct BotMessage_Previews: PreviewProvider {
    static let steps: [ConversationProgressStep] = [
        .init(id: "001", title: "running step", description: "this is running step", status: .running, error: nil),
        .init(id: "002", title: "completed step", description: "this is completed step", status: .completed, error: nil),
        .init(id: "003", title: "failed step", description: "this is failed step", status: .failed, error: nil),
        .init(id: "004", title: "cancelled step", description: "this is cancelled step", status: .cancelled, error: nil)
    ]

    static let agentRounds: [AgentRound] = [
        .init(roundId: 1, reply: "this is agent step 1", toolCalls: [
            .init(
                id: "toolcall_001",
                name: "Tool Call 1",
                progressMessage: "Read Tool Call 1",
                status: .completed,
                error: nil)
            ]),
        .init(roundId: 2, reply: "this is agent step 2", toolCalls: [
            .init(
                id: "toolcall_002",
                name: "Tool Call 2",
                progressMessage: "Running Tool Call 2",
                status: .running)
            ])
        ]

    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        BotMessage(
            id: "1",
            text: """
            **Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?
            ```swift
            func foo() {}
            ```
            """,
            references: .init(repeating: .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .class,
                referenceType: .file
            ), count: 2),
            followUp: ConversationFollowUp(message: "followup question", id: "id", type: "type"),
            errorMessages: ["Sorry, an error occurred while generating a response."],
            chat: .init(initialState: .init(), reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }),
            steps: steps,
            editAgentRounds: agentRounds,
            panelMessages: [],
            codeReviewRound: nil
        )
        .padding()
        .fixedSize(horizontal: true, vertical: true)
    }
}

struct ReferenceList_Previews: PreviewProvider {
    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        ReferenceList(references: [
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .class,
                referenceType: .file
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views",
                status: .included,
                kind: .struct,
                referenceType: .file
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .function,
                referenceType: .file
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .case,
                referenceType: .file
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .extension,
                referenceType: .file
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .webpage,
                referenceType: .file
            ),
        ], chat: .init(initialState: .init(), reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }))
    }
}

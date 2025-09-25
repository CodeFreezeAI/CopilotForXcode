import ComposableArchitecture
import ChatService
import Foundation
import MarkdownUI
import SharedUIComponents
import SwiftUI
import Status
import Cache
import ChatTab
import ConversationServiceProvider
import SwiftUIFlowLayout

private let MAX_TEXT_LENGTH = 10000 // Maximum characters to prevent crashes

struct UserMessage: View {
    var r: Double { messageBubbleCornerRadius }
    let id: String
    let text: String
    let imageReferences: [ImageReference]
    let chat: StoreOf<Chat>
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var statusObserver = StatusObserver.shared
    
    struct AvatarView: View {
        @ObservedObject private var avatarViewModel = AvatarViewModel.shared
        
        var body: some View {
            if let avatarImage = avatarViewModel.avatarImage {
                avatarImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaledFrame(width: 24, height: 24)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle")
                    .resizable()
                    .scaledToFit()
                    .scaledFrame(width: 24, height: 24)
            }
        }
    }

    // Truncate the displayed user message if it's too long.
    private var displayText: String {
        if text.count > MAX_TEXT_LENGTH {
            return String(text.prefix(MAX_TEXT_LENGTH)) + "\n… (message too long, rest hidden)"
        }
        return text
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    AvatarView()

                    Text(statusObserver.authStatus.username ?? "")
                        .scaledFont(size: 13, weight: .semibold)
                        .padding(2)
                    
                    Spacer()
                }
                
                ThemedMarkdownText(text: displayText, chat: chat)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if !imageReferences.isEmpty {
                    FlowLayout(mode: .scrollable, items: imageReferences, itemSpacing: 4) { item in
                        ImageReferenceItemView(item: item)
                    }
                }
            }
        }
        .shadow(color: .black.opacity(0.05), radius: 6)
    }
}

struct UserMessage_Previews: PreviewProvider {
    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        UserMessage(
            id: "A",
            text: #"""
            Please buy me a coffee!
            | Coffee | Milk |
            |--------|------|
            | Espresso | No |
            | Latte | Yes |
            ```swift
            func foo() {}
            ```
            ```objectivec
            - (void)bar {}
            ```
            """#,
            imageReferences: [],
            chat: .init(
                initialState: .init(history: [] as [DisplayedChatMessage], isReceivingMessage: false),
                reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }
            )
        )
        .padding()
        .fixedSize(horizontal: true, vertical: true)
        .background(Color.yellow)
        
    }
}

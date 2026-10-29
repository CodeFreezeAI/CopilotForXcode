import AppKit
import ChatService
import ComposableArchitecture
import SharedUIComponents
import SwiftUI

struct ChatTabItemView: View {
    let chat: StoreOf<Chat>

    var body: some View {
        WithPerceptionTracking {
            Text(chat.title)
        }
    }
}

struct ChatConversationItemView: View {
    let chat: StoreOf<Chat>
    
    var body: some View {
        WithPerceptionTracking {
            Text(chat.title)
                .frame(alignment: .leading)
        }
    }
}

struct ChatContextMenu: View {
    let store: StoreOf<ChatMenu>
    @AppStorage(\.customCommands) var customCommands

    var body: some View {
        WithPerceptionTracking {
            currentSystemPrompt
                .onAppear { store.send(.appear) }
            currentExtraSystemPrompt

            Divider()

            customCommandMenu
        }
    }

    @ViewBuilder
    var currentSystemPrompt: some View {
        Text("System Prompt:")
        Text({
            var text = store.systemPrompt
            if text.isEmpty { text = "N/A" }
            if text.count > 30 { text = String(text.prefix(30)) + "..." }
            return text
        }() as String)
    }

    @ViewBuilder
    var currentExtraSystemPrompt: some View {
        Text("Extra Prompt:")
        Text({
            var text = store.extraSystemPrompt
            if text.isEmpty { text = "N/A" }
            if text.count > 30 { text = String(text.prefix(30)) + "..." }
            return text
        }() as String)
    }

    var customCommandMenu: some View {
        Menu("Custom Commands") {
            ForEach(
                customCommands.filter {
                    switch $0.feature {
                    case .chatWithSelection, .customChat: return true
                    case .promptToCode: return false
                    case .singleRoundDialog: return false
                    }
                },
                id: \.name
            ) { command in
                Button(action: {
                    store.send(.customCommandButtonTapped(command))
                }) {
                    Text(command.name)
                        .scaledFont(.body)
                }
            }
        }
    }
}


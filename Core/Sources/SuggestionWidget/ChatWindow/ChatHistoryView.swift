import ActiveApplicationMonitor
import ConversationTab
import AppKit
import ComposableArchitecture
import SwiftUI
import ChatTab
import SharedUIComponents
import PersistMiddleware


struct ChatHistoryView: View {
    let store: StoreOf<ChatPanelFeature>
    @Environment(\.chatTabPool) var chatTabPool
    @Binding var isChatHistoryVisible: Bool
    @State private var searchText = ""
    
    var body: some View {
        WithPerceptionTracking {

            VStack(alignment: .center, spacing: 0) {
                Header(isChatHistoryVisible: $isChatHistoryVisible)
                    .frame(height: 32)
                    .padding(.leading, 16)
                    .padding(.trailing, 12)
                
                Divider()
                
                ChatHistorySearchBarView(searchText: $searchText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                
                ItemView(store: store, searchText: $searchText, isChatHistoryVisible: $isChatHistoryVisible)
                    .padding(.horizontal, 16)
            }
        }
    }
    
    struct Header: View {
        @Binding var isChatHistoryVisible: Bool
        @AppStorage(\.chatFontSize) var chatFontSize
        
        var body: some View {
            HStack {
                Text("Chat History")
                    .scaledFont(size: 13, weight: .bold)
                    .lineLimit(nil)
                
                Spacer()
                
                Button(action: {
                    isChatHistoryVisible = false
                }) {
                    Image(systemName: "xmark")
                        .scaledFont(.body)
                }
                .buttonStyle(HoverButtonStyle())
                .help("Close")
            }
        }
    }
    
    struct ItemView: View {
        let store: StoreOf<ChatPanelFeature>
        @Binding var searchText: String
        @Binding var isChatHistoryVisible: Bool
        @State private var storedChatTabPreviewInfos: [ChatTabPreviewInfo] = []
        
        @Environment(\.chatTabPool) var chatTabPool
        
        var body: some View {
            WithPerceptionTracking {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filteredTabInfo, id: \.id) { previewInfo in
                            ChatHistoryItemView(
                                store: store,
                                previewInfo: previewInfo,
                                isChatHistoryVisible: $isChatHistoryVisible
                            ) {
                                refreshStoredChatTabInfos()
                            }
                            .id(previewInfo.id)
                            .frame(height: 61)
                        }
                    }
                }
                .onAppear { refreshStoredChatTabInfos() }
            }
        }
        
        func refreshStoredChatTabInfos() -> Void {
            Task {
                if let workspacePath = store.chatHistory.selectedWorkspacePath,
                   let username = store.chatHistory.currentUsername
                {
                    storedChatTabPreviewInfos = ChatTabPreviewInfoStore.getAll(with: .init(workspacePath: workspacePath, username: username))
                }
            }
        }
        
        var filteredTabInfo: IdentifiedArray<String, ChatTabPreviewInfo> {
            // Only compute when view is visible to prevent unnecessary computation
            if !isChatHistoryVisible {
                return IdentifiedArray(uniqueElements: [])
            }
            
            guard !searchText.isEmpty else { return IdentifiedArray(uniqueElements: storedChatTabPreviewInfos) }

            let result = storedChatTabPreviewInfos.filter { info in
                return (info.title ?? "New Chat").localizedCaseInsensitiveContains(searchText)
            }
            
            return IdentifiedArray(uniqueElements: result)
        }
    }
}


struct ChatHistorySearchBarView: View {
    @Binding var searchText: String
    @FocusState private var isSearchBarFocused: Bool
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .scaledFont(.body)
            
            TextField("Search", text: $searchText)
                .scaledFont(.body)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isSearchBarFocused)
                .foregroundColor(searchText.isEmpty ? Color(nsColor: .placeholderTextColor) : Color(nsColor: .textColor))
        }
        .cornerRadius(10)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.1))
        )
        .onAppear {
            isSearchBarFocused = true
        }
    }
}

struct ChatHistoryItemView: View {
    let store: StoreOf<ChatPanelFeature>
    let previewInfo: ChatTabPreviewInfo
    @Environment(\.colorScheme) var colorScheme
    @Binding var isChatHistoryVisible: Bool
    @State private var isHovered = false
    
    let onDelete: () -> Void
    
    func isTabSelected() -> Bool {
        return store.state.currentChatWorkspace?.selectedTabId == previewInfo.id
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy, h:mm a"
        return formatter.string(from: date)
    }
    
    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            // Do not use the `ChatConversationItemView` any more
                            // directly get title from chat tab info
                            Text(previewInfo.title ?? "New Chat")
                                .frame(alignment: .leading)
                                .scaledFont(size: 14, weight: .semibold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            if isTabSelected() {
                                Text("Current")
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 0) {
                            Text(formatDate(previewInfo.updatedAt))
                                .frame(alignment: .leading)
                                .scaledFont(size: 13, weight: .regular)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    if !isTabSelected() {
                        Button(action: {
                            Task { @MainActor in
                                await store.send(.chatHistoryDeleteButtonClicked(id: previewInfo.id)).finish()
                                onDelete()
                            }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.primary)
                                .scaledFont(.body)
                                .opacity(isHovered ? 1 : 0)
                        }
                        .buttonStyle(HoverButtonStyle())
                        .help("Delete")
                        .allowsHitTesting(isHovered)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: .infinity)
            .onHover(perform: {
                isHovered = $0
            })
            .hoverRadiusBackground(
                isHovered: isHovered,
                hoverColor: Color(
                    nsColor: .controlColor
                        .withAlphaComponent(colorScheme == .dark ? 0.1 : 0.55)
                ),
                cornerRadius: 8,
                showBorder: isHovered,
                borderColor: Color(nsColor: .separatorColor)
            )
            .onTapGesture {
                Task { @MainActor in
                    await store.send(.chatHistoryItemClicked(id: previewInfo.id)).finish()
                    isChatHistoryVisible = false
                }
            }
        }
    }
}

struct ChatHistoryView_Previews: PreviewProvider {
    static let pool = ChatTabPool([
        "2": EmptyChatTab(id: "2"),
        "3": EmptyChatTab(id: "3"),
        "4": EmptyChatTab(id: "4"),
        "5": EmptyChatTab(id: "5"),
        "6": EmptyChatTab(id: "6")
    ])

    static func createStore() -> StoreOf<ChatPanelFeature> {
        StoreOf<ChatPanelFeature>(
            initialState: .init(
                chatHistory: .init(
                    workspaces: [.init(
                        id: .init(path: "p", username: "u"),
                        tabInfo: [
                            .init(id: "2", title: "Empty-2", workspacePath: "path", username: "username"),
                            .init(id: "3", title: "Empty-3", workspacePath: "path", username: "username"),
                            .init(id: "4", title: "Empty-4", workspacePath: "path", username: "username"),
                            .init(id: "5", title: "Empty-5", workspacePath: "path", username: "username"),
                            .init(id: "6", title: "Empty-6", workspacePath: "path", username: "username")
                        ] as IdentifiedArray<String, ChatTabInfo>,
                        selectedTabId: "2"
                    ) { _ in }] as IdentifiedArray<WorkspaceIdentifier, ChatWorkspace>,
                    selectedWorkspacePath: "activeWorkspacePath",
                    selectedWorkspaceName: "activeWorkspacePath"
                ),
                isPanelDisplayed: true
            ),
            reducer: { ChatPanelFeature() }
        )
    }

    static var previews: some View {
        ChatHistoryView(
            store: createStore(),
            isChatHistoryVisible: .constant(true)
            )
            .xcodeStyleFrame()
            .padding()
            .environment(\.chatTabPool, pool)
    }
}

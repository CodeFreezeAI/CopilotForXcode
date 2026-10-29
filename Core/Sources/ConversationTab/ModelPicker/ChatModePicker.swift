import SwiftUI
import Persist
import ConversationServiceProvider
import GitHubCopilotService
import Combine
import SharedUIComponents

public extension Notification.Name {
    static let gitHubCopilotChatModeDidChange = Notification
        .Name("com.github.CopilotForXcode.ChatModeDidChange")
}

public enum ChatMode: String {
    case Ask = "Ask"
    case Agent = "Agent"
}

public struct ChatModePicker: View {
    @Binding var chatMode: String
    @Environment(\.colorScheme) var colorScheme
    @State var isAgentModeFFEnabled: Bool
    @State private var cancellables = Set<AnyCancellable>()
    var onScopeChange: (PromptTemplateScope) -> Void
    
    public init(chatMode: Binding<String>, onScopeChange: @escaping (PromptTemplateScope) -> Void = { _ in }) {
        self._chatMode = chatMode
        self.onScopeChange = onScopeChange
        self.isAgentModeFFEnabled = FeatureFlagNotifierImpl.shared.featureFlags.agentMode
    }
    
    private func setChatMode(mode: ChatMode) {
        chatMode = mode.rawValue
        AppState.shared.setSelectedChatMode(mode.rawValue)
        onScopeChange(mode == .Ask ? .chatPanel : .agentPanel)
        NotificationCenter.default.post(
            name: .gitHubCopilotChatModeDidChange,
            object: nil
        )
    }
    
    private func subscribeToFeatureFlagsDidChangeEvent() {
        FeatureFlagNotifierImpl.shared.featureFlagsDidChange.sink(receiveValue: { featureFlags in
            isAgentModeFFEnabled = featureFlags.agentMode
        })
        .store(in: &cancellables)
    }

    public var body: some View {
        VStack {
            if isAgentModeFFEnabled {
                HStack(spacing: -1) {
                    ModeButton(
                        title: "Ask",
                        isSelected: chatMode == "Ask",
                        activeBackground: colorScheme == .dark ? Color.white.opacity(0.25) : Color.white,
                        activeTextColor: Color.primary,
                        inactiveTextColor: Color.primary.opacity(0.5),
                        action: {
                            setChatMode(mode: .Ask)
                        }
                    )
                    
                    ModeButton(
                        title: "Agent",
                        isSelected: chatMode == "Agent",
                        activeBackground: Color.blue,
                        activeTextColor: Color.white,
                        inactiveTextColor: Color.primary.opacity(0.5),
                        action: {
                            setChatMode(mode: .Agent)
                        }
                    )
                }
                .scaledPadding(1)
                .scaledFrame(height: 20, alignment: .topLeading)
                .background(.primary.opacity(0.1))
                .cornerRadius(5)
                .padding(4)
                .help("Set Mode")
            } else {
                EmptyView()
            }
        }
        .task {
            subscribeToFeatureFlagsDidChangeEvent()
            if !isAgentModeFFEnabled {
                setChatMode(mode: .Ask)
            }
        }
        .onChange(of: isAgentModeFFEnabled) { newAgentModeFFEnabled in
            if !newAgentModeFFEnabled {
                setChatMode(mode: .Ask)
            }
        }
    }
}

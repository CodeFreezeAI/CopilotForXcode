import Foundation
import SwiftUI
import ChatService
import SharedUIComponents
import ComposableArchitecture
import ChatTab
import GitHubCopilotService

struct FunctionMessage: View {
    let text: String
    let chat: StoreOf<Chat>
    @AppStorage(\.chatFontSize) var chatFontSize
    @Environment(\.openURL) private var openURL
    
    private var isFreePlanUser: Bool {
        text.contains("30-day free trial")
    }

    private var isOrgUser: Bool {
        text.contains("reach out to your organization's Copilot admin")
    }

    private var switchToFallbackModelText: String {
        if let fallbackModelName = CopilotModelManager.getFallbackLLM(
            scope: chat.isAgentMode ? .agentPanel : .chatPanel
        )?.modelName {
            return "We have automatically switched you to \(fallbackModelName) which is included with your plan."
        } else {
            return ""
        }
    }

    private var errorContent: Text {
        switch (isFreePlanUser, isOrgUser) {
        case (true, _):
            return Text("Monthly message limit reached. Upgrade to Copilot Pro (30-day free trial) or wait for your limit to reset.")
            
        case (_, true):
            let parts = [
                "You have exceeded your free request allowance.",
                switchToFallbackModelText,
                "To enable additional paid premium requests, contact your organization admin."
            ].filter { !$0.isEmpty }
            return Text(attributedString(from: parts))

        default:
            let parts = [
                "You have exceeded your premium request allowance.",
                switchToFallbackModelText,
                "[Enable additional paid premium requests](https://aka.ms/github-copilot-manage-overage) to continue using premium models."
            ].filter { !$0.isEmpty }
            return Text(attributedString(from: parts))
        }
    }
    
    private func attributedString(from parts: [String]) -> AttributedString {
        do {
            return try AttributedString(markdown: parts.joined(separator: " "))
        } catch {
            return AttributedString(parts.joined(separator: " "))
        }
    }

    var body: some View {
        NotificationBanner(style: .warning) {
            errorContent
            
            if isFreePlanUser {
                Button("Update to Copilot Pro") {
                    if let url = URL(string: "https://aka.ms/github-copilot-upgrade-plan") {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .scaledFont(.body)
                .onHover { isHovering in
                    if isHovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
    }
}

struct FunctionMessage_Previews: PreviewProvider {
    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        FunctionMessage(
            text: "You've reached your monthly chat limit. Upgrade to Copilot Pro (30-day free trial) or wait until 1/17/2025, 8:00:00 AM for your limit to reset.",
            chat: .init(initialState: .init(), reducer: { Chat(service: ChatService.service(for: chatTabInfo)) })
        )
        .padding()
        .fixedSize()
    }
}

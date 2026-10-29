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
    
    private var isBYOKUser: Bool {
        text.contains("You've reached your quota limit for your BYOK model")
    }

    private var isTBBMessage: Bool {
        text.contains("AI Credits") || text.contains("additional overages")
    }

    private var switchToFallbackModelText: String {
        guard !isTBBMessage else { return "" }
        if let fallbackModelName = CopilotModelManager.getFallbackLLM(
            scope: chat.isAgentMode ? .agentPanel : .chatPanel
        )?.modelName {
            return "We have automatically switched you to \(fallbackModelName) which is included with your plan."
        }
        return ""
    }

    private var quotaActionButtons: [(title: String, urlString: String, isProminent: Bool)] {
        let lower = text.lowercased()
        let hasEnableOverage = lower.contains("enable additional overages")
        let hasIncreaseBudget = lower.contains("increase budget")
        let hasOverage = hasEnableOverage || hasIncreaseBudget
        var buttons: [(String, String, Bool)] = []
        if hasEnableOverage {
            buttons.append(("Enable Additional Overage", "https://aka.ms/github-copilot-manage-overage", true))
        }
        if hasIncreaseBudget {
            buttons.append(("Increase Budget", "https://aka.ms/github-copilot-manage-overage", true))
        }
        if lower.contains("upgrade your plan") {
            buttons.append(("Upgrade Plan", "https://aka.ms/github-copilot-upgrade-plan", !hasOverage))
        }
        return buttons
    }

    private var errorContent: Text {
        switch (isFreePlanUser, isOrgUser, isBYOKUser) {
        case (true, _, _):
            return Text("Monthly message limit reached. Upgrade to Copilot Pro (30-day free trial) or wait for your limit to reset.")

        case (_, true, _):
            let parts = [
                "You have exceeded your free request allowance.",
                switchToFallbackModelText,
                "To enable additional paid premium requests, contact your organization admin."
            ].filter { !$0.isEmpty }
            return Text(attributedString(from: parts))

        case (_, _, true):
            let sentences = splitBYOKQuotaMessage(text)
            guard sentences.count == 2 else { fallthrough }
            let parts = [sentences[0], switchToFallbackModelText, sentences[1]].filter { !$0.isEmpty }
            return Text(attributedString(from: parts))

        default:
            let parts = [text, switchToFallbackModelText].filter { !$0.isEmpty }
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

    private func splitBYOKQuotaMessage(_ message: String) -> [String] {
        // Fast path: find the first period followed by a space + capital P (for "Please")
        let boundary = ". Please check with"
        if let range = message.range(of: boundary) {
            // First sentence ends at the period just before " Please"
            let firstSentence = String(message[..<range.lowerBound]) + "."
            // Second sentence starts at "Please check with ..."
            let secondSentenceStart = message.index(range.lowerBound, offsetBy: 2) // skip ". "
            let secondSentence = String(message[secondSentenceStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return [firstSentence, secondSentence]
        }
        
        return [message]
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

            if !quotaActionButtons.isEmpty {
                HStack(spacing: 8) {
                    ForEach(quotaActionButtons, id: \.title) { button in
                        Group {
                            if button.isProminent {
                                Button(button.title) {
                                    if let url = URL(string: button.urlString) { openURL(url) }
                                }.buttonStyle(.borderedProminent)
                            } else {
                                Button(button.title) {
                                    if let url = URL(string: button.urlString) { openURL(url) }
                                }.buttonStyle(.bordered)
                            }
                        }
                        .controlSize(.regular)
                        .scaledFont(.body)
                        .onHover { if $0 { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
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

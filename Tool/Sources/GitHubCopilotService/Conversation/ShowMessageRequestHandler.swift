import JSONRPC
import Foundation
import Combine
import Logger
import AppKit
import LanguageServerProtocol
import NotificationCenterCoordinator
import UserNotifications

public protocol ShowMessageRequestHandler {
    func handleShowMessageRequest(
        _ request: ShowMessageRequest,
        callback: @escaping @Sendable (Result<MessageActionItem?, JSONRPCResponseError<JSONValue>>) async -> Void
    )
}

public final class ShowMessageRequestHandlerImpl: ShowMessageRequestHandler {
    public static let shared = ShowMessageRequestHandlerImpl()

    private init() {}

    public func handleShowMessageRequest(
        _ request: ShowMessageRequest,
        callback: @escaping @Sendable (Result<MessageActionItem?, JSONRPCResponseError<JSONValue>>) async -> Void
    ) {
        guard let params = request.params else { return }
        Logger.gitHubCopilot.debug("Received Show Message Request: \(params)")
        Task { @MainActor in
            await NotificationCenterCoordinator.shared.setupIfNeeded()

            let actionCount = params.actions?.count ?? 0
            
            // Use notification for messages with no action, alert for messages with actions
            if actionCount == 0 {
                await showMessageRequestNotification(params)
                await callback(.success(nil))
            } else {
                let selectedAction = showMessageRequestAlert(params)
                await callback(.success(selectedAction))
            }
        }
    }
    
    @MainActor
    func showMessageRequestNotification(_ params: ShowMessageRequestParams) async {
        let content = UNMutableNotificationContent()
        content.title = "GitHub Copilot for Xcode"
        content.body = params.message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.gitHubCopilot.error("Failed to show notification: \(error)")
        }
    }
    
    @MainActor
    func showMessageRequestAlert(_ params: ShowMessageRequestParams) -> MessageActionItem? {
        let alert = NSAlert()

        alert.messageText = "GitHub Copilot"
        alert.informativeText = params.message
        alert.alertStyle = params.type == .info ? .informational : .warning
        
        let actions = params.actions ?? []
        for item in actions {
            alert.addButton(withTitle: item.title)
        }
        
        let response = alert.runModal()
        
        // Map the button response to the corresponding action
        // .alertFirstButtonReturn = 1000, .alertSecondButtonReturn = 1001, etc.
        let buttonIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        
        guard buttonIndex >= 0 && buttonIndex < actions.count else {
            return nil
        }
        
        return actions[buttonIndex]
    }
}

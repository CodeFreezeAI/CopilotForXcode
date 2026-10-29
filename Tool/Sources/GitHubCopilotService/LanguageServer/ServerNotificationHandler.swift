import Combine
import Foundation
import JSONRPC
import LanguageServerProtocol

protocol ServerNotificationHandler {
    var protocolProgressSubject: PassthroughSubject<ProgressParams, Never> { get }
    func handleNotification(_ notification: AnyJSONRPCNotification)
}

class ServerNotificationHandlerImpl: ServerNotificationHandler {
    public static let shared = ServerNotificationHandlerImpl()
    var protocolProgressSubject: PassthroughSubject<LanguageServerProtocol.ProgressParams, Never>
    var conversationProgressHandler: ConversationProgressHandler = ConversationProgressHandlerImpl.shared
    var featureFlagNotifier: FeatureFlagNotifier = FeatureFlagNotifierImpl.shared
    var copilotPolicyNotifier: CopilotPolicyNotifier = CopilotPolicyNotifierImpl.shared
    var compressionHandler: CompressionHandler = CompressionHandlerImpl.shared
    var rateLimitNotifier: RateLimitNotifier = RateLimitNotifierImpl.shared
    var quotaNotifier: QuotaNotifier = QuotaNotifierImpl.shared

    init() {
        self.protocolProgressSubject = PassthroughSubject<ProgressParams, Never>()
    }

    func handleNotification(_ notification: AnyJSONRPCNotification) {
        let methodName = notification.method
        
        if let method = ServerNotification.Method(rawValue: methodName) {
            switch method {
            case .windowLogMessage:
                break
            case .protocolProgress:
                if let data = try? JSONEncoder().encode(notification.params),
                   let progress = try? JSONDecoder().decode(ProgressParams.self, from: data) {
                    conversationProgressHandler.handleConversationProgress(progress)
                }
            default:
                break
            }
        } else {
            switch methodName {
            case "copilot/didChangeFeatureFlags":
                if let data = try? JSONEncoder().encode(notification.params),
                   let didChangeFeatureFlagsParams = try? JSONDecoder().decode(
                    DidChangeFeatureFlagsParams.self,
                    from: data
                   ) {
                    featureFlagNotifier.handleFeatureFlagNotification(didChangeFeatureFlagsParams)
                }
                break
            case "policy/didChange":
                if let data = try? JSONEncoder().encode(notification.params),
                   let policy = try? JSONDecoder().decode(
                    CopilotPolicy.self,
                    from: data
                   ) {
                    copilotPolicyNotifier.handleCopilotPolicyNotification(policy)
                }
                break
            case "$/copilot/compressionStarted":
                if let payload = GitHubCopilotNotification.CompressionStartedNotification
                    .decode(fromParams: notification.params) {
                    compressionHandler.onCompressionStarted.send(payload.conversationId)
                }
                break
            case "$/copilot/compressionCompleted":
                if let payload = GitHubCopilotNotification.CompressionCompletedNotification
                    .decode(fromParams: notification.params) {
                    compressionHandler.onCompressionCompleted.send(payload)
                }
                break
            case "$/copilot/rateLimitWarning":
                if let data = try? JSONEncoder().encode(notification.params),
                   let params = try? JSONDecoder().decode(
                    RateLimitWarningParams.self,
                    from: data
                   ) {
                    rateLimitNotifier.handleRateLimitWarning(params)
                }
                break
            case "copilot/quotaChange":
                if let data = try? JSONEncoder().encode(notification.params),
                   let params = try? JSONDecoder().decode(
                    QuotaChangeParams.self,
                    from: data
                   ) {
                    quotaNotifier.handleQuotaChange(params)
                }
                break
            case "copilot/quotaWarning":
                if let data = try? JSONEncoder().encode(notification.params),
                   let params = try? JSONDecoder().decode(
                    QuotaWarningParams.self,
                    from: data
                   ) {
                    quotaNotifier.handleQuotaWarning(params)
                }
                break
            default:
                break
            }
        }
    }
}

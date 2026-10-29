import ConversationServiceProvider
import Foundation

public extension Notification.Name {
    static let gitHubCopilotModelsDidChange = Notification
        .Name("com.github.CopilotForXcode.CopilotModelsDidChange")
    static let gitHubCopilotShouldSwitchFallbackModel = Notification
        .Name("com.github.CopilotForXcode.CopilotShouldSwitchFallbackModel")
}

public class CopilotModelManager {
    private static var availableLLMs: [CopilotModel] = []
    private static var fallbackLLMs: [CopilotModel] = []
    
    public static func updateLLMs(_ models: [CopilotModel]) {
        let sortedModels = models.sorted(by: { $0.modelName.lowercased() < $1.modelName.lowercased() })
        guard sortedModels != availableLLMs else { return }
        availableLLMs = sortedModels
        fallbackLLMs = models.filter({ $0.isChatFallback})
        NotificationCenter.default.post(name: .gitHubCopilotModelsDidChange, object: nil)
    }

    public static func getAvailableLLMs() -> [CopilotModel] {
        return availableLLMs
    }

    public static func hasLLMs() -> Bool {
        return !availableLLMs.isEmpty
    }
    
    public static func getFallbackLLM(scope: PromptTemplateScope) -> CopilotModel? {
        return fallbackLLMs.first(where: { $0.scopes.contains(scope) && $0.billing?.isPremium == false})
    }
    
    public static func switchToFallbackModel() {
        NotificationCenter.default.post(name: .gitHubCopilotShouldSwitchFallbackModel, object: nil)
    }

    public static func clearLLMs() {
        availableLLMs = []
        NotificationCenter.default.post(name: .gitHubCopilotModelsDidChange, object: nil)
    }
}

import Foundation
import Combine
import Persist
import GitHubCopilotService
import ConversationServiceProvider

public let SELECTED_LLM_KEY = "selectedLLM"
public let SELECTED_CHATMODE_KEY = "selectedChatMode"
public let SELECTED_AGENT_SUBMODE_KEY = "selectedAgentSubMode"
public let SELECTED_REASONING_EFFORT_KEY = "selectedReasoningEffort"

public extension Notification.Name {
    static let gitHubCopilotSelectedModelDidChange = Notification.Name("com.github.CopilotForXcode.SelectedModelDidChange")
    static let gitHubCopilotSelectedReasoningEffortDidChange = Notification.Name("com.github.CopilotForXcode.SelectedReasoningEffortDidChange")
}

public extension AppState {
    func isSelectedModelSupportVision() -> Bool? {
        if let savedModel = get(key: SELECTED_LLM_KEY) {
           return savedModel["supportVision"]?.boolValue
        }
        return nil
    }
    
    func getSelectedModel() -> LLMModel? {
        guard let savedModel = get(key: SELECTED_LLM_KEY) else {
            return nil
        }
        
        guard let modelName = savedModel["modelName"]?.stringValue,
              let modelFamily = savedModel["modelFamily"]?.stringValue,
              let id = savedModel["id"]?.stringValue else {
            return nil
        }
        
        let displayName = savedModel["displayName"]?.stringValue
        let providerName = savedModel["providerName"]?.stringValue
        let supportVision = savedModel["supportVision"]?.boolValue ?? false
        let degradationReason = savedModel["degradationReason"]?.stringValue
        let supportsReasoningEffortLevel = savedModel["supportsReasoningEffortLevel"]?.boolValue ?? false
        var reasoningEfforts: [String]? = nil
        if case .array(let arr)? = savedModel["reasoningEfforts"] {
            reasoningEfforts = arr.compactMap { $0.stringValue }
        }

        // Try to reconstruct billing info if available
        var billing: CopilotModelBilling?
        if let isPremium = savedModel["billing"]?["isPremium"]?.boolValue,
           let multiplier = savedModel["billing"]?["multiplier"]?.numberValue {
            billing = CopilotModelBilling(
                isPremium: isPremium,
                multiplier: Float(multiplier)
            )
        }

        return LLMModel(
            displayName: displayName,
            modelName: modelName,
            modelFamily: modelFamily,
            id: id,
            billing: billing,
            providerName: providerName,
            supportVision: supportVision,
            degradationReason: degradationReason,
            reasoningEfforts: reasoningEfforts,
            supportsReasoningEffortLevel: supportsReasoningEffortLevel
        )
    }

    func setSelectedModel(_ model: LLMModel) {
        update(key: SELECTED_LLM_KEY, value: model)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .gitHubCopilotSelectedModelDidChange, object: nil)
        }
    }

    func getSelectedReasoningEffort(for model: LLMModel) -> String? {
        guard let saved = get(key: SELECTED_REASONING_EFFORT_KEY) else { return nil }
        return saved[model.reasoningEffortStorageKey]?.stringValue
    }

    func setSelectedReasoningEffort(_ effort: String, for model: LLMModel) {
        var efforts: [String: String] = [:]
        if let existing = get(key: SELECTED_REASONING_EFFORT_KEY),
           case .hash(let dict) = existing {
            for (k, v) in dict {
                if let s = v.stringValue { efforts[k] = s }
            }
        }
        efforts[model.reasoningEffortStorageKey] = effort
        update(key: SELECTED_REASONING_EFFORT_KEY, value: efforts)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .gitHubCopilotSelectedReasoningEffortDidChange, object: nil)
        }
    }

    /// Returns the effective reasoning effort for a given model:
    /// - `nil` if the model does not support reasoning effort
    /// - `nil` for the auto model — lets the server pick the effort for whichever model it routes to
    /// - the user-persisted value if set
    /// - otherwise the model-family default: "medium" for all models
    func effectiveReasoningEffort(for model: LLMModel) -> String? {
        guard model.supportsReasoningEffortLevel else { return nil }
        guard !model.isAutoModel else { return nil }
        let candidate = getSelectedReasoningEffort(for: model) ?? model.defaultReasoningEffort
        if let efforts = model.reasoningEfforts, !efforts.isEmpty {
            return efforts.contains(candidate) ? candidate : efforts.first
        }
        return candidate
    }

    func modelScope() -> PromptTemplateScope {
        return isAgentModeEnabled() ? .agentPanel : .chatPanel
    }
    
    func getSelectedChatMode() -> String {
        if let savedMode = get(key: SELECTED_CHATMODE_KEY),
           let modeName = savedMode.stringValue {
            return convertChatMode(modeName)
        }

        // Default to "Agent"
        return "Agent"
    }

    func setSelectedChatMode(_ mode: String) {
        update(key: SELECTED_CHATMODE_KEY, value: mode)
    }

    func isAgentModeEnabled() -> Bool {
        return getSelectedChatMode() == "Agent"
    }
    
    func getSelectedAgentSubMode() -> String {
        if let savedSubMode = get(key: SELECTED_AGENT_SUBMODE_KEY),
           let subMode = savedSubMode.stringValue {
            return subMode
        }
        // Default to "Agent"
        return "Agent"
    }
    
    func setSelectedAgentSubMode(_ subMode: String) {
        update(key: SELECTED_AGENT_SUBMODE_KEY, value: subMode)
    }

    private func convertChatMode(_ mode: String) -> String {
        switch mode {
        case "Ask":
            return "Ask"
        default:
            return "Agent"
        }
    }
}

public class CopilotModelManagerObservable: ObservableObject {
    static let shared = CopilotModelManagerObservable()
    
    @Published var availableChatModels: [LLMModel] = []
    @Published var availableAgentModels: [LLMModel] = []
    @Published var defaultChatModel: LLMModel?
    @Published var defaultAgentModel: LLMModel?
    @Published var availableChatBYOKModels: [LLMModel] = []
    @Published var availableAgentBYOKModels: [LLMModel] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Initial load
        availableChatModels = CopilotModelManager.getAvailableChatLLMs(scope: .chatPanel)
        availableAgentModels = CopilotModelManager.getAvailableChatLLMs(scope: .agentPanel)
        defaultChatModel = CopilotModelManager.getDefaultChatModel(scope: .chatPanel)
        defaultAgentModel = CopilotModelManager.getDefaultChatModel(scope: .agentPanel)
        availableChatBYOKModels = BYOKModelManager.getAvailableChatLLMs(scope: .chatPanel)
        availableAgentBYOKModels = BYOKModelManager.getAvailableChatLLMs(scope: .agentPanel)
        
        // Setup notification to update when models change
        NotificationCenter.default.publisher(for: .gitHubCopilotModelsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.availableChatModels = CopilotModelManager.getAvailableChatLLMs(scope: .chatPanel)
                self?.availableAgentModels = CopilotModelManager.getAvailableChatLLMs(scope: .agentPanel)
                self?.defaultChatModel = CopilotModelManager.getDefaultChatModel(scope: .chatPanel)
                self?.defaultAgentModel = CopilotModelManager.getDefaultChatModel(scope: .agentPanel)
                self?.availableChatBYOKModels = BYOKModelManager.getAvailableChatLLMs(scope: .chatPanel)
                self?.availableAgentBYOKModels = BYOKModelManager.getAvailableChatLLMs(scope: .agentPanel)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .gitHubCopilotShouldSwitchFallbackModel)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                if let fallbackModel = CopilotModelManager.getFallbackLLM(
                    scope: AppState.shared
                        .isAgentModeEnabled() ? .agentPanel : .chatPanel
                ) {
                    AppState.shared.setSelectedModel(fallbackModel.toLLMModel())
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Copilot Model Manager
public extension CopilotModelManager {
    static func getAvailableChatLLMs(scope: PromptTemplateScope = .chatPanel) -> [LLMModel] {
        let LLMs = CopilotModelManager.getAvailableLLMs()
        return LLMs.filter(
            { $0.scopes.contains(scope) }
        ).map {
            $0.toLLMModel(familyOverride: $0.isChatFallback ? $0.id : nil)
        }
    }

    static func getDefaultChatModel(scope: PromptTemplateScope = .chatPanel) -> LLMModel? {
        let LLMs = CopilotModelManager.getAvailableLLMs()
        let LLMsInScope = LLMs.filter({ $0.scopes.contains(scope) })
        let defaultModel = LLMsInScope.first(where: { $0.isChatDefault && $0.isAutoModel })
            ?? LLMsInScope.first(where: { $0.isChatDefault })
        // If a default model is found, return it
        if let defaultModel = defaultModel {
            return defaultModel.toLLMModel()
        }

        // Fallback to gpt-4.1 if available
        if let gpt4_1 = LLMsInScope.first(where: { $0.modelFamily == "gpt-4.1" }) {
            return gpt4_1.toLLMModel()
        }

        // If no default model is found, fallback to the first available model
        if let firstModel = LLMsInScope.first {
            return firstModel.toLLMModel()
        }

        return nil
    }
}

// MARK: - BYOK Model Manager
public extension BYOKModelManager {
    static func getAvailableChatLLMs(scope: PromptTemplateScope = .chatPanel) -> [LLMModel] {
        var BYOKModels = BYOKModelManager.getRegisteredBYOKModels()
        if scope == .agentPanel {
            BYOKModels = BYOKModels.filter(
                { $0.modelCapabilities?.toolCalling == true }
            )
        }
        return BYOKModels.map {
            return LLMModel(
                displayName: $0.modelCapabilities?.name,
                modelName: $0.modelId,
                modelFamily: $0.modelId,
                id: $0.modelId,
                billing: nil,
                providerName: $0.providerName.rawValue,
                supportVision: $0.modelCapabilities?.vision ?? false,
                maxInputTokens: $0.modelCapabilities?.maxInputTokens,
                maxOutputTokens: $0.modelCapabilities?.maxOutputTokens
            )
        }
    }
}

public struct LLMModel: Codable, Hashable, Equatable {
    public let displayName: String?
    public let modelName: String
    public let modelFamily: String
    public let id: String
    public let vendor: String?
    public let billing: CopilotModelBilling?
    public let providerName: String?
    public let supportVision: Bool
    public let degradationReason: String?
    public let maxInputTokens: Int?
    public let maxOutputTokens: Int?
    public let maxContextWindowTokens: Int?
    public let modelPickerCategory: String?
    public let modelPickerPriceCategory: String?
    public let reasoningEfforts: [String]?
    public let supportsReasoningEffortLevel: Bool

    public init(
        displayName: String? = nil,
        modelName: String,
        modelFamily: String,
        id: String,
        vendor: String? = nil,
        billing: CopilotModelBilling? = nil,
        providerName: String? = nil,
        supportVision: Bool,
        degradationReason: String? = nil,
        maxInputTokens: Int? = nil,
        maxOutputTokens: Int? = nil,
        maxContextWindowTokens: Int? = nil,
        modelPickerCategory: String? = nil,
        modelPickerPriceCategory: String? = nil,
        reasoningEfforts: [String]? = nil,
        supportsReasoningEffortLevel: Bool = false
    ) {
        self.displayName = displayName
        self.modelName = modelName
        self.modelFamily = modelFamily
        self.id = id
        self.vendor = vendor
        self.billing = billing
        self.providerName = providerName
        self.supportVision = supportVision
        self.degradationReason = degradationReason
        self.maxInputTokens = maxInputTokens
        self.maxOutputTokens = maxOutputTokens
        self.maxContextWindowTokens = maxContextWindowTokens
        self.modelPickerCategory = modelPickerCategory
        self.modelPickerPriceCategory = modelPickerPriceCategory
        self.reasoningEfforts = reasoningEfforts
        self.supportsReasoningEffortLevel = supportsReasoningEffortLevel
    }

    // Only compare model identity fields; exclude transient/display-only data
    // (billing, degradationReason, vendor, token limits) so that a persisted
    // model still matches a freshly-fetched one.
    public static func == (lhs: LLMModel, rhs: LLMModel) -> Bool {
        lhs.displayName == rhs.displayName &&
            lhs.modelName == rhs.modelName &&
            lhs.modelFamily == rhs.modelFamily &&
            lhs.id == rhs.id &&
            lhs.providerName == rhs.providerName &&
            lhs.supportVision == rhs.supportVision
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(displayName)
        hasher.combine(modelName)
        hasher.combine(modelFamily)
        hasher.combine(id)
        hasher.combine(providerName)
        hasher.combine(supportVision)
        hasher.combine(maxContextWindowTokens)
        hasher.combine(modelPickerPriceCategory)
    }
}

public extension LLMModel {
    /// Apply to `Copilot Models`
    var isPremiumModel: Bool { billing?.isPremium == true }
    /// Apply to `Copilot Models`
    var isStandardModel: Bool { !isPremiumModel || billing == nil }
    /// Apply to `Copilot Models`
    var isAutoModel: Bool { isStandardModel && modelName == "Auto" }

    var reasoningEffortStorageKey: String {
        "\(id)_\(providerName ?? "")"
    }

    var defaultReasoningEffort: String {
        "medium"
    }
}

extension CopilotModel {
    var isAutoModel: Bool { modelName == "Auto" }

    func toLLMModel(familyOverride: String? = nil) -> LLMModel {
        LLMModel(
            modelName: modelName,
            modelFamily: familyOverride ?? modelFamily,
            id: id,
            vendor: vendor,
            billing: billing,
            supportVision: capabilities.supports.vision,
            degradationReason: degradationReason,
            maxInputTokens: capabilities.limits?.maxInputTokens,
            maxOutputTokens: capabilities.limits?.maxOutputTokens,
            maxContextWindowTokens: capabilities.limits?.maxContextWindowTokens,
            modelPickerCategory: modelPickerCategory,
            modelPickerPriceCategory: modelPickerPriceCategory,
            reasoningEfforts: capabilities.supports.reasoningEfforts,
            supportsReasoningEffortLevel: capabilities.supports.supportsReasoningEffortLevel
        )
    }
}

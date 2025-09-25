import SwiftUI
import ChatService
import Persist
import ComposableArchitecture
import GitHubCopilotService
import Combine
import HostAppActivator
import SharedUIComponents
import ConversationServiceProvider

struct ModelPicker: View {
    @State private var selectedModel: LLMModel?
    @State private var isHovered = false
    @State private var isPressed = false
    @ObservedObject private var modelManager = CopilotModelManagerObservable.shared
    static var lastRefreshModelsTime: Date = .init(timeIntervalSince1970: 0)

    @State private var chatMode = "Ask"
    @State private var isAgentPickerHovered = false
    
    // Separate caches for both scopes
    @State private var askScopeCache: ScopeCache = ScopeCache()
    @State private var agentScopeCache: ScopeCache = ScopeCache()
    
    @State var isMCPFFEnabled: Bool
    @State var isBYOKFFEnabled: Bool
    @State private var cancellables = Set<AnyCancellable>()
    
    @StateObject private var fontScaleManager = FontScaleManager.shared
    
    var fontScale: Double {
        fontScaleManager.currentScale
    }

    let minimumPadding: Int = 48
    let attributes: [NSAttributedString.Key: NSFont] = [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]

    var spaceWidth: CGFloat {
        "\u{200A}".size(withAttributes: attributes).width
    }

    var minimumPaddingWidth: CGFloat {
        spaceWidth * CGFloat(minimumPadding)
    }

    init() {
        let initialModel = AppState.shared.getSelectedModel() ??
            CopilotModelManager.getDefaultChatModel()
        self._selectedModel = State(initialValue: initialModel)
        self.isMCPFFEnabled = FeatureFlagNotifierImpl.shared.featureFlags.mcp
        self.isBYOKFFEnabled = FeatureFlagNotifierImpl.shared.featureFlags.byok
        updateAgentPicker()
    }
    
    private func subscribeToFeatureFlagsDidChangeEvent() {
        FeatureFlagNotifierImpl.shared.featureFlagsDidChange.sink(receiveValue: { featureFlags in
            isMCPFFEnabled = featureFlags.mcp
            isBYOKFFEnabled = featureFlags.byok
        })
        .store(in: &cancellables)
    }

    var copilotModels: [LLMModel] {
        AppState.shared.isAgentModeEnabled() ?
        modelManager.availableAgentModels : modelManager.availableChatModels
    }
    
    var byokModels: [LLMModel] {
        AppState.shared.isAgentModeEnabled() ?
        modelManager.availableAgentBYOKModels : modelManager.availableChatBYOKModels
    }

    var defaultModel: LLMModel? {
        AppState.shared.isAgentModeEnabled() ? modelManager.defaultAgentModel : modelManager.defaultChatModel
    }

    // Get the current cache based on scope
    var currentCache: ScopeCache {
        AppState.shared.isAgentModeEnabled() ? agentScopeCache : askScopeCache
    }

    // Helper method to format multiplier text
    func formatMultiplierText(for billing: CopilotModelBilling?) -> String {
        guard let billingInfo = billing else { return "" }
        
        let multiplier = billingInfo.multiplier
        if multiplier == 0 {
            return "Included"
        } else {
            let numberPart = multiplier.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", multiplier)
                : String(format: "%.2f", multiplier)
            return "\(numberPart)x"
        }
    }
    
    // Update cache for specific scope only if models changed
    func updateModelCacheIfNeeded(for scope: PromptTemplateScope) {
        let currentModels = scope == .agentPanel ?
        modelManager.availableAgentModels + modelManager.availableAgentBYOKModels :
        modelManager.availableChatModels + modelManager.availableChatBYOKModels
        let modelsHash = currentModels.hashValue
        
        if scope == .agentPanel {
            guard agentScopeCache.lastModelsHash != modelsHash else { return }
            agentScopeCache = buildCache(for: currentModels, currentHash: modelsHash)
        } else {
            guard askScopeCache.lastModelsHash != modelsHash else { return }
            askScopeCache = buildCache(for: currentModels, currentHash: modelsHash)
        }
    }
    
    // Build cache for given models
    private func buildCache(for models: [LLMModel], currentHash: Int) -> ScopeCache {
        var newCache: [String: String] = [:]
        var maxWidth: CGFloat = 0

        for model in models {
            var multiplierText = ""
            if model.billing != nil {
                multiplierText = formatMultiplierText(for: model.billing)
            } else if let providerName = model.providerName, !providerName.isEmpty {
                // For BYOK models, show the provider name
                multiplierText = providerName
            }
            newCache[model.modelName.appending(model.providerName ?? "")] = multiplierText
            
            let displayName = "✓ \(model.displayName ?? model.modelName)"
            let displayNameWidth = displayName.size(withAttributes: attributes).width
            let multiplierWidth = multiplierText.isEmpty ? 0 : multiplierText.size(withAttributes: attributes).width
            let totalWidth = displayNameWidth + minimumPaddingWidth + multiplierWidth
            maxWidth = max(maxWidth, totalWidth)
        }

        if maxWidth == 0, let selectedModel = selectedModel {
            maxWidth = (selectedModel.displayName ?? selectedModel.modelName).size(withAttributes: attributes).width
        }
        
        return ScopeCache(
            modelMultiplierCache: newCache,
            cachedMaxWidth: maxWidth,
            lastModelsHash: currentHash
        )
    }

    func updateCurrentModel() {
        let currentModel = AppState.shared.getSelectedModel()
        var allAvailableModels = copilotModels
        if isBYOKFFEnabled {
            allAvailableModels += byokModels
        }
        
        // Check if current model exists in available models for current scope using model comparison
        let modelExists = allAvailableModels.contains { model in
            model == currentModel
        }
        
        if !modelExists && currentModel != nil {
            // Switch to default model if current model is not available
            if let fallbackModel = defaultModel {
                AppState.shared.setSelectedModel(fallbackModel)
                selectedModel = fallbackModel
            } else if let firstAvailable = allAvailableModels.first {
                // If no default model, use first available
                AppState.shared.setSelectedModel(firstAvailable)
                selectedModel = firstAvailable
            } else {
                selectedModel = nil
            }
        } else {
            selectedModel = currentModel ?? defaultModel
        }
    }
    
    func updateAgentPicker() {
        self.chatMode = AppState.shared.getSelectedChatMode()
    }
    
    func switchModelsForScope(_ scope: PromptTemplateScope) {
        let newModeModels = CopilotModelManager.getAvailableChatLLMs(
            scope: scope
        ) + BYOKModelManager.getAvailableChatLLMs(scope: scope)
        
        if let currentModel = AppState.shared.getSelectedModel() {
            if !newModeModels.isEmpty && !newModeModels.contains(where: { $0 == currentModel }) {
                let defaultModel = CopilotModelManager.getDefaultChatModel(scope: scope)
                if let defaultModel = defaultModel {
                    AppState.shared.setSelectedModel(defaultModel)
                } else {
                    AppState.shared.setSelectedModel(newModeModels[0])
                }
            }
        }
        
        self.updateCurrentModel()
        updateModelCacheIfNeeded(for: scope)
    }
    
    // Model picker menu component
    private var modelPickerMenu: some View {
        Menu {
            // Group models by premium status
            let premiumModels = copilotModels.filter {
                $0.billing?.isPremium == true
            }
            let standardModels = copilotModels.filter {
                $0.billing?.isPremium == false || $0.billing == nil
            }
            
            // Display standard models section if available
            modelSection(title: "Standard Models", models: standardModels)
            
            // Display premium models section if available
            modelSection(title: "Premium Models", models: premiumModels)
            
            if isBYOKFFEnabled {
                // Display byok models section if available
                modelSection(title: "Other Models", models: byokModels)

                Button("Manage Models...") {
                    try? launchHostAppBYOKSettings()
                }
            }
            
            if standardModels.isEmpty {
                Link("Add Premium Models", destination: URL(string: "https://aka.ms/github-copilot-upgrade-plan")!)
            }
        } label: {
            Text(selectedModel?.displayName ?? selectedModel?.modelName ?? "")
                // scaledFont not work here. workaround by direclty use the fontScale
                .font(.system(size: 13 * fontScale))
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .frame(maxWidth: labelWidth())
        .scaledPadding(4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isHovered ? Color.gray.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    // Helper function to create a section of model options
    @ViewBuilder
    private func modelSection(title: String, models: [LLMModel]) -> some View {
        if !models.isEmpty {
            Section(title) {
                ForEach(models, id: \.self) { model in
                    modelButton(for: model)
                }
            }
        }
    }
    
    // Helper function to create a model selection button
    private func modelButton(for model: LLMModel) -> some View {
        Button {
            AppState.shared.setSelectedModel(model)
        } label: {
            Text(createModelMenuItemAttributedString(
                modelName: model.displayName ?? model.modelName,
                isSelected: selectedModel == model,
                cachedMultiplierText: currentCache.modelMultiplierCache[model.modelName.appending(model.providerName ?? "")] ?? ""
            ))
        }
    }
    
    private var mcpButton: some View {
        Group {
            if isMCPFFEnabled {
                Button(action: {
                    try? launchHostAppToolsSettings()
                }) {
                    mcpIcon.foregroundColor(.primary.opacity(0.85))
                }
                .buttonStyle(HoverButtonStyle(padding: 0))
                .help("Configure your MCP server")
            } else {
                // Non-interactive view that looks like a button but only shows tooltip
                mcpIcon.foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .padding(0)
                    .help("MCP servers are disabled by org policy. Contact your admin.")
            }
        }
        .cornerRadius(6)
    }
    
    private var mcpIcon: some View {
        Image(systemName: "wrench.and.screwdriver")
            .resizable()
            .scaledToFit()
            .scaledFrame(width: 16, height: 16)
            .padding(4)
            .font(Font.system(size: 11, weight: .semibold))
    }
    
    // Main view body
    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: 0) {
                // Custom segmented control with color change
                ChatModePicker(chatMode: $chatMode, onScopeChange: switchModelsForScope)
                    .onAppear() {
                        updateAgentPicker()
                    }
                
                if chatMode == "Agent" {
                    mcpButton
                }

                // Model Picker
                Group {
                    if !copilotModels.isEmpty && selectedModel != nil {
                        modelPickerMenu
                    } else {
                        EmptyView()
                    }
                }
            }
            .onAppear() {
                updateCurrentModel()
                // Initialize both caches
                updateModelCacheIfNeeded(for: .chatPanel)
                updateModelCacheIfNeeded(for: .agentPanel)
                Task {
                    await refreshModels()
                }
            }
            .onChange(of: defaultModel) { _ in
                updateCurrentModel()
            }
            .onChange(of: modelManager.availableChatModels) { _ in
                updateCurrentModel()
                updateModelCacheIfNeeded(for: .chatPanel)
            }
            .onChange(of: modelManager.availableAgentModels) { _ in
                updateCurrentModel()
                updateModelCacheIfNeeded(for: .agentPanel)
            }
            .onChange(of: modelManager.availableChatBYOKModels) { _ in
                updateCurrentModel()
                updateModelCacheIfNeeded(for: .chatPanel)
            }
            .onChange(of: modelManager.availableAgentBYOKModels) { _ in
                updateCurrentModel()
                updateModelCacheIfNeeded(for: .agentPanel)
            }
            .onChange(of: chatMode) { _ in
                updateCurrentModel()
            }
            .onChange(of: isBYOKFFEnabled) { _ in
                updateCurrentModel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .gitHubCopilotSelectedModelDidChange)) { _ in
                updateCurrentModel()
            }
            .task {
                subscribeToFeatureFlagsDidChangeEvent()
            }
        }
    }

    func labelWidth() -> CGFloat {
        guard let selectedModel = selectedModel else { return 100 }
        let displayName = selectedModel.displayName ?? selectedModel.modelName
        let width = displayName.size(
            withAttributes: attributes
        ).width
        return CGFloat(width * fontScale + 20)
    }

    @MainActor
    func refreshModels() async {
        let now = Date()
        if now.timeIntervalSince(Self.lastRefreshModelsTime) < 60 {
            return
        }

        Self.lastRefreshModelsTime = now
        let copilotModels = await SharedChatService.shared.copilotModels()
        if !copilotModels.isEmpty {
            CopilotModelManager.updateLLMs(copilotModels)
        }
    }

    private func createModelMenuItemAttributedString(
        modelName: String,
        isSelected: Bool,
        cachedMultiplierText: String
    ) -> AttributedString {
        let displayName = isSelected ? "✓ \(modelName)" : "    \(modelName)"

        var fullString = displayName
        var attributedString = AttributedString(fullString)

        if !cachedMultiplierText.isEmpty {
            let displayNameWidth = displayName.size(withAttributes: attributes).width
            let multiplierTextWidth = cachedMultiplierText.size(withAttributes: attributes).width
            let neededPaddingWidth = currentCache.cachedMaxWidth - displayNameWidth - multiplierTextWidth
            let finalPaddingWidth = max(neededPaddingWidth, minimumPaddingWidth)
            
            let numberOfSpaces = Int(round(finalPaddingWidth / spaceWidth))
            let padding = String(repeating: "\u{200A}", count: max(minimumPadding, numberOfSpaces))
            fullString = "\(displayName)\(padding)\(cachedMultiplierText)"
            
            attributedString = AttributedString(fullString)

            if let range = attributedString.range(
                of: cachedMultiplierText,
                options: .backwards
            ) {
                attributedString[range].foregroundColor = .secondary
            }
        }

        return attributedString
    }
}

struct ModelPicker_Previews: PreviewProvider {
    static var previews: some View {
        ModelPicker()
    }
}

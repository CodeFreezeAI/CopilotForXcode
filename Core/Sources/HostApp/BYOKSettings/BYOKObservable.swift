import Client
import GitHubCopilotService
import Logger
import SwiftUI
import XPCShared
import SystemUtils

actor BYOKServiceActor {
    private let service: XPCExtensionService

    // MARK: - Write Serialization
    // Chains write operations so only one mutating request is in-flight at a time.
    private var writeQueue: Task<Void, Never>? = nil

    /// Enqueue a mutating operation ensuring strict sequential execution.
    private func enqueueWrite(_ op: @escaping () async throws -> Void) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let previousQueue = writeQueue
            writeQueue = Task {
                // Wait for all previous operations to complete
                await previousQueue?.value
                
                // Now execute this operation
                do {
                    try await op()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    init(serviceFactory: () throws -> XPCExtensionService) rethrows {
        self.service = try serviceFactory()
    }

    // MARK: - Listing (reads can stay concurrent)
    func listApiKeys() async throws -> [BYOKApiKeyInfo] {
        let resp = try await service.listBYOKApiKey(BYOKListApiKeysParams())
        return resp?.apiKeys ?? []
    }

    func listModels(providerName: BYOKProviderName? = nil,
                    enableFetchUrl: Bool? = nil) async throws -> [BYOKModelInfo] {
        let params = BYOKListModelsParams(providerName: providerName,
                                          enableFetchUrl: enableFetchUrl)
        let resp = try await service.listBYOKModels(params)
        return resp?.models ?? []
    }

    // MARK: - Mutations (serialized)
    func saveModel(_ model: BYOKModelInfo) async throws {
        try await enqueueWrite { [service] in
            _ = try await service.saveBYOKModel(model)
        }
    }

    func deleteModel(providerName: BYOKProviderName, modelId: String) async throws {
        try await enqueueWrite { [service] in
            let params = BYOKDeleteModelParams(providerName: providerName, modelId: modelId)
            _ = try await service.deleteBYOKModel(params)
        }
    }

    func saveApiKey(_ apiKey: String, providerName: BYOKProviderName) async throws {
        try await enqueueWrite { [service] in
            let params = BYOKSaveApiKeyParams(providerName: providerName, apiKey: apiKey)
            _ = try await service.saveBYOKApiKey(params)
        }
    }

    func deleteApiKey(providerName: BYOKProviderName) async throws {
        try await enqueueWrite { [service] in
            let params = BYOKDeleteApiKeyParams(providerName: providerName)
            _ = try await service.deleteBYOKApiKey(params)
        }
    }
}

@MainActor
class BYOKModelManagerObservable: ObservableObject {
    @Published var availableBYOKApiKeys: [BYOKApiKeyInfo] = []
    @Published var availableBYOKModels: [BYOKModelInfo] = []
    @Published var errorMessages: [BYOKProviderName: String] = [:]
    @Published var providerLoadingStates: [BYOKProviderName: Bool] = [:]

    private let serviceActor: BYOKServiceActor

    init() {
        self.serviceActor = try! BYOKServiceActor {
            try getService() // existing factory
        }
    }

    func refreshData() async {
        do {
            // Serialized by actor (even though we still parallelize logically, calls run one by one)
            async let apiKeys = serviceActor.listApiKeys()
            async let models = serviceActor.listModels()

            availableBYOKApiKeys = try await apiKeys
            availableBYOKModels = try await models.sorted()
        } catch {
            Logger.client.error("Failed to refresh BYOK data: \(error)")
        }
    }

    func deleteModel(_ model: BYOKModelInfo) async throws {
        try await serviceActor.deleteModel(providerName: model.providerName, modelId: model.modelId)
        await refreshData()
    }

    func saveModel(_ modelInfo: BYOKModelInfo) async throws {
        try await serviceActor.saveModel(modelInfo)
        await refreshData()
    }

    func saveApiKey(_ apiKey: String, providerName: BYOKProviderName) async throws {
        try await serviceActor.saveApiKey(apiKey, providerName: providerName)
        await refreshData()
    }

    func deleteApiKey(providerName: BYOKProviderName) async throws {
        try await serviceActor.deleteApiKey(providerName: providerName)
        errorMessages[providerName] = nil
        await refreshData()
    }

    func listModelsWithFetch(providerName: BYOKProviderName) async {
        providerLoadingStates[providerName] = true
        errorMessages[providerName] = nil
        defer { providerLoadingStates[providerName] = false }
        do {
            _ = try await serviceActor.listModels(providerName: providerName, enableFetchUrl: true)
            await refreshData()
        } catch {
            errorMessages[providerName] = error.localizedDescription
        }
    }

    func updateAllModels(providerName: BYOKProviderName, isRegistered: Bool) async throws {
        let current = availableBYOKModels.filter { $0.providerName == providerName && $0.isRegistered != isRegistered }
        guard !current.isEmpty else { return }
        for model in current {
            var updated = model
            updated.isRegistered = isRegistered
            try await serviceActor.saveModel(updated)
        }
        await refreshData()
    }
}

// MARK: - Provider-specific Data Filtering

extension BYOKModelManagerObservable {
    func filteredApiKeys(for provider: BYOKProviderName, modelId: String? = nil) -> [BYOKApiKeyInfo] {
        availableBYOKApiKeys.filter { apiKey in
            apiKey.providerName == provider && (modelId == nil || apiKey.modelId == modelId)
        }
    }

    func filteredModels(for provider: BYOKProviderName) -> [BYOKModelInfo] {
        availableBYOKModels.filter { $0.providerName == provider }
    }

    func hasApiKey(for provider: BYOKProviderName) -> Bool {
        !filteredApiKeys(for: provider).isEmpty
    }

    func hasModels(for provider: BYOKProviderName) -> Bool {
        !filteredModels(for: provider).isEmpty
    }

    func isLoadingProvider(_ provider: BYOKProviderName) -> Bool {
        providerLoadingStates[provider] ?? false
    }
}

public var BYOKHelpLink: String {
    var editorPluginVersion = SystemUtils.editorPluginVersionString
    if editorPluginVersion == "0.0.0" {
        editorPluginVersion = "main"
    }
    return "https://github.com/github/CopilotForXcode/blob/\(editorPluginVersion)/Docs/BYOK.md"
}

enum BYOKSheetType: Identifiable {
    case apiKey(BYOKProviderName)
    case model(BYOKProviderName, BYOKModelInfo? = nil)

    var id: String {
        switch self {
        case let .apiKey(provider):
            return "apiKey_\(provider.rawValue)"
        case let .model(provider, model):
            if let model = model {
                return "editModel_\(provider.rawValue)_\(model.modelId)"
            } else {
                return "model_\(provider.rawValue)"
            }
        }
    }
}

enum BYOKAuthType {
    case GlobalApiKey
    case PerModelDeployment

    var helpText: String {
        switch self {
        case .GlobalApiKey:
            return "Requires a single API key for all models"
        case .PerModelDeployment:
            return "Requires both deployment URL and API key per model"
        }
    }
}

extension BYOKProviderName {
    var title: String {
        switch self {
        case .Azure: return "Azure"
        case .Anthropic: return "Anthropic"
        case .Gemini: return "Gemini"
        case .Groq: return "Groq"
        case .OpenAI: return "OpenAI"
        case .OpenRouter: return "OpenRouter"
        }
    }

    // MARK: - Configuration Type

    /// The configuration approach used by this provider
    var authType: BYOKAuthType {
        switch self {
        case .Anthropic, .Gemini, .Groq, .OpenAI, .OpenRouter: return .GlobalApiKey
        case .Azure: return .PerModelDeployment
        }
    }
}

typealias BYOKProvider = BYOKProviderName

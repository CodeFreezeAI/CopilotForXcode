import Foundation

public class BYOKModelManager {
    private static var availableApiKeys: [BYOKApiKeyInfo] = []
    private static var availableBYOKModels: [BYOKModelInfo] = []

    public static func updateBYOKModels(BYOKModels: [BYOKModelInfo]) {
        let sortedModels = BYOKModels.sorted()
        guard sortedModels != availableBYOKModels else { return }
        availableBYOKModels = sortedModels
        NotificationCenter.default.post(name: .gitHubCopilotModelsDidChange, object: nil)
    }

    public static func hasBYOKModels(providerName: BYOKProviderName? = nil) -> Bool {
        if let providerName = providerName {
            return availableBYOKModels.contains { $0.providerName == providerName }
        }
        return !availableBYOKModels.isEmpty
    }

    public static func getRegisteredBYOKModels() -> [BYOKModelInfo] {
        let fullRegisteredBYOKModels = availableBYOKModels.filter({ $0.isRegistered })
        return fullRegisteredBYOKModels
    }

    public static func clearBYOKModels() {
        availableBYOKModels = []
    }

    public static func updateApiKeys(apiKeys: [BYOKApiKeyInfo]) {
        availableApiKeys = apiKeys
    }

    public static func hasApiKey(providerName: BYOKProviderName? = nil) -> Bool {
        if let providerName = providerName {
            return availableApiKeys.contains { $0.providerName == providerName }
        }
        return !availableApiKeys.isEmpty
    }

    public static func clearApiKeys() {
        availableApiKeys = []
    }
}

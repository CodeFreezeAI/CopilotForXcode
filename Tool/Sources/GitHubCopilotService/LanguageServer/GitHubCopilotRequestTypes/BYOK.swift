import Foundation

public enum BYOKProviderName: String, Codable, Equatable, Hashable, Comparable, CaseIterable {
    case Azure
    case Anthropic
    case Gemini
    case Groq
    case OpenAI
    case OpenRouter

    public static func < (lhs: BYOKProviderName, rhs: BYOKProviderName) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

public struct BYOKModelCapabilities: Codable, Equatable, Hashable {
    public var name: String
    public var maxInputTokens: Int?
    public var maxOutputTokens: Int?
    public var toolCalling: Bool
    public var vision: Bool

    public init(
        name: String,
        maxInputTokens: Int? = nil,
        maxOutputTokens: Int? = nil,
        toolCalling: Bool,
        vision: Bool
    ) {
        self.name = name
        self.maxInputTokens = maxInputTokens
        self.maxOutputTokens = maxOutputTokens
        self.toolCalling = toolCalling
        self.vision = vision
    }
}

public struct BYOKModelInfo: Codable, Equatable, Hashable, Comparable {
    public let providerName: BYOKProviderName
    public let modelId: String
    public var isRegistered: Bool
    public let isCustomModel: Bool
    public let deploymentUrl: String?
    public let apiKey: String?
    public var modelCapabilities: BYOKModelCapabilities?

    public init(
        providerName: BYOKProviderName,
        modelId: String,
        isRegistered: Bool,
        isCustomModel: Bool,
        deploymentUrl: String?,
        apiKey: String?,
        modelCapabilities: BYOKModelCapabilities?
    ) {
        self.providerName = providerName
        self.modelId = modelId
        self.isRegistered = isRegistered
        self.isCustomModel = isCustomModel
        self.deploymentUrl = deploymentUrl
        self.apiKey = apiKey
        self.modelCapabilities = modelCapabilities
    }

    public static func < (lhs: BYOKModelInfo, rhs: BYOKModelInfo) -> Bool {
        if lhs.providerName != rhs.providerName {
            return lhs.providerName < rhs.providerName
        }
        let lhsId = lhs.modelId.lowercased()
        let rhsId = rhs.modelId.lowercased()
        if lhsId != rhsId {
            return lhsId < rhsId
        }
        // Fallback to preserve deterministic ordering when only case differs
        return lhs.modelId < rhs.modelId
    }
}

public typealias BYOKSaveModelParams = BYOKModelInfo

public struct BYOKSaveModelResponse: Codable, Equatable, Hashable {
    public let success: Bool
    public let message: String
}

public struct BYOKDeleteModelParams: Codable, Equatable, Hashable {
    public let providerName: BYOKProviderName
    public let modelId: String

    public init(providerName: BYOKProviderName, modelId: String) {
        self.providerName = providerName
        self.modelId = modelId
    }
}

public typealias BYOKDeleteModelResponse = BYOKSaveModelResponse

public struct BYOKListModelsParams: Codable, Equatable, Hashable {
    public let providerName: BYOKProviderName?
    public let enableFetchUrl: Bool?

    public init(
        providerName: BYOKProviderName? = nil,
        enableFetchUrl: Bool? = nil
    ) {
        self.providerName = providerName
        self.enableFetchUrl = enableFetchUrl
    }
}

public struct BYOKListModelsResponse: Codable, Equatable, Hashable {
    public let models: [BYOKModelInfo]
}

public struct BYOKSaveApiKeyParams: Codable, Equatable, Hashable {
    public let providerName: BYOKProviderName
    public let apiKey: String
    public let modelId: String?

    public init(
        providerName: BYOKProviderName,
        apiKey: String,
        modelId: String? = nil
    ) {
        self.providerName = providerName
        self.apiKey = apiKey
        self.modelId = modelId
    }
}

public typealias BYOKSaveApiKeyResponse = BYOKSaveModelResponse

public struct BYOKDeleteApiKeyParams: Codable, Equatable, Hashable {
    public let providerName: BYOKProviderName

    public init(providerName: BYOKProviderName) {
        self.providerName = providerName
    }
}

public typealias BYOKDeleteApiKeyResponse = BYOKSaveModelResponse

public struct BYOKListApiKeysParams: Codable, Equatable, Hashable {
    public let providerName: BYOKProviderName?
    public let modelId: String?

    public init(providerName: BYOKProviderName? = nil, modelId: String? = nil) {
        self.providerName = providerName
        self.modelId = modelId
    }
}

public struct BYOKApiKeyInfo: Codable, Equatable, Hashable {
    public let providerName: BYOKProviderName
    public let modelId: String?
    public let apiKey: String?
}

public struct BYOKListApiKeysResponse: Codable, Equatable, Hashable {
    public let apiKeys: [BYOKApiKeyInfo]
}

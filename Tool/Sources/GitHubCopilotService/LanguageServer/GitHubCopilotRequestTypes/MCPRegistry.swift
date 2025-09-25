import Foundation
import JSONRPC
import ConversationServiceProvider

/// Schema definitions for MCP Registry API based on the OpenAPI spec:
/// https://github.com/modelcontextprotocol/registry/blob/main/docs/reference/api/openapi.yaml

// MARK: - Repository

public struct Repository: Codable {
    public let url: String
    public let source: String
    public let id: String?
    public let subfolder: String?

    enum CodingKeys: String, CodingKey {
        case url, source, id, subfolder
    }
}

// MARK: - Server Status

public enum ServerStatus: String, Codable {
    case active
    case deprecated
}

// MARK: - Base Input Protocol

public protocol InputProtocol: Codable {
    var description: String? { get }
    var isRequired: Bool? { get }
    var format: ArgumentFormat? { get }
    var value: String? { get }
    var isSecret: Bool? { get }
    var defaultValue: String? { get }
    var choices: [String]? { get }
}

// MARK: - Input (base type)

public struct Input: InputProtocol {
    public let description: String?
    public let isRequired: Bool?
    public let format: ArgumentFormat?
    public let value: String?
    public let isSecret: Bool?
    public let defaultValue: String?
    public let choices: [String]?

    enum CodingKeys: String, CodingKey {
        case description
        case isRequired = "is_required"
        case format
        case value
        case isSecret = "is_secret"
        case defaultValue = "default"
        case choices
    }
}

// MARK: - Input with Variables

public struct InputWithVariables: InputProtocol {
    public let description: String?
    public let isRequired: Bool?
    public let format: ArgumentFormat?
    public let value: String?
    public let isSecret: Bool?
    public let defaultValue: String?
    public let choices: [String]?
    public let variables: [String: Input]?

    enum CodingKeys: String, CodingKey {
        case description
        case isRequired = "is_required"
        case format
        case value
        case isSecret = "is_secret"
        case defaultValue = "default"
        case choices
        case variables
    }
}

// MARK: - Argument Format

public enum ArgumentFormat: String, Codable {
    case string
    case number
    case boolean
    case filepath
}

// MARK: - Argument Type

public enum ArgumentType: String, Codable {
    case positional
    case named
}

// MARK: - Base Argument Protocol

public protocol ArgumentProtocol: InputProtocol {
    var type: ArgumentType { get }
    var variables: [String: Input]? { get }
}

// MARK: - Positional Argument

public struct PositionalArgument: ArgumentProtocol {
    public let type: ArgumentType = .positional
    public let description: String?
    public let isRequired: Bool?
    public let format: ArgumentFormat?
    public let value: String?
    public let isSecret: Bool?
    public let defaultValue: String?
    public let choices: [String]?
    public let variables: [String: Input]?
    public let valueHint: String?
    public let isRepeated: Bool?

    enum CodingKeys: String, CodingKey {
        case type, description, format, value, choices, variables
        case isRequired = "is_required"
        case isSecret = "is_secret"
        case defaultValue = "default"
        case valueHint = "value_hint"
        case isRepeated = "is_repeated"
    }
}

// MARK: - Named Argument

public struct NamedArgument: ArgumentProtocol {
    public let type: ArgumentType = .named
    public let name: String
    public let description: String?
    public let isRequired: Bool?
    public let format: ArgumentFormat?
    public let value: String?
    public let isSecret: Bool?
    public let defaultValue: String?
    public let choices: [String]?
    public let variables: [String: Input]?
    public let isRepeated: Bool?

    enum CodingKeys: String, CodingKey {
        case type, name, description, format, value, choices, variables
        case isRequired = "is_required"
        case isSecret = "is_secret"
        case defaultValue = "default"
        case isRepeated = "is_repeated"
    }
}

// MARK: - Argument Enum

public enum Argument: Codable {
    case positional(PositionalArgument)
    case named(NamedArgument)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Discriminator.self)
        let type = try container.decode(ArgumentType.self, forKey: .type)
        switch type {
        case .positional:
            self = .positional(try PositionalArgument(from: decoder))
        case .named:
            self = .named(try NamedArgument(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .positional(let arg):
            try arg.encode(to: encoder)
        case .named(let arg):
            try arg.encode(to: encoder)
        }
    }

    private enum Discriminator: String, CodingKey {
        case type
    }
}

// MARK: - KeyValueInput

public struct KeyValueInput: InputProtocol {
    public let name: String
    public let description: String?
    public let isRequired: Bool?
    public let format: ArgumentFormat?
    public let value: String?
    public let isSecret: Bool?
    public let defaultValue: String?
    public let choices: [String]?
    public let variables: [String: Input]?

    enum CodingKeys: String, CodingKey {
        case name, description, format, value, choices, variables
        case isRequired = "is_required"
        case isSecret = "is_secret"
        case defaultValue = "default"
    }
}

// MARK: - Package

public struct Package: Codable {
    public let registryType: String?
    public let registryBaseURL: String?
    public let identifier: String?
    public let version: String?
    public let fileSHA256: String?
    public let runtimeHint: String?
    public let runtimeArguments: [Argument]?
    public let packageArguments: [Argument]?
    public let environmentVariables: [KeyValueInput]?

    enum CodingKeys: String, CodingKey {
        case version, identifier
        case registryType = "registry_type"
        case registryBaseURL = "registry_base_url"
        case fileSHA256 = "file_sha256"
        case runtimeHint = "runtime_hint"
        case runtimeArguments = "runtime_arguments"
        case packageArguments = "package_arguments"
        case environmentVariables = "environment_variables"
    }
}

// MARK: - Transport Type

public enum TransportType: String, Codable {
    case streamable = "streamable"
    case streamableHttp = "streamable-http"
    case sse = "sse"
}

// MARK: - Remote

public struct Remote: Codable {
    public let transportType: TransportType
    public let url: String
    public let headers: [KeyValueInput]?

    enum CodingKeys: String, CodingKey {
        case url, headers
        case transportType = "type"
    }
}

// MARK: - Publisher Provided Meta

public struct PublisherProvidedMeta: Codable {
    public let tool: String?
    public let version: String?
    public let buildInfo: BuildInfo?
    private let additionalProperties: [String: AnyCodable]?

    public struct BuildInfo: Codable {
        public let commit: String?
        public let timestamp: String?
        public let pipelineID: String?

        enum CodingKeys: String, CodingKey {
            case commit, timestamp
            case pipelineID = "pipeline_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tool, version
        case buildInfo = "build_info"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tool = try container.decodeIfPresent(String.self, forKey: .tool)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        buildInfo = try container.decodeIfPresent(BuildInfo.self, forKey: .buildInfo)

        // Capture additional properties
        let allKeys = try decoder.container(keyedBy: AnyCodingKey.self)
        var extras: [String: AnyCodable] = [:]
        
        for key in allKeys.allKeys {
            if !["tool", "version", "build_info"].contains(key.stringValue) {
                extras[key.stringValue] = try allKeys.decode(AnyCodable.self, forKey: key)
            }
        }
        additionalProperties = extras.isEmpty ? nil : extras
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(tool, forKey: .tool)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(buildInfo, forKey: .buildInfo)

        if let additionalProperties = additionalProperties {
            var dynamicContainer = encoder.container(keyedBy: AnyCodingKey.self)
            for (key, value) in additionalProperties {
                try dynamicContainer.encode(value, forKey: AnyCodingKey(stringValue: key)!)
            }
        }
    }
}

// MARK: - Official Meta

public struct OfficialMeta: Codable {
    public let id: String
    public let publishedAt: String
    public let updatedAt: String
    public let isLatest: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case publishedAt = "published_at"
        case updatedAt = "updated_at"
        case isLatest = "is_latest"
    }
}

// MARK: - Server Meta

public struct ServerMeta: Codable {
    public let publisherProvided: PublisherProvidedMeta?
    public let official: OfficialMeta?
    private let additionalProperties: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case publisherProvided = "io.modelcontextprotocol.registry/publisher-provided"
        case official = "io.modelcontextprotocol.registry/official"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        publisherProvided = try container.decodeIfPresent(PublisherProvidedMeta.self, forKey: .publisherProvided)
        official = try container.decodeIfPresent(OfficialMeta.self, forKey: .official)

        // Capture additional properties
        let allKeys = try decoder.container(keyedBy: AnyCodingKey.self)
        var extras: [String: AnyCodable] = [:]
        
        let knownKeys = ["io.modelcontextprotocol.registry/publisher-provided", "io.modelcontextprotocol.registry/official"]
        for key in allKeys.allKeys {
            if !knownKeys.contains(key.stringValue) {
                extras[key.stringValue] = try allKeys.decode(AnyCodable.self, forKey: key)
            }
        }
        additionalProperties = extras.isEmpty ? nil : extras
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(publisherProvided, forKey: .publisherProvided)
        try container.encodeIfPresent(official, forKey: .official)

        if let additionalProperties = additionalProperties {
            var dynamicContainer = encoder.container(keyedBy: AnyCodingKey.self)
            for (key, value) in additionalProperties {
                try dynamicContainer.encode(value, forKey: AnyCodingKey(stringValue: key)!)
            }
        }
    }
}

// MARK: - Dynamic Coding Key Helper

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Server Detail

public struct MCPRegistryServerDetail: Codable {
    public let name: String
    public let description: String
    public let status: ServerStatus?
    public let repository: Repository?
    public let version: String
    public let websiteURL: String?
    public let createdAt: String?
    public let updatedAt: String?
    public let schemaURL: String?
    public let packages: [Package]?
    public let remotes: [Remote]?
    public let meta: ServerMeta?

    enum CodingKeys: String, CodingKey {
        case name, description, status, repository, version, packages, remotes
        case websiteURL = "website_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case schemaURL = "$schema"
        case meta = "_meta"
    }
}

// MARK: - Server List Metadata

public struct MCPRegistryServerListMetadata: Codable {
    public let nextCursor: String?
    public let count: Int?

    enum CodingKeys: String, CodingKey {
        case nextCursor = "next_cursor"
        case count
    }
}

// MARK: - Server List

public struct MCPRegistryServerList: Codable {
    public let servers: [MCPRegistryServerDetail]
    public let metadata: MCPRegistryServerListMetadata?
}

// MARK: - Request Parameters

public struct MCPRegistryListServersParams: Codable {
    public let baseUrl: String
    public let cursor: String?
    public let limit: Int?

    public init(baseUrl: String, cursor: String? = nil, limit: Int? = nil) {
        self.baseUrl = baseUrl
        self.cursor = cursor
        self.limit = limit
    }
}

public struct MCPRegistryGetServerParams: Codable {
    public let baseUrl: String
    public let id: String
    public let version: String?

    public init(baseUrl: String, id: String, version: String?) {
        self.baseUrl = baseUrl
        self.id = id
        self.version = version
    }
}

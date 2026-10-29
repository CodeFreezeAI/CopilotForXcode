import Foundation

// MARK: - MCPRegistryOwner

public struct MCPRegistryOwner: Codable, Hashable {
    public let login: String
    public let id: Int
    public let type: String // "Business" (Enterprise) or "Organization"
    public let parentLogin: String?
    public let parentId: Int?
    
    enum CodingKeys: String, CodingKey {
        case login
        case id
        case type
        case parentLogin = "parent_login"
        case parentId = "parent_id"
    }
    
    public init(login: String, id: Int, type: String, parentLogin: String? = nil, parentId: Int? = nil) {
        self.login = login
        self.id = id
        self.type = type
        self.parentLogin = parentLogin
        self.parentId = parentId
    }
}

// MARK: - RegistryAccess

public enum RegistryAccess: String, Codable, Hashable {
    case registryOnly = "registry_only"
    case allowAll = "allow_all"
}

// MARK: - McpRegistryEntry

public struct MCPRegistryEntry: Codable, Hashable {
    public let url: String
    public let registryAccess: RegistryAccess
    public let owner: MCPRegistryOwner
    
    enum CodingKeys: String, CodingKey {
        case url
        case registryAccess = "registry_access"
        case owner
    }
    
    public init(url: String, registryAccess: RegistryAccess, owner: MCPRegistryOwner) {
        self.url = url
        self.registryAccess = registryAccess
        self.owner = owner
    }
}

// MARK: - GetMCPRegistryAllowlistResult  

/// Result schema for getMCPRegistryAllowlist method  
public struct GetMCPRegistryAllowlistResult: Codable, Hashable {
    public let mcpRegistries: [MCPRegistryEntry]
    
    enum CodingKeys: String, CodingKey {
        case mcpRegistries = "mcp_registries"
    }
}

public struct MCPRegistryErrorData: Codable {
    public let errorType: String
    public let status: Int?
    public let shouldRetry: Bool?
    
    enum CodingKeys: String, CodingKey {
        case errorType
        case status
        case shouldRetry
    }
    
    public init(errorType: String, status: Int? = nil, shouldRetry: Bool? = nil) {
        self.errorType = errorType
        self.status = status
        self.shouldRetry = shouldRetry
    }
}

import Foundation

public struct TurnItem: Codable, Equatable {
    public let id: String
    public let conversationID: String
    public let CLSTurnID: String?
    public let role: String
    public let data: String
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(id: String, conversationID: String, CLSTurnID: String?, role: String, data: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.conversationID = conversationID
        self.CLSTurnID = CLSTurnID
        self.role = role
        self.data = data
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ConversationItem: Codable, Equatable {
    public let id: String
    public let title: String?
    public let isSelected: Bool
    public let CLSConversationID: String?
    public let data: String
    public let createdAt: Date
    public let updatedAt: Date
    
    public init(id: String, title: String?, isSelected: Bool, CLSConversationID: String?, data: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.title = title
        self.isSelected = isSelected
        self.CLSConversationID = CLSConversationID
        self.data = data
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ConversationPreviewItem: Codable, Equatable {
    public let id: String
    public let title: String?
    public let isSelected: Bool
    public let updatedAt: Date
}

public enum DeleteType {
    case conversation(id: String)
    case turn(id: String)
    case turnByConversationID(conversationID: String)
}

public enum OperationType {
    case upsertTurn([TurnItem])
    case upsertConversation([ConversationItem])
    case delete([DeleteType])
}

public struct OperationRequest {

    var operations: [OperationType]
    
    public init(_ operations: [OperationType]) {
        self.operations = operations
    }
}

public enum ConversationFetchType {
    case all, selected, latest, id(String)
}

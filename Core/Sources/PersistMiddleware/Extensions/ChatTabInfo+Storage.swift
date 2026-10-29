import Foundation
import ChatTab
import Persist
import Logger

extension ChatTabInfo {
    
    func toConversationItem() -> ConversationItem {
        // Currently, no additional data to store.
        let data = "{}"
        
        return ConversationItem(id: self.id, title: self.title, isSelected: self.isSelected, CLSConversationID: self.CLSConversationID, data: data, createdAt: self.createdAt, updatedAt: self.updatedAt)
    }
    
    static func from(_ conversationItem: ConversationItem, with metadata: StorageMetadata) -> ChatTabInfo? {
        var chatTabInfo: ChatTabInfo? = nil
        
        chatTabInfo = .init(
            id: conversationItem.id,
            title: conversationItem.title,
            isSelected: conversationItem.isSelected,
            CLSConversationID: conversationItem.CLSConversationID,
            createdAt: conversationItem.createdAt,
            updatedAt: conversationItem.updatedAt,
            workspacePath: metadata.workspacePath,
            username: metadata.username)
        
        return chatTabInfo
    }
}


extension Array where Element == ChatTabInfo {
    func toConversationItems() -> [ConversationItem] {
        return self.map { $0.toConversationItem() }
    }
}

extension ChatTabPreviewInfo {
    static func from(_ conversationPreviewItem: ConversationPreviewItem) -> ChatTabPreviewInfo {
        return .init(
            id: conversationPreviewItem.id,
            title: conversationPreviewItem.title,
            isSelected: conversationPreviewItem.isSelected,
            updatedAt: conversationPreviewItem.updatedAt
        )
    }
}

import Persist
import ChatTab

public struct ChatTabInfoStore {
    public static func saveAll(_ chatTabInfos: [ChatTabInfo], with metadata: StorageMetadata) {
        let conversationItems = chatTabInfos.toConversationItems()
        ConversationStorageService.shared.operate(
            OperationRequest([.upsertConversation(conversationItems)]), metadata: metadata)
    }
    
    public static func delete(by id: String, with metadata: StorageMetadata) {
        ConversationStorageService.shared.operate(
            OperationRequest(
                [.delete([.conversation(id: id), .turnByConversationID(conversationID: id)])]),
            metadata: metadata)
    }
    
    public static func getAll(with metadata: StorageMetadata) -> [ChatTabInfo] {
        return fetchChatTabInfos(.all, metadata: metadata)
    }
    
    public static func getSelected(with metadata: StorageMetadata) -> ChatTabInfo? {
        return fetchChatTabInfos(.selected, metadata: metadata).first
    }
    
    public static func getLatest(with metadata: StorageMetadata) -> ChatTabInfo? {
        return fetchChatTabInfos(.latest, metadata: metadata).first
    }
    
    public static func getByID(_ id: String, with metadata: StorageMetadata) -> ChatTabInfo? {
        return fetchChatTabInfos(.id(id), metadata: metadata).first
    }
    
    private static func fetchChatTabInfos(_ type: ConversationFetchType, metadata: StorageMetadata) -> [ChatTabInfo] {
        let items = ConversationStorageService.shared.fetchConversationItems(type, metadata: metadata)
        
        return items.compactMap { ChatTabInfo.from($0, with: metadata) }
    }
}

public struct ChatTabPreviewInfoStore {
    public static func getAll(with metadata: StorageMetadata) -> [ChatTabPreviewInfo] {
        var previewInfos: [ChatTabPreviewInfo] = []
        
        let conversationPreviewItems = ConversationStorageService.shared.fetchConversationPreviewItems(metadata: metadata)
        if conversationPreviewItems.count > 0 {
            previewInfos = conversationPreviewItems.compactMap { ChatTabPreviewInfo.from($0) }
        }
        
        return previewInfos
    }
}

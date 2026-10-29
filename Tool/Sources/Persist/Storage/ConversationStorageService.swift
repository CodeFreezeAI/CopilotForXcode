import Foundation
import CryptoKit
import Logger

extension String {
    
    func appendingPathComponents(_ components: String...) -> String {
        var url = URL(fileURLWithPath: self)
        components.forEach { component in
            url = url.appendingPathComponent(component)
        }
        
        return url.path
    }
}

protocol ConversationStorageServiceProtocol {
    func fetchConversationItems(_ type: ConversationFetchType, metadata: StorageMetadata) -> [ConversationItem]
    func fetchTurnItems(for conversationID: String, metadata: StorageMetadata) -> [TurnItem]

    func operate(_ request: OperationRequest, metadata: StorageMetadata)
    
    func terminate()
}

public struct StorageMetadata: Hashable {
    public var workspacePath: String
    public var username: String
    
    public init(workspacePath: String, username: String) {
        self.workspacePath = workspacePath
        self.username = username
    }
}

public final class ConversationStorageService: ConversationStorageServiceProtocol {
    private var conversationStoragePool: [StorageMetadata: ConversationStorage] = [:]
    public static let shared = ConversationStorageService()
    private init() { }
    
    // The storage path would be xdgConfigHome/usernameHash/conversations/workspacePathHash.db
    private func getPersistenceFile(_ metadata: StorageMetadata) -> String {
        let fileName = "\(ConfigPathUtils.toHash(contents: metadata.workspacePath)).db"
        let persistenceFileURL = ConfigPathUtils.configFilePath(
            userName: metadata.username,
            subDirectory: "conversations",
            fileName: fileName
        )
        
        return persistenceFileURL.path
    }
    
    private func getConversationStorage(_ metadata: StorageMetadata) throws -> ConversationStorage {
        if let existConversationStorage = conversationStoragePool[metadata] {
            return existConversationStorage
        }
        
        let persistenceFile = getPersistenceFile(metadata)

        let conversationStorage = try ConversationStorage(persistenceFile)
        try conversationStorage.createTableIfNeeded()
        conversationStoragePool[metadata] = conversationStorage
        return conversationStorage
    }
    
    private func ensurePathExists(_ path: String) -> Bool {
        
        do {
            let fileManager = FileManager.default
            let pathURL = URL(fileURLWithPath: path)
            if !fileManager.fileExists(atPath: path) {
                try fileManager.createDirectory(at: pathURL, withIntermediateDirectories: true)
            }
        } catch {
            Logger.client.error("Failed to create persistence path: \(error)")
            return false
        }

        return true
    }
    
    private func withStorage<T>(_ metadata: StorageMetadata, operation: (ConversationStorage) throws -> T) throws -> T {
        let storage = try getConversationStorage(metadata)
        return try operation(storage)
    }
    
    public func fetchConversationItems(_ type: ConversationFetchType, metadata: StorageMetadata) -> [ConversationItem] {
        var items: [ConversationItem] = []
        do {
            try withStorage(metadata) { conversationStorage in
                items = try conversationStorage.fetchConversationItems(type)
            }
        } catch {
            Logger.client.error("Failed to fetch conversation items: \(error)")
        }
        
        return items
    }
    
    public func fetchConversationPreviewItems(metadata: StorageMetadata) -> [ConversationPreviewItem] {
        var items: [ConversationPreviewItem] = []
        
        do {
            try withStorage(metadata) { conversationStorage in
                items = try conversationStorage.fetchConversationPreviewItems()
            }
        } catch {
            Logger.client.error("Failed to fetch conversation preview items: \(error)")
        }
        
        return items
    }
    
    public func fetchTurnItems(for conversationID: String, metadata: StorageMetadata) -> [TurnItem] {
        var items: [TurnItem] = []
        
        do {
            try withStorage(metadata) { conversationStorage in
                items = try conversationStorage.fetchTurnItems(for: conversationID)
            }
        } catch {
            Logger.client.error("Failed to fetch turn items: \(error)")
        }
        
        return items
    }
    
    public func operate(_ request: OperationRequest, metadata: StorageMetadata) {
        do {
            try withStorage(metadata) { conversationStorage in
                try conversationStorage.operate(request)
            }
            
        } catch {
            Logger.client.error("Failed to operate database request: \(error)")
        }
    }
    
    public func terminate() {
        conversationStoragePool = [:]
    }
}

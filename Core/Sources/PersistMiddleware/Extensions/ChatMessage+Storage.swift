import Foundation
import ChatAPIService
import Persist
import Logger
import ConversationServiceProvider

extension ChatMessage {
    
    struct TurnItemData: Codable {
        var content: String
        var rating: ConversationRating
        var references: [ConversationReference]
        var followUp: ConversationFollowUp?
        var suggestedTitle: String?
        var errorMessages: [String] = []
        var steps: [ConversationProgressStep]
        var editAgentRounds: [AgentRound]
        var panelMessages: [CopilotShowMessageParams]

        // Custom decoder to provide default value for steps
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            content = try container.decode(String.self, forKey: .content)
            rating = try container.decode(ConversationRating.self, forKey: .rating)
            references = try container.decode([ConversationReference].self, forKey: .references)
            followUp = try container.decodeIfPresent(ConversationFollowUp.self, forKey: .followUp)
            suggestedTitle = try container.decodeIfPresent(String.self, forKey: .suggestedTitle)
            errorMessages = try container.decodeIfPresent([String].self, forKey: .errorMessages) ?? []
            steps = try container.decodeIfPresent([ConversationProgressStep].self, forKey: .steps) ?? []
            editAgentRounds = try container.decodeIfPresent([AgentRound].self, forKey: .editAgentRounds) ?? []
            panelMessages = try container.decodeIfPresent([CopilotShowMessageParams].self, forKey: .panelMessages) ?? []
        }

        // Default memberwise init for encoding
        init(
            content: String,
            rating: ConversationRating,
            references: [ConversationReference],
            followUp: ConversationFollowUp?,
            suggestedTitle: String?,
            errorMessages: [String] = [],
            steps: [ConversationProgressStep]?,
            editAgentRounds: [AgentRound]? = nil,
            panelMessages: [CopilotShowMessageParams]? = nil
        ) {
            self.content = content
            self.rating = rating
            self.references = references
            self.followUp = followUp
            self.suggestedTitle = suggestedTitle
            self.errorMessages = errorMessages
            self.steps = steps ?? []
            self.editAgentRounds = editAgentRounds ?? []
            self.panelMessages = panelMessages ?? []
        }
    }
    
    func toTurnItem() -> TurnItem {
        let turnItemData = TurnItemData(
            content: self.content,
            rating: self.rating,
            references: self.references,
            followUp: self.followUp,
            suggestedTitle: self.suggestedTitle,
            errorMessages: self.errorMessages,
            steps: self.steps,
            editAgentRounds: self.editAgentRounds,
            panelMessages: self.panelMessages
        )
        
        // TODO: handle exception
        let encoder = JSONEncoder()
        let encodeData = (try? encoder.encode(turnItemData)) ?? Data()
        let data = String(data: encodeData, encoding: .utf8) ?? "{}"
        
        return TurnItem(id: self.id, conversationID: self.chatTabID, CLSTurnID: self.clsTurnID, role: role.rawValue, data: data, createdAt: self.createdAt, updatedAt: self.updatedAt)
    }
    
    static func from(_ turnItem: TurnItem) -> ChatMessage? {
        var chatMessage: ChatMessage? = nil
                
        do {
            if let jsonData = turnItem.data.data(using: .utf8) {
                let decoder = JSONDecoder()
                let turnItemData = try decoder.decode(TurnItemData.self, from: jsonData)
                
                chatMessage = .init(
                    id: turnItem.id,
                    chatTabID: turnItem.conversationID,
                    clsTurnID: turnItem.CLSTurnID,
                    role: ChatMessage.Role(rawValue: turnItem.role)!,
                    content: turnItemData.content,
                    references: turnItemData.references,
                    followUp: turnItemData.followUp,
                    suggestedTitle: turnItemData.suggestedTitle,
                    errorMessages: turnItemData.errorMessages,
                    rating: turnItemData.rating,
                    steps: turnItemData.steps,
                    editAgentRounds: turnItemData.editAgentRounds,
                    panelMessages: turnItemData.panelMessages,
                    createdAt: turnItem.createdAt,
                    updatedAt: turnItem.updatedAt
                )
            }
        } catch {
            Logger.client.error("Failed to restore chat message: \(error)")
        }
        
        return chatMessage
    }
}

extension Array where Element == ChatMessage {
    func toTurnItems() -> [TurnItem] {
        return self.map { $0.toTurnItem() }
    }
}

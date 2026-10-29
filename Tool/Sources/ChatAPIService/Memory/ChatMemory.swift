import Foundation
import ConversationServiceProvider

public protocol ChatMemory {
    /// The message history.
    var history: [ChatMessage] { get async }
    /// Update the message history.
    func mutateHistory(_ update: (inout [ChatMessage]) -> Void) async
}

public extension ChatMemory {
    /// Append a message to the history.
    func appendMessage(_ message: ChatMessage) async {
        await mutateHistory { history in
            if let index = history.firstIndex(where: { $0.id == message.id }) {
                history[index].mergeMessage(with: message)
            } else {
                history.append(message)
            }
        }
    }

    /// Remove a message from the history.
    func removeMessage(_ id: String) async {
        await mutateHistory {
            $0.removeAll { $0.id == id }
        }
    }

    /// Clear the history.
    func clearHistory() async {
        await mutateHistory { $0.removeAll() }
    }
}

extension ChatMessage {
    mutating func mergeMessage(with message: ChatMessage) {
        // merge content
        self.content = self.content + message.content
        
        // merge references
        var seen = Set<ConversationReference>()
        // without duplicated and keep order
        self.references = (self.references + message.references).filter { seen.insert($0).inserted }
        
        // merge followUp
        self.followUp = message.followUp ?? self.followUp
        
        // merge suggested title
        self.suggestedTitle = message.suggestedTitle ?? self.suggestedTitle
        
        // merge error message
        self.errorMessages = self.errorMessages + message.errorMessages
        
        self.panelMessages = self.panelMessages + message.panelMessages
        
        // merge steps
        if !message.steps.isEmpty {
            var mergedSteps = self.steps
            
            for newStep in message.steps {
                if let index = mergedSteps.firstIndex(where: { $0.id == newStep.id }) {
                    mergedSteps[index] = newStep
                } else {
                    mergedSteps.append(newStep)
                }
            }
            
            self.steps = mergedSteps
        }
        
        // merge agent steps
        if !message.editAgentRounds.isEmpty {
            let mergedAgentRounds = mergeEditAgentRounds(
                oldRounds: self.editAgentRounds, 
                newRounds: message.editAgentRounds
            )
            
            self.editAgentRounds = mergedAgentRounds
        }
        
        self.codeReviewRound = message.codeReviewRound
    }
    
    private func mergeEditAgentRounds(oldRounds: [AgentRound], newRounds: [AgentRound]) -> [AgentRound] {
        var mergedAgentRounds = oldRounds
        
        for newRound in newRounds {
            if let index = mergedAgentRounds.firstIndex(where: { $0.roundId == newRound.roundId }) {
                mergedAgentRounds[index].reply = mergedAgentRounds[index].reply + newRound.reply
                
                if newRound.toolCalls != nil, !newRound.toolCalls!.isEmpty {
                    var mergedToolCalls = mergedAgentRounds[index].toolCalls ?? []
                    for newToolCall in newRound.toolCalls! {
                        if let toolCallIndex = mergedToolCalls.firstIndex(where: { $0.id == newToolCall.id }) {
                            mergedToolCalls[toolCallIndex].status = newToolCall.status
                            if let progressMessage = newToolCall.progressMessage, !progressMessage.isEmpty {
                                mergedToolCalls[toolCallIndex].progressMessage = newToolCall.progressMessage
                            }
                            if let error = newToolCall.error, !error.isEmpty {
                                mergedToolCalls[toolCallIndex].error = newToolCall.error
                            }
                            if let invokeParams = newToolCall.invokeParams {
                                mergedToolCalls[toolCallIndex].invokeParams = invokeParams
                            }
                        } else {
                            mergedToolCalls.append(newToolCall)
                        }
                    }
                    mergedAgentRounds[index].toolCalls = mergedToolCalls
                }
            } else {
                mergedAgentRounds.append(newRound)
            }
        }
        
        return mergedAgentRounds
    }
}

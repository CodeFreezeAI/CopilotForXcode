import CodableWrappers
import Foundation
import Preferences

struct ChatCompletionsRequestBody: Codable, Equatable {
    struct Message: Codable, Equatable {
        enum Role: String, Codable, Equatable {
            case user
            case assistant
            
            var asChatMessageRole: ChatMessage.Role {
                switch self {
                case .user:
                    return .user
                case .assistant:
                    return .assistant
                }
            }
        }

        /// The role of the message.
        var role: Role
        /// The content of the message.
        
        var content: String
    }

    var messages: [Message]
    var temperature: Double?
    var stream: Bool?
    var stop: [String]?

    init(
        messages: [Message],
        temperature: Double? = nil,
        stream: Bool? = nil,
        stop: [String]? = nil
    ) {
        self.messages = messages
        self.temperature = temperature
        self.stream = stream
        self.stop = stop
    }
}

// MARK: - Stream API

extension AsyncSequence {
    func toStream() -> AsyncThrowingStream<Element, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await element in self {
                        continuation.yield(element)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

struct ChatCompletionsStreamDataChunk {
    struct Delta {
        var role: ChatCompletionsRequestBody.Message.Role?
        var content: String?
    }

    var id: String?
    var object: String?
    var model: String?
    var message: Delta?
    var finishReason: String?
}

// MARK: - Non Stream API

struct ChatCompletionResponseBody: Codable, Equatable {
    typealias Message = ChatCompletionsRequestBody.Message

    var id: String?
    var object: String
    var message: Message
    var otherChoices: [Message]
    var finishReason: String
}


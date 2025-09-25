import ChatAPIService
import ConversationServiceProvider
import Foundation
import Logger
import GitHelper

public struct CodeReviewServiceProvider {
    public var conversationServiceProvider: (any ConversationServiceProvider)?
}

public struct CodeReviewProvider {
    public static func invoke(
        _ request: CodeReviewRequest,
        context: CodeReviewServiceProvider
    ) async -> (fileComments: [CodeReviewResponse.FileComment], errorMessage: String?) {
        var fileComments: [CodeReviewResponse.FileComment] = []
        var errorMessage: String?
        
        do {
            if let result = try await requestReviewChanges(request.fileChange.selectedChanges, context: context) {
                for comment in result.comments {
                    guard let change = request.fileChange.selectedChanges.first(where: { $0.uri == comment.uri }) else {
                        continue
                    }
                    
                    if let index = fileComments.firstIndex(where: { $0.uri == comment.uri }) {
                        var currentFileComments = fileComments[index]
                        currentFileComments.comments.append(comment)
                        fileComments[index] = currentFileComments
                        
                    } else {
                        fileComments.append(
                            .init(uri: change.uri, originalContent: change.originalContent, comments: [comment])
                        )
                    }
                }
            }
        } catch {
            Logger.gitHubCopilot.error("Failed to review change: \(error)")
            errorMessage = "Oops, failed to review changes."
        }
        
        return (fileComments, errorMessage)
    }
    
    private static func requestReviewChanges(
        _ changes: [PRChange],
        context: CodeReviewServiceProvider
    ) async throws -> CodeReviewResult? {
        return try await context.conversationServiceProvider?
            .reviewChanges(
                .init(
                    changes: changes.map {
                        .init(uri: $0.uri, path: $0.path, baseContent: $0.baseContent, headContent: $0.headContent)
                    }
                )
            )
    }
}

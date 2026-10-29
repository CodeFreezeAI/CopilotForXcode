import Collections
import ConversationServiceProvider
import Foundation
import LanguageServerProtocol

public struct DocumentReview: Equatable {
    public var comments: [ReviewComment]
    public let originalContent: String
}

public typealias DocumentReviewsByUri = OrderedDictionary<DocumentUri, DocumentReview>

@MainActor
public class CodeReviewService: ObservableObject {
    @Published public private(set) var documentReviews: DocumentReviewsByUri = [:]
    
    public static let shared = CodeReviewService()
    
    private init() {}
    
    public func updateComments(for uri: DocumentUri, comments: [ReviewComment], originalContent: String) {
        if var existing = documentReviews[uri] {
            existing.comments.append(contentsOf: comments)
            existing.comments = sortedComments(existing.comments)
            documentReviews[uri] = existing
        } else {
            documentReviews[uri] = .init(comments: comments, originalContent: originalContent)
        }
    }
    
    public func updateComments(_ fileComments: [CodeReviewResponse.FileComment]) {
        for fileComment in fileComments {
            updateComments(
                for: fileComment.uri,
                comments: fileComment.comments,
                originalContent: fileComment.originalContent
            )
        }
    }
    
    private func sortedComments(_ comments: [ReviewComment]) -> [ReviewComment] {
        return comments.sorted { $0.range.end.line < $1.range.end.line }
    }
    
    public func resetComments() {
        documentReviews = [:]
    }
}

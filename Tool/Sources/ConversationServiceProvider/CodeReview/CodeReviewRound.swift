import Foundation
import LanguageServerProtocol
import GitHelper

public struct CodeReviewRequest: Equatable, Codable {
    public struct FileChange: Equatable, Codable {
        public let changes: [PRChange]
        public var selectedChanges: [PRChange]
        
        public init(changes: [PRChange]) {
            self.changes = changes
            self.selectedChanges = changes
        }
    }
    
    public var fileChange: FileChange
    
    public var changedFileUris: [DocumentUri] { fileChange.changes.map { $0.uri } }
    public var selectedFileUris: [DocumentUri] { fileChange.selectedChanges.map { $0.uri } }
    
    public init(fileChange: FileChange) {
        self.fileChange = fileChange
    }
    
    public static func from(_ changes: [PRChange]) -> CodeReviewRequest {
        return .init(fileChange: .init(changes: changes))
    }
    
    public mutating func updateSelectedChanges(by fileUris: [DocumentUri]) {
        fileChange.selectedChanges = fileChange.selectedChanges.filter { fileUris.contains($0.uri) }
    }
}

public struct CodeReviewResponse: Equatable, Codable {
    public struct FileComment: Equatable, Codable, Hashable {
        public let uri: DocumentUri
        public let originalContent: String
        public var comments: [ReviewComment]
        
        public var url: URL? { URL(string: uri) }
        
        public init(uri: DocumentUri, originalContent: String, comments: [ReviewComment]) {
            self.uri = uri
            self.originalContent = originalContent
            self.comments = comments
        }
    }
    
    public var fileComments: [FileComment]
    
    public var allComments: [ReviewComment] {
        fileComments.flatMap { $0.comments }
    }
    
    public init(fileComments: [FileComment]) {
        self.fileComments = fileComments
    }
    
    public func merge(with other: CodeReviewResponse) -> CodeReviewResponse {
        var mergedResponse = self
        
        for newFileComment in other.fileComments {
            if let index = mergedResponse.fileComments.firstIndex(where: { $0.uri == newFileComment.uri }) {
                // Merge comments for existing URI
                var mergedComments = mergedResponse.fileComments[index].comments + newFileComment.comments
                mergedComments.sortByEndLine()
                mergedResponse.fileComments[index].comments = mergedComments
            } else {
                // Append new URI with sorted comments
                var newReview = newFileComment
                newReview.comments.sortByEndLine()
                mergedResponse.fileComments.append(newReview)
            }
        }
        
        return mergedResponse
    }
}

public struct CodeReviewRound: Equatable, Codable {
    public enum Status: Equatable, Codable {
        case waitForConfirmation, accepted, running, completed, error, cancelled
        
        public func canTransitionTo(_ newStatus: Status) -> Bool {
            switch (self, newStatus) {
            case (.waitForConfirmation, .accepted): return true
            case (.waitForConfirmation, .cancelled): return true
            case (.accepted, .running): return true
            case (.accepted, .cancelled): return true
            case (.running, .completed): return true
            case (.running, .error): return true
            case (.running, .cancelled): return true
            default: return false
            }
        }
    }
    
    public let id: String
    public let turnId: String
    public var status: Status {
        didSet { statusHistory.append(status) }
    }
    public private(set) var statusHistory: [Status]
    public var request: CodeReviewRequest?
    public var response: CodeReviewResponse?
    public var error: String?
    
    public init(
        id: String = UUID().uuidString,
        turnId: String,
        status: Status,
        request: CodeReviewRequest? = nil,
        response: CodeReviewResponse? = nil,
        error: String? = nil
    ) {
        self.id = id
        self.turnId = turnId
        self.status = status
        self.request = request
        self.response = response
        self.error = error
        self.statusHistory = [status]
    }
    
    public static func fromError(turnId: String, error: String) -> CodeReviewRound {
        .init(turnId: turnId, status: .error, error: error)
    }
    
    public func withResponse(_ response: CodeReviewResponse) -> CodeReviewRound {
        var round = self
        round.response = response
        return round
    }
    
    public func withStatus(_ status: Status) -> CodeReviewRound {
        var round = self
        round.status = status
        return round
    }
    
    public func withError(_ error: String) -> CodeReviewRound {
        var round = self
        round.error = error
        round.status = .error
        return round
    }
}

extension Array where Element == ReviewComment {
    // Order in asc
    public mutating func sortByEndLine() {
        self.sort(by: { $0.range.end.line < $1.range.end.line })
    }
}

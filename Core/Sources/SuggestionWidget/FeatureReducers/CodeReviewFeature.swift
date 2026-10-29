import ChatService
import ComposableArchitecture
import AppKit
import AXHelper
import ConversationServiceProvider
import Foundation
import LanguageServerProtocol
import Logger
import Terminal
import XcodeInspector
import SuggestionBasic
import ConversationTab

@Reducer
public struct CodeReviewPanelFeature {
    @ObservableState
    public struct State: Equatable {
        public fileprivate(set) var documentReviews: DocumentReviewsByUri = [:]
        public var operatedCommentIds: Set<String> = []
        public var currentIndex: Int = 0
        public var activeDocumentURL: URL? = nil
        public var isPanelDisplayed: Bool = false
        public var closedByUser: Bool = false
        
        public var currentDocumentReview: DocumentReview? {
            if let url = activeDocumentURL,
               let result = documentReviews[url.absoluteString]
            {
                return result
            }
            return nil
        }
        
        public var currentSelectedComment: ReviewComment? {
            guard let currentDocumentReview = currentDocumentReview else { return nil }
            guard currentIndex >= 0 && currentIndex < currentDocumentReview.comments.count
            else { return nil }

            return currentDocumentReview.comments[currentIndex]
        }
        
        public var originalContent: String? { currentDocumentReview?.originalContent }
        
        public var documentUris: [DocumentUri] { Array(documentReviews.keys) }
        
        public var pendingNavigation: PendingNavigation? = nil

        public func getCommentById(id: String) -> ReviewComment? {
            // Check current selected comment first for efficiency
            if let currentSelectedComment = currentSelectedComment,
               currentSelectedComment.id == id {
                return currentSelectedComment
            }
            
            // Search through all document reviews
            for documentReview in documentReviews.values {
                for comment in documentReview.comments {
                    if comment.id == id {
                        return comment
                    }
                }
            }
            
            return nil
        }
        
        public func getOriginalContentByUri(_ uri: DocumentUri) -> String? {
            documentReviews[uri]?.originalContent
        }
        
        public var hasNextComment: Bool { hasComment(of: .next) }
        public var hasPreviousComment: Bool { hasComment(of: .previous) }
        
        public init() {}
    }
    
    public struct PendingNavigation: Equatable {
        public let url: URL
        public let index: Int
        
        public init(url: URL, index: Int) {
            self.url = url
            self.index = index
        }
    }
    
    public enum Action: Equatable {
        case next
        case previous
        case close(commentId: String)
        case dismiss(commentId: String)
        case accept(commentId: String)
        
        case onActiveDocumentURLChanged(URL?)
        
        case appear
        case onCodeReviewResultsChanged(DocumentReviewsByUri)
        case observeDocumentReviews
        case observeReviewedFileClicked
        
        case checkDisplay
        case reviewedfileClicked
    }
    
    public init() {}
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .next:
                let nextIndex = state.currentIndex + 1
                if let reviewComments = state.currentDocumentReview?.comments,
                   reviewComments.count > nextIndex {
                    state.currentIndex = nextIndex
                    return .none
                }
                
                if let result = state.getDocumentNavigation(.next) {
                    state.navigateToDocument(uri: result.documentUri, index: result.commentIndex)
                }
                
                return .none
                
            case .previous:
                let previousIndex = state.currentIndex - 1
                if let reviewComments = state.currentDocumentReview?.comments,
                   reviewComments.count > previousIndex && previousIndex >= 0 {
                    state.currentIndex = previousIndex
                    return .none
                }
                
                if let result = state.getDocumentNavigation(.previous) {
                    state.navigateToDocument(uri: result.documentUri, index: result.commentIndex)
                }
                
                return .none
                
            case let .close(id):
                state.isPanelDisplayed = false
                state.closedByUser = true
                
                return .none
                
            case let .dismiss(id):
                state.operatedCommentIds.insert(id)
                return .run { send in 
                    await send(.checkDisplay)
                    await send(.next)
                }
                
            case let .accept(id):
                guard !state.operatedCommentIds.contains(id),
                      let comment = state.getCommentById(id: id),
                      let suggestion = comment.suggestion,
                      let url = URL(string: comment.uri),
                      let currentContent = try? String(contentsOf: url),
                      let originalContent = state.getOriginalContentByUri(comment.uri)
                else { return .none }
                
                let currentLines = currentContent.components(separatedBy: .newlines)
                
                let currentEndLineNumber = CodeReviewLocationStrategy.calculateCurrentLineNumber(
                    for: comment.range.end.line,
                    originalLines: originalContent.components(separatedBy: .newlines),
                    currentLines: currentLines
                )
                
                let range: CursorRange = .init(
                    start: .init(
                        line: currentEndLineNumber - (comment.range.end.line - comment.range.start.line), 
                        character: comment.range.start.character
                    ), 
                    end: .init(line: currentEndLineNumber, character: comment.range.end.character)
                )
                
                ChatInjector.insertSuggestion(
                    suggestion: suggestion, 
                    range: range,
                    lines: currentLines
                )
                
                state.operatedCommentIds.insert(id)
                
                return .none
                
            case let .onActiveDocumentURLChanged(url):
                if url != state.activeDocumentURL {
                    if let pendingNavigation = state.pendingNavigation,
                       pendingNavigation.url == url {
                        state.activeDocumentURL = url
                        state.currentIndex = pendingNavigation.index
                    } else {
                        state.activeDocumentURL = url
                        state.currentIndex = 0
                    }
                }
                return .run { send in await send(.checkDisplay) }
                
            case .appear:
                return .run { send in
                    await send(.observeDocumentReviews)
                    await send(.observeReviewedFileClicked)
                }
                
            case .observeDocumentReviews:
                return .run { send in
                    for await documentReviews in await CodeReviewService.shared.$documentReviews.values {
                        await send(.onCodeReviewResultsChanged(documentReviews))
                    }
                }
                
            case .observeReviewedFileClicked:
                return .run { send in 
                    for await _ in await CodeReviewStateService.shared.fileClickedEvent.values {
                        await send(.reviewedfileClicked)
                    }
                }

            case let .onCodeReviewResultsChanged(newCodeReviewResults):
                state.documentReviews = newCodeReviewResults
                
                return .run { send in await send(.checkDisplay) }
                
            case .checkDisplay:
                guard !state.closedByUser else {
                    state.isPanelDisplayed = false
                    return .none
                }
                
                if let currentDocumentReview = state.currentDocumentReview,
                   currentDocumentReview.comments.count > 0 {
                    state.isPanelDisplayed = true
                } else {
                    state.isPanelDisplayed = false
                }
                
                return .none
                
            case .reviewedfileClicked:
                state.isPanelDisplayed = true
                state.closedByUser = false
                
                return .none
            }
        }
    }
}

enum NavigationDirection {
    case previous, next
}

extension CodeReviewPanelFeature.State {
    func getDocumentNavigation(_ direction: NavigationDirection) -> (documentUri: String, commentIndex: Int)? {
        let documentUris = documentUris
        let documentUrisCount = documentUris.count
        
        guard documentUrisCount > 1,
              let activeDocumentURL = activeDocumentURL,
              let documentIndex = documentUris.firstIndex(where: { $0 == activeDocumentURL.absoluteString })
        else { return nil }
        
        var offSet = 1
        // Iter documentUris to find valid next/previous document and comment
        while offSet < documentUrisCount {
            let targetDocumentIndex: Int = {
                switch direction {
                case .previous: (documentIndex - offSet + documentUrisCount) % documentUrisCount
                case .next: (documentIndex + offSet) % documentUrisCount
                }
            }()
            
            let targetDocumentUri = documentUris[targetDocumentIndex]
            if let targetComments = documentReviews[targetDocumentUri]?.comments,
               !targetComments.isEmpty {
                let targetCommentIndex: Int = {
                    switch direction {
                    case .previous: targetComments.count - 1
                    case .next: 0
                    }
                }()
                
                return (targetDocumentUri, targetCommentIndex)
            }
            
            offSet += 1
        }
        
        return nil
    }
    
    mutating func navigateToDocument(uri: String, index: Int) {
        let url = URL(fileURLWithPath: uri)
        let originalContent = documentReviews[uri]!.originalContent
        let comment = documentReviews[uri]!.comments[index]
        
        openFileInXcode(fileURL: url, originalContent: originalContent, range: comment.range)
        
        pendingNavigation = .init(url: url, index: index)
    }
    
    func hasComment(of direction: NavigationDirection) -> Bool {
        // Has next comment against current document
        switch direction {
        case .next: 
            if currentDocumentReview?.comments.count ?? 0 > currentIndex + 1 {
                return true
            }
        case .previous:
            if currentIndex > 0 {
                return true
            }
        }
        
        // Has next comment against next document
        if getDocumentNavigation(direction) != nil {
            return true
        }
        
        return false
    }
}

private func openFileInXcode(
    fileURL: URL, 
    originalContent: String, 
    range: LSPRange
) {
    NSWorkspace.openFileInXcode(fileURL: fileURL) { app, error in
        guard error == nil else {
            Logger.client.error("Failed to open file in xcode: \(error!.localizedDescription)")
            return
        }
        
        guard let app = app else { return }
        
        let appInstanceInspector = AppInstanceInspector(runningApplication: app)
        guard appInstanceInspector.isXcode,
              let focusedElement = appInstanceInspector.appElement.focusedElement,
              let content = try? String(contentsOf: fileURL)
        else { return }
        
        let currentLineNumber = CodeReviewLocationStrategy.calculateCurrentLineNumber(
            for: range.end.line, 
            originalLines: originalContent.components(separatedBy: .newlines), 
            currentLines: content.components(separatedBy: .newlines)
        )

        
        AXHelper.scrollSourceEditorToLine(
            currentLineNumber, 
            content: content, 
            focusedElement: focusedElement
        )
    }
}

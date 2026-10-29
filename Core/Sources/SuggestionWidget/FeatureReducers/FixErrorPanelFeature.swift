import ComposableArchitecture
import Foundation
import SuggestionBasic
import XcodeInspector
import ChatTab
import ConversationTab

@Reducer
public struct FixErrorPanelFeature {
    @ObservableState
    public struct State: Equatable {
        public var focusedEditor: SourceEditor? = nil
        public var editorContent: EditorInformation.SourceEditorContent? = nil
        public var fixId: String? = nil
        public var fixFailure: FixEditorErrorIssueFailure? = nil
        public var cursorPosition: CursorPosition? {
            editorContent?.cursorPosition
        }
        public var isPanelDisplayed: Bool = false
        public var shouldCheckingAnnotations: Bool = false {
            didSet {
                if shouldCheckingAnnotations {
                    annotationCheckStartTime = Date()
                }
            }
        }
        public var maxCheckDuration: TimeInterval = 30.0
        public var annotationCheckStartTime: Date? = nil
        
        public var editorContentLines: [String] {
            editorContent?.lines ?? []
        }
        
        public var errorAnnotationsAtCursorPosition: [EditorInformation.LineAnnotation] {
            guard let editorContent = editorContent else {
                return []
            }
            
            return getErrorAnnotationsAtCursor(from: editorContent)
        }
        
        public func getErrorAnnotationsAtCursor(from editorContent: EditorInformation.SourceEditorContent) -> [EditorInformation.LineAnnotation] {
            return editorContent.lineAnnotations
                .filter { $0.isError }
                .filter { $0.line == editorContent.cursorPosition.line + 1 }
        }
        
        public mutating func resetFailure() {
            fixFailure = nil
            fixId = nil
        }
    }
    
    public enum Action: Equatable {
        case onFocusedEditorChanged(SourceEditor?)
        case onEditorContentChanged
        case onScrollPositionChanged
        case onCursorPositionChanged
        
        case fixErrorIssue([EditorInformation.LineAnnotation])
        case scheduleFixFailureReset
        case observeErrorNotification
        
        case appear
        case onFailure(FixEditorErrorIssueFailure)
        case checkDisplay
        case resetFixFailure
        
        // Annotation checking
        case startAnnotationCheck
        case onAnnotationCheckTimerFired
        case stopCheckingAnnotation
    }
    
    let id = UUID()
    
    enum CancelID: Hashable {
        case observeErrorNotification(UUID)
        case annotationCheck(UUID)
        case scheduleFixFailureReset(UUID)
    }
    
    public init() {}
    
    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appear:
                return .run { send in 
                    await send(.observeErrorNotification)
                    await send(.startAnnotationCheck)
                }
                
            case .observeErrorNotification:
                return .run { send in 
                    let stream = AsyncStream<Void> { continuation in
                        let observer = NotificationCenter.default.addObserver(
                            forName: .fixEditorErrorIssueError, 
                            object: nil, 
                            queue: .main
                        ) { notification in 
                            guard let error = notification.userInfo?["error"] as? FixEditorErrorIssueFailure
                            else {
                                return
                            }
                            
                            Task {
                                await send(.onFailure(error))
                            }
                        }
                        
                        continuation.onTermination = { _ in
                            NotificationCenter.default.removeObserver(observer)
                        }
                    }
                    
                    for await _ in stream {
                        // Stream continues until cancelled
                    }
                }.cancellable(
                    id: CancelID.observeErrorNotification(id), 
                    cancelInFlight: true
                )
            case .onFocusedEditorChanged(let editor):
                state.focusedEditor = editor
                state.editorContent = nil
                state.shouldCheckingAnnotations = true
                return .none
                
            case .onEditorContentChanged:
                state.shouldCheckingAnnotations = true
                return .none
                
            case .onScrollPositionChanged:
                if state.shouldCheckingAnnotations {
                    state.shouldCheckingAnnotations = false
                }
                if state.editorContent != nil {
                    state.editorContent = nil
                }
                return .none
                
            case .onCursorPositionChanged:
                state.shouldCheckingAnnotations = true
                return .none
                
            case .fixErrorIssue(let annotations):
                guard let fileURL = state.focusedEditor?.realtimeDocumentURL ?? nil,
                      let workspaceURL = state.focusedEditor?.realtimeWorkspaceURL ?? nil
                else {
                    return .none
                }
                
                let fixId = UUID().uuidString
                state.fixId = fixId
                state.fixFailure = nil
                
                let editorErrorIssue: EditorErrorIssue = .init(
                    lineAnnotations: annotations,
                    fileURL: fileURL,
                    workspaceURL: workspaceURL,
                    id: fixId
                )
                
                let userInfo = [
                    "editorErrorIssue": editorErrorIssue
                ]
                
                return .run { _ in 
                    await MainActor.run {
                        suggestionWidgetControllerDependency.onOpenChatClicked()
                         
                        NotificationCenter.default.post(
                            name: .fixEditorErrorIssue,
                            object: nil,
                            userInfo: userInfo
                        )
                    }
                }
                
            case .scheduleFixFailureReset:
                return .run { send in 
                    try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    await send(.resetFixFailure)
                }
                .cancellable(id: CancelID.scheduleFixFailureReset(id), cancelInFlight: true)
                
            case .resetFixFailure:
                state.resetFailure()
                return .cancel(id: CancelID.scheduleFixFailureReset(id))
                
            case .onFailure(let failure):
                guard case let .isReceivingMessage(fixId) = failure,
                      fixId == state.fixId
                else {
                    return .none
                }
                
                state.fixFailure = failure
                
                return .run { send in await send(.scheduleFixFailureReset)}
                
            case .checkDisplay:
                state.isPanelDisplayed = !state.editorContentLines.isEmpty
                    && !state.errorAnnotationsAtCursorPosition.isEmpty
                return .none
                
            // MARK: - Annotation Check
                
            case .startAnnotationCheck:
                return .run { send in 
                    let interval: TimeInterval = 2
                    
                    while !Task.isCancelled {
                        try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                        
                        await send(.onAnnotationCheckTimerFired)
                    }
                }.cancellable(id: CancelID.annotationCheck(id), cancelInFlight: true)
                
            case .onAnnotationCheckTimerFired:
                // Check if max duration exceeded
                if let startTime = state.annotationCheckStartTime,
                   Date().timeIntervalSince(startTime) > state.maxCheckDuration {
                    return .run { send in
                        await send(.stopCheckingAnnotation)
                        await send(.checkDisplay)
                    }
                }
                
                guard state.shouldCheckingAnnotations,
                      let editor = state.focusedEditor
                else {
                    return .run { send in
                        await send(.checkDisplay)
                    }
                }
                
                let newEditorContent = editor.getContent()
                let newErrorAnnotationsAtCursorPosition = state.getErrorAnnotationsAtCursor(from: newEditorContent)
                let errorAnnotationsAtCursorPosition = state.errorAnnotationsAtCursorPosition
                
                if state.editorContent != newEditorContent {
                    state.editorContent = newEditorContent
                }
                
                if Set(errorAnnotationsAtCursorPosition) != Set(newErrorAnnotationsAtCursorPosition) {
                    // Keep checking annotations as Xcode may update them asynchronously after content changes
                    return .merge(
                        .run { send in
                            await send(.checkDisplay)
                        }
                    )
                } else {
                    return .none
                }
                
            case .stopCheckingAnnotation:
                state.shouldCheckingAnnotations = false
                return .none
            }
        }
    }
}

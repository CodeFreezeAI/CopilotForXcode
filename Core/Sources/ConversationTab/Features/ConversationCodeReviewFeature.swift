import ComposableArchitecture
import ChatService
import Foundation
import ConversationServiceProvider
import GitHelper
import LanguageServerProtocol
import Terminal
import Combine

@MainActor
public class CodeReviewStateService: ObservableObject {
    public static let shared = CodeReviewStateService()
    
    public let fileClickedEvent = PassthroughSubject<Void, Never>()
    
    private init() { }
    
    func notifyFileClicked() {
        fileClickedEvent.send()
    }
}

@Reducer
public struct ConversationCodeReviewFeature {
    @ObservableState
    public struct State: Equatable {
     
        public init() { }
    }
    
    public enum Action: Equatable {
        case request(GitDiffGroup)
        case accept(id: String, selectedFiles: [DocumentUri])
        case cancel(id: String)
        
        case onFileClicked(URL, Int)
    }
    
    public let service: ChatService
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in 
            switch action {
            case .request(let group):
                
                return .run { _ in 
                    try await service.requestCodeReview(group)
                }
                
            case let .accept(id, selectedFileUris):
                
                return .run { _ in 
                    await service.acceptCodeReview(id, selectedFileUris: selectedFileUris)
                }
                
            case .cancel(let id):
                
                return .run { _ in 
                    await service.cancelCodeReview(id)
                }
            
            // lineNumber: 0-based
            case .onFileClicked(let fileURL, let lineNumber):
                
                return .run { _ in
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let terminal = Terminal()
                        do {
                            _ = try await terminal.runCommand(
                                "/bin/bash",
                                arguments: [
                                    "-c",
                                    "xed -l \(lineNumber+1) \"\(fileURL.path)\""
                                ],
                                environment: [:]
                            )
                        } catch {
                            print(error)
                        }
                    }
                    
                    Task { @MainActor in 
                        CodeReviewStateService.shared.notifyFileClicked()
                    }
                }
                
            }
        }
    }
}

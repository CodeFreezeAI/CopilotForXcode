import ComposableArchitecture
import ConversationServiceProvider
import LanguageServerProtocol
import SwiftUI
import SharedUIComponents

// MARK: - Main View

struct CodeReviewMainView: View {
    let store: StoreOf<Chat>
    let round: CodeReviewRound 
    @State private var selectedFileUris: [DocumentUri]
    @AppStorage(\.chatFontSize) var chatFontSize
    
    private var changedFileUris: [DocumentUri] { 
        round.request?.changedFileUris ?? []
    }
    
    private var hasChangedFiles: Bool { 
        !changedFileUris.isEmpty 
    }
    
    private var hasFileComments: Bool {
        guard let fileComments = round.response?.fileComments else { return false }
        return !fileComments.isEmpty
    }
    
    static let HelloMessage: String = "Sure, I can help you with that."
    
    public init(store: StoreOf<Chat>, round: CodeReviewRound) {
        self.store = store
        self.round = round
        self.selectedFileUris = round.request?.selectedFileUris ?? []
    }
    
    var helloMessageView: some View {
        Text(Self.HelloMessage)
            .scaledFont(.system(size: chatFontSize))
    }
    
    var shouldShowHelloMessage: Bool { round.statusHistory.contains(.waitForConfirmation) }
    
    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 8) {
                if shouldShowHelloMessage {
                    helloMessageView
                }
                
                if hasChangedFiles {
                    FileSelectionSection(
                        store: store,
                        round: round,
                        changedFileUris: changedFileUris,
                        selectedFileUris: $selectedFileUris
                    )
                }
                
                if hasFileComments {
                    ReviewResultsSection(store: store, round: round)
                }
                
                if round.status == .completed || round.status == .error {
                    ReviewSummarySection(round: round)
                }
            }
        }
    }
}

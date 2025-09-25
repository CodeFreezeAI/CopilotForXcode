import SwiftUI
import ConversationServiceProvider
import SharedUIComponents

struct ReviewSummarySection: View {
    var round: CodeReviewRound
    @AppStorage(\.chatFontSize) var chatFontSize
    
    var body: some View {
        if round.status == .error, let errorMessage = round.error {
            Text(errorMessage)
                .scaledFont(size: chatFontSize)
        } else if round.status == .completed, let request = round.request, let response = round.response {
            CompletedSummary(request: request, response: response)
        } else {
            Text("Oops, failed to review changes.")
                .font(.system(size: chatFontSize))
        }
    }
}

struct CompletedSummary: View {
    var request: CodeReviewRequest
    var response: CodeReviewResponse
    @AppStorage(\.chatFontSize) var chatFontSize
    
    var body: some View {
        let changedFileUris = request.changedFileUris
        let selectedFileUris = request.selectedFileUris
        let allComments = response.allComments
        
        VStack(alignment: .leading, spacing: 8) {
            
            Text("Total comments: \(allComments.count)")
            
            if allComments.count > 0 {
                Text("Review complete! We found \(allComments.count) comment(s) in your selected file(s). Click a file name to see details in the editor.")
            } else {
                Text("Copilot reviewed \(selectedFileUris.count) out of \(changedFileUris.count) changed files, and no comments were found.")
            }
            
        }
        .scaledFont(size: chatFontSize)
    }
}

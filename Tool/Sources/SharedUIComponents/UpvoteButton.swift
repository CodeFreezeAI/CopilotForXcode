import AppKit
import SwiftUI
import ConversationServiceProvider

public struct UpvoteButton: View {
    public var upvote: (ConversationRating) -> Void
    @State var isSelected = false
    
    public init(upvote: @escaping (ConversationRating) -> Void) {
        self.upvote = upvote
    }
    
    public var body: some View {
        Button(action: {
            isSelected = !isSelected
            isSelected ? upvote(.helpful) : upvote(.unrated)
        }) {
            Image(systemName: isSelected ? "hand.thumbsup.fill" : "hand.thumbsup")
                .resizable()
                .scaledToFit()
                .scaledPadding(2)
                .scaledFrame(width: 16, height: 16)
                .foregroundColor(.secondary)
                .help("Helpful")
        }
        .buttonStyle(HoverButtonStyle(padding: 0))
    }
}

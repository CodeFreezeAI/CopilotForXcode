import AppKit
import SwiftUI
import ConversationServiceProvider

public struct DownvoteButton: View {
    public var downvote: (ConversationRating) -> Void
    @State var isSelected = false
    
    public init(downvote: @escaping (ConversationRating) -> Void) {
        self.downvote = downvote
    }
    
    public var body: some View {
        Button(action: {
            isSelected = !isSelected
            isSelected ? downvote(.unhelpful) : downvote(.unrated)
        }) {
            Image(systemName: isSelected ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                .resizable()
                .scaledToFit()
                .scaledPadding(2)
                .scaledFrame(width: 16, height: 16)
                .foregroundColor(.secondary)
                .help("Unhelpful")
        }
        .buttonStyle(HoverButtonStyle(padding: 0))
    }
}

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
                .aspectRatio(contentMode: .fit)
                .scaledFrame(width: 14, height: 14)
                .foregroundColor(.secondary)
                .padding(4)
                .help("Unhelpful")
        }
        .buttonStyle(HoverButtonStyle(padding: 0))
    }
}

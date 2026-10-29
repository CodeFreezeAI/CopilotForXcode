import ConversationServiceProvider
import SwiftUI
import Foundation
import SharedUIComponents

struct ImageReferenceItemView: View {
    let item: ImageReference
    @State private var showPopover = false
    @AppStorage(\.fontScale) var fontScale: Double
    
    private func getImageTitle() -> String {
        switch item.source {
        case .file:
            if let fileUrl = item.fileUrl {
                return fileUrl.lastPathComponent
            } else {
                return "Attached Image"
            }
        case .pasted:
            return "Pasted Image"
        case .screenshot:
            return "Screenshot"
        }
    }
    
    var body: some View {
        // The HStack arranges its child views horizontally with a right-to-left layout direction applied via `.environment(\.layoutDirection, .rightToLeft)`.
        // This ensures the views are displayed in reverse order to match the desired layout for FlowLayout.
        HStack(alignment: .center, spacing: 4) {
            let text = getImageTitle()

            Text(text)
                .lineLimit(1)
                .scaledFont(size: 12)
                .truncationMode(.middle)
                .scaledFrame(maxWidth: 105, alignment: .center)
                .fixedSize(horizontal: true, vertical: false)
            
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .scaledPadding(.vertical, 2)
                .scaledFrame(width: 16, height: 16)
        }
        .foregroundColor(.primary.opacity(0.85))
        .scaledPadding(.horizontal, 4)
        .scaledPadding(.vertical, 1)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .inset(by: 0.5)
                .stroke(Color(nsColor: .quaternaryLabelColor), lineWidth: 1 * fontScale)
        )
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            PopoverImageView(data: item.data)
        }
        .onTapGesture {
            self.showPopover = true
        }
    }
}


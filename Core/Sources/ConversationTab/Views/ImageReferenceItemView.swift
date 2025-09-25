import ConversationServiceProvider
import SwiftUI
import Foundation
import SharedUIComponents

struct ImageReferenceItemView: View {
    let item: ImageReference
    @State private var showPopover = false
    
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
        HStack(alignment: .center, spacing: 4) {
            let image = loadImageFromData(data: item.data).image
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 1.72))
                .overlay(
                    RoundedRectangle(cornerRadius: 1.72)
                        .inset(by: 0.21)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.43)
                )
             
            let text = getImageTitle()
            let font = NSFont.systemFont(ofSize: 12)
            let attributes = [NSAttributedString.Key.font: font]
            let size = (text as NSString).size(withAttributes: attributes)
            let textWidth = min(size.width, 105)

            Text(text)
                .lineLimit(1)
                .scaledFont(size: 12)
                .foregroundColor(.primary.opacity(0.85))
                .truncationMode(.middle)
                .frame(width: textWidth, alignment: .leading)
        }
        .padding(4)
        .background(
            Color(nsColor: .windowBackgroundColor).opacity(0.5)
        )
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .inset(by: 0.5)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            PopoverImageView(data: item.data)
        }
        .onTapGesture {
            self.showPopover = true
        }
    }
}


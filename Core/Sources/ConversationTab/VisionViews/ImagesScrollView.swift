import SwiftUI
import ComposableArchitecture

public struct ImagesScrollView: View {
    let chat: StoreOf<Chat>
    
    public var body: some View {
        let attachedImages = chat.state.attachedImages.reversed()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(attachedImages, id: \.self) { image in
                    HoverableImageView(image: image, chat: chat)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}

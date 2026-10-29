import SwiftUI
import ComposableArchitecture

public struct ImagesScrollView: View {
    let chat: StoreOf<Chat>
    let editorMode: Chat.EditorMode
    
    public var body: some View {
        let attachedImages = chat.state.getChatContext(of: editorMode).attachedImages.reversed()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(attachedImages, id: \.self) { image in
                    HoverableImageView(image: image, chat: chat)
                }
            }
        }
    }
}

import SwiftUI
import ComposableArchitecture
import Persist
import ConversationServiceProvider
import GitHubCopilotService
import SharedUIComponents

public struct HoverableImageView: View {
    @Environment(\.colorScheme) var colorScheme

    let image: ImageReference
    let chat: StoreOf<Chat>
    @State private var isHovered = false
    @State private var hoverTask: Task<Void, Never>?
    @State private var isSelectedModelSupportVision = AppState.shared.isSelectedModelSupportVision() ?? CopilotModelManager.getDefaultChatModel(scope: AppState.shared.modelScope())?.supportVision ?? false
    @State private var showPopover = false
    
    let maxWidth: CGFloat = 330
    let maxHeight: CGFloat = 160
    
    private var visionNotSupportedOverlay: some View {
        Group {
            if !isSelectedModelSupportVision {
                ZStack {
                    Color.clear
                        .background(.regularMaterial)
                        .opacity(0.4)
                        .clipShape(RoundedRectangle(cornerRadius: hoverableImageCornerRadius))
                    
                    VStack(alignment: .center, spacing: 8) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Vision not supported by current model")
                            .font(.system(size: 12, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .foregroundColor(colorScheme == .dark ? .primary : .white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .colorScheme(colorScheme == .dark ? .light : .dark)
            }
        }
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: hoverableImageCornerRadius)
            .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
    }
    
    private var removeButton: some View {
        Button(action: {
            chat.send(.removeSelectedImage(image))
        }) {
            Image(systemName: "xmark")
                .foregroundColor(.primary)
                .scaledFont(.system(size: 13))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: hoverableImageCornerRadius)
                        .fill(Color.contentBackground.opacity(0.72))
                        .shadow(color: .black.opacity(0.3), radius: 1.5, x: 0, y: 0)
                        .shadow(color: .black.opacity(0.25), radius: 50, x: 0, y: 36)
                )
        }
        .buttonStyle(.plain)
        .padding(1)
        .onHover { buttonHovering in
            hoverTask?.cancel()
            if buttonHovering {
                isHovered = true
            }
        }
    }
    
    private var hoverOverlay: some View {
        Group {
            if isHovered {
                VStack {
                    Spacer()
                    HStack {
                        removeButton
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var baseImageView: some View {
        let (image, nsImage) = loadImageFromData(data: image.data)
        let imageSize = nsImage?.size ?? CGSize(width: maxWidth, height: maxHeight)
        let isWideImage = imageSize.height < 160 && imageSize.width >= maxWidth
        
        return image
            .resizable()
            .aspectRatio(contentMode: isWideImage ? .fill : .fit)
            .blur(radius: !isSelectedModelSupportVision ? 2.5 : 0)
            .frame(
                width: isWideImage ? min(imageSize.width, maxWidth) : nil,
                height: isWideImage ? min(imageSize.height, maxHeight) : maxHeight,
                alignment: .leading
            )
            .clipShape(
                RoundedRectangle(cornerRadius: hoverableImageCornerRadius),
                style: .init(eoFill: true, antialiased: true)
            )
    }

    private func handleHover(_ hovering: Bool) {
        hoverTask?.cancel()
        
        if hovering {
            isHovered = true
        } else {
            // Add a small delay before hiding to prevent flashing
            hoverTask = Task {
                try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
                if !Task.isCancelled {
                    isHovered = false
                }
            }
        }
    }
    
    private func updateVisionSupport() {
        isSelectedModelSupportVision = AppState.shared.isSelectedModelSupportVision() ?? CopilotModelManager.getDefaultChatModel(scope: AppState.shared.modelScope())?.supportVision ?? false
    }
    
    public var body: some View {
        if NSImage(data: image.data) != nil {
            baseImageView
                .frame(height: maxHeight, alignment: .leading)
                .background(
                    Color(nsColor: .windowBackgroundColor).opacity(0.5)
                )
                .overlay(visionNotSupportedOverlay)
                .overlay(borderOverlay)
                .onHover(perform: handleHover)
                .overlay(hoverOverlay)
                .onReceive(NotificationCenter.default.publisher(for: .gitHubCopilotSelectedModelDidChange)) { _ in
                    updateVisionSupport()
                }
                .onTapGesture {
                    showPopover.toggle()
                }
                .popover(isPresented: $showPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                    PopoverImageView(data: image.data)
                }
        }
    }
}

public func loadImageFromData(data: Data) -> (image: Image, nsImage: NSImage?) {
    if let nsImage = NSImage(data: data) {
        return (Image(nsImage: nsImage), nsImage)
    } else {
        return (Image(systemName: "photo.trianglebadge.exclamationmark"), nil)
    }
}

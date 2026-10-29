import SwiftUI

extension View {
    public func scaledFrame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        ScaledFrameView(self, width: width, height: height, alignment: alignment)
    }
}

struct ScaledFrameView<Content: View>: View {
    let content: Content
    let width: CGFloat?
    let height: CGFloat?
    let alignment: Alignment
    
    @StateObject private var fontScaleManager = FontScaleManager.shared
    
    var fontScale: Double {
        fontScaleManager.currentScale
    }
    
    var scaledWidth: CGFloat? {
        guard let width else {
            return nil
        }
        return width * fontScale
    }
    
    var scaledHeight: CGFloat? {
        guard let height else {
            return nil
        }
        return height * fontScale
    }
    
    init(_ content: Content, width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) {
        self.content = content
        self.width = width
        self.height = height
        self.alignment = alignment
    }
    
    var body: some View {
        content
            .frame(width: scaledWidth, height: scaledHeight, alignment: alignment)
    }
}

import SwiftUI

extension View {
    public func scaledFrame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        ScaledFrameView(self, width: width, height: height, alignment: alignment)
    }
    
    /// Applies a scaled frame to the target view based on the current font scaling factor.
    /// Use this function only when the target view requires dynamic scaling to adapt to font size changes.
    public func scaledFrame(
        minWidth: CGFloat? = nil,
        idealWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        idealHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        alignment: Alignment = .center
    ) -> some View {
        ScaledConstraintFrameView(
            self,
            minWidth: minWidth,
            idealWidth: idealWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight,
            alignment: alignment
        )
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

struct ScaledConstraintFrameView<Content: View>: View {
    let content: Content
    let minWidth: CGFloat?
    let idealWidth: CGFloat?
    let maxWidth: CGFloat?
    let minHeight: CGFloat?
    let idealHeight: CGFloat?
    let maxHeight: CGFloat?
    let alignment: Alignment
    
    @StateObject private var fontScaleManager = FontScaleManager.shared
    
    var fontScale: Double {
        fontScaleManager.currentScale
    }
    
    private func getScaledValue(_ v: CGFloat?) -> CGFloat? {
        guard let v = v else {
            return nil
        }
        
        return v * fontScale
    }
    
    init(
        _ content: Content,
        minWidth: CGFloat? = nil,
        idealWidth: CGFloat? = nil,
        maxWidth: CGFloat? = nil,
        minHeight: CGFloat? = nil,
        idealHeight: CGFloat? = nil,
        maxHeight: CGFloat? = nil,
        alignment: Alignment = .center
    ) {
        self.content = content
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.maxWidth = maxWidth
        self.minHeight = minHeight
        self.idealHeight = idealHeight
        self.maxHeight = maxHeight
        self.alignment = alignment
    }
    
    var body: some View {
        content
            .frame(
                minWidth: getScaledValue(minWidth),
                idealWidth: getScaledValue(idealWidth),
                maxWidth: getScaledValue(maxWidth),
                minHeight: getScaledValue(minHeight),
                idealHeight: getScaledValue(idealHeight),
                maxHeight: getScaledValue(maxHeight),
                alignment: alignment
            )
    }
}

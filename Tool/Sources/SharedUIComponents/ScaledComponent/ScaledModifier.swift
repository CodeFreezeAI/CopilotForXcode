import SwiftUI

// MARK: - padding
public extension View {
    func scaledPadding(_ length: CGFloat?) -> some View {
        scaledPadding(.all, length)
    }
    
    func scaledPadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        ScaledPaddingView(self, edges: edges, length: length)
    }
}

struct ScaledPaddingView<Content: View>: View {
    let content: Content
    let edges: Edge.Set
    let length: CGFloat?
    
    @StateObject private var fontScaleManager = FontScaleManager.shared
    
    var fontScale: Double {
        fontScaleManager.currentScale
    }
    
    init(_ content: Content, edges: Edge.Set, length: CGFloat? = nil) {
        self.content = content
        self.edges = edges
        self.length = length
    }
    
    var body: some View {
        content
            .padding(edges, length.map { $0 * fontScale })
    }
}


// MARK: - scaleEffect
public extension View {
    func scaledScaleEffect(_ s: CGFloat, anchor: UnitPoint = .center) -> some View {
        ScaledScaleEffectView(self, s, anchor: anchor)
    }
}

struct ScaledScaleEffectView<Content: View>: View {
    let content: Content
    let s: CGFloat
    let anchor: UnitPoint
    
    @StateObject private var fontScaleManager = FontScaleManager.shared
    
    var fontScale: Double {
        fontScaleManager.currentScale
    }
    
    init(_ content: Content, _ s: CGFloat, anchor: UnitPoint = .center) {
        self.content = content
        self.s = s
        self.anchor = anchor
    }
    
    var body: some View {
        content
            .scaleEffect(s * fontScale, anchor: anchor)
    }
}

import SwiftUI
import AppKit

// MARK: built-in fonts
// Refer to https://developer.apple.com/design/human-interface-guidelines/typography#macOS-built-in-text-styles
extension Font {
    
    public var builtinSize: CGFloat {
        let textStyle = nsTextStyle ?? .body
        
        return NSFont.preferredFont(forTextStyle: textStyle).pointSize
    }
    
    // Map SwiftUI Font to NSFont.TextStyle
    private var nsTextStyle: NSFont.TextStyle? {
        switch self {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .body: .body
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: nil
        }
    }
    
    var builtinWeight: Font.Weight {
        switch self {
        case .headline: .bold
        case .caption2: .medium
        default: .regular
        }
    }
}

public extension View {
    func scaledFont(_ font: Font) -> some View {
        ScaledFontView(self, font: font)
    }
    
    func scaledFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        ScaledFontView(self, size: size, weight: weight, design: design)
    }
}


public struct ScaledFontView<Content: View>: View {
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    var fontDesign: Font.Design
    let content: Content
    
    @StateObject private var fontScaleManager = FontScaleManager.shared
    
    var fontScale: Double {
        fontScaleManager.currentScale
    }
    
    init(_ content: Content, font: Font) {
        self.fontSize = font.builtinSize
        self.fontWeight = font.builtinWeight
        self.fontDesign = .default
        self.content = content
    }
    
    public init(_ content: Content, size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) {
        self.fontSize = size
        self.fontWeight = weight
        self.fontDesign = design
        self.content = content
    }
    
    public var body: some View {
        content
            .font(.system(size: fontSize * fontScale, weight: fontWeight, design: fontDesign))            
    }
}

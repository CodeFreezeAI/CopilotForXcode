import SwiftUI

// This is a custom button style that changes its background color when hovered
public struct HoverButtonStyle: ButtonStyle {
    @State private var isHovered: Bool
    private var padding: CGFloat
    private var hoverColor: Color
    
    public init(isHovered: Bool = false, padding: CGFloat = 4, hoverColor: Color = .hoverColor) {
        self.isHovered = isHovered
        self.padding = padding
        self.hoverColor = hoverColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(padding)
            .background(
                configuration.isPressed
                ? Color.gray.opacity(0.2)
                    : isHovered
                        ? hoverColor
                        : Color.clear
            )
            .cornerRadius(4)
            .onHover { hover in
                isHovered = hover
            }
    }
}

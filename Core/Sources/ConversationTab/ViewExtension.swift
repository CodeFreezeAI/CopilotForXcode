import SwiftUI
import ComposableArchitecture

let ITEM_SELECTED_COLOR = Color("ItemSelectedColor")

struct HoverBackgroundModifier: ViewModifier {
    var isHovered: Bool

    func body(content: Content) -> some View {
        content
            .background(isHovered ? ITEM_SELECTED_COLOR : Color.clear)
    }
}

struct HoverRadiusBackgroundModifier: ViewModifier {
    var isHovered: Bool
    var hoverColor: Color?
    var cornerRadius: CGFloat = 0
    var showBorder: Bool = false
    var borderColor: Color = .white.opacity(0.07)
    var borderWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovered ? hoverColor ?? ITEM_SELECTED_COLOR : Color.clear)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                (isHovered && showBorder) ? 
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth) : 
                nil
            )
    }
}

struct HoverForegroundModifier: ViewModifier {
    var isHovered: Bool
    var defaultColor: Color

    func body(content: Content) -> some View {
        content.foregroundColor(isHovered ? Color.white : defaultColor)
    }
}

extension View {
    public func hoverBackground(isHovered: Bool) -> some View {
        self.modifier(HoverBackgroundModifier(isHovered: isHovered))
    }

    public func hoverRadiusBackground(isHovered: Bool, cornerRadius: CGFloat) -> some View {
        self.modifier(HoverRadiusBackgroundModifier(isHovered: isHovered, cornerRadius: cornerRadius))
    }

    public func hoverRadiusBackground(isHovered: Bool, hoverColor: Color?, cornerRadius: CGFloat) -> some View {
        self.modifier(HoverRadiusBackgroundModifier(isHovered: isHovered, hoverColor: hoverColor, cornerRadius: cornerRadius))
    }
    
    public func hoverRadiusBackground(isHovered: Bool, hoverColor: Color?, cornerRadius: CGFloat, showBorder: Bool, borderColor: Color = .white.opacity(0.07)) -> some View {
        self.modifier(
            HoverRadiusBackgroundModifier(
                isHovered: isHovered,
                hoverColor: hoverColor,
                cornerRadius: cornerRadius,
                showBorder: true,
                borderColor: borderColor
            )
        )
    }

    public func hoverForeground(isHovered: Bool, defaultColor: Color) -> some View {
        self.modifier(HoverForegroundModifier(isHovered: isHovered, defaultColor: defaultColor))
    }

    public func hoverPrimaryForeground(isHovered: Bool) -> some View {
        self.hoverForeground(isHovered: isHovered, defaultColor: .primary)
    }

    public func hoverSecondaryForeground(isHovered: Bool) -> some View {
        self.hoverForeground(isHovered: isHovered, defaultColor: .secondary)
    }
    
    // MARK: - Editor Mode
    
    /// Dims the view when in edit mode and provides tap/keyboard exit functionality
    /// - Parameters:
    ///   - chat: The chat store
    ///   - messageId: Optional message ID to determine if this specific message should be dimmed
    ///   - isDimmed: Whether this view should be dimmed (defaults to true when editing affects this view)
    ///   - allowTapToExit: Whether tapping on this view should exit edit mode (defaults to true)
    func dimWithExitEditMode(
        _ chat: StoreOf<Chat>,
        applyTo messageId: String? = nil,
        isDimmed: Bool? = nil,
        allowTapToExit: Bool = true
    ) -> some View {
        let editUserMessageEffectedMessageIds = chat.editUserMessageEffectedMessages.map { $0.id }
        let shouldDim = isDimmed ?? {
            guard chat.editorMode.isEditingUserMessage else { return false }
            guard let messageId else { return true }
            return editUserMessageEffectedMessageIds.contains(messageId)
        }()
        
        let isInEditMode = chat.editorMode.isEditingUserMessage
        let shouldAllowTapExit = allowTapToExit && isInEditMode
        
        return self
            .opacity(shouldDim && isInEditMode ? 0.5 : 1)
            .overlay(
                Group {
                    if shouldAllowTapExit {
                        Color.clear
                            .contentShape(Rectangle()) // Ensure the entire area is tappable
                            .onTapGesture {
                                if shouldAllowTapExit {
                                    chat.send(.setEditorMode(.input))
                                }
                            }
                    }
                }
            )
            .background(
                // Global escape key handler - only add once per view hierarchy
                Group {
                    if isInEditMode {
                        Button("") {
                            chat.send(.setEditorMode(.input))
                        }
                        .keyboardShortcut(.escape, modifiers: [])
                        .opacity(0)
                        .accessibilityHidden(true)
                    }
                }
            )
    }
}

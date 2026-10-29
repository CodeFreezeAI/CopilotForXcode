import SwiftUI

public struct DestructiveButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color.red)
            .padding(.horizontal, 13)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.red.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(configuration.isPressed ? 0.15 : 0))
                    )
            )
    }
}

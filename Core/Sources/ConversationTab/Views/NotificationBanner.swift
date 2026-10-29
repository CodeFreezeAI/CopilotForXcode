import SwiftUI
import SharedUIComponents

public enum BannerStyle { 
    case info
    case warning
    
    var iconName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

struct NotificationBanner<Content: View>: View {
    var style: BannerStyle
    var isDismissable: Bool = false
    var onDismiss: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content
    @AppStorage(\.chatFontSize) var chatFontSize
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: style.iconName)
                    .foregroundColor(style.color)
                
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isDismissable {
                    Button(action: { onDismiss?() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                }
            }
            .scaledFont(size: chatFontSize - 1)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .scaledPadding(.vertical, 10)
        .scaledPadding(.horizontal, 12)
        .background(Color("BannerBackgroundColor"))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("BannerBorderColor"), lineWidth: 1)
        )
    }
}

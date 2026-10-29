import SwiftUI

public enum BannerStyle { 
    case warning
    
    var iconName: String {
        switch self {
        case .warning: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .warning: return .orange
        }
    }
}

struct NotificationBanner<Content: View>: View {
    var style: BannerStyle
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: style.iconName)
                    .font(Font.system(size: 12))
                    .foregroundColor(style.color)
                
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }
}

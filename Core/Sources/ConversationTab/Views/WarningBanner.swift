import AppKit
import GitHubCopilotService
import SharedUIComponents
import SwiftUI

struct WarningBanner: View {
    let message: String
    let severity: String // "warning" or "info"
    let actions: [WarningAction]
    let onDismiss: () -> Void

    @State private var hoveredActionIndex: Int? = nil

    private var bannerStyle: BannerStyle {
        severity == "warning" ? .warning : .info
    }

    var body: some View {
        NotificationBanner(style: bannerStyle, isDismissable: true, onDismiss: onDismiss) {
            VStack(alignment: .leading, spacing: 8) {
                Text(message)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !actions.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                            ActionLink(
                                title: action.title,
                                url: action.url,
                                isHovered: hoveredActionIndex == index
                            ) { isHovered in
                                hoveredActionIndex = isHovered ? index : nil
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ActionLink: View {
    let title: String
    let url: URL
    let isHovered: Bool
    let onHoverChange: (Bool) -> Void

    var body: some View {
        Button(action: {
            NSWorkspace.shared.open(url)
        }) {
            Text(title)
                .underline(isHovered)
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            onHoverChange(isHovered)
            DispatchQueue.main.async {
                if isHovered {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .onDisappear {
            NSCursor.pop()
        }
    }
}

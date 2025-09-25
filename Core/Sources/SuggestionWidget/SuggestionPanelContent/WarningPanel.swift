import SwiftUI
import SharedUIComponents
import XcodeInspector
import ComposableArchitecture

struct WarningPanel: View {
    let message: String
    let url: String?
    let firstLineIndent: Double
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @Environment(CursorPositionTracker.self) var cursorPositionTracker
    @AppStorage(\.clsWarningDismissedUntilRelaunch) var isDismissedUntilRelaunch
    
    var foregroundColor: Color {
        return colorScheme == .light ? .black.opacity(0.85) : .white.opacity(0.85)
    }
    
    var body: some View {
        WithPerceptionTracking {
            if !isDismissedUntilRelaunch {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image("CopilotLogo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundColor(.primary)
                            .scaledFrame(width: 14, height: 14)
                        
                        Text("Monthly completion limit reached.")
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 9)
                    .background(
                        Capsule()
                            .fill(foregroundColor.opacity(0.1))
                            .frame(height: 17)
                    )
                    .fixedSize()
                    
                    HStack(spacing: 8) {
                        if let url = url {
                            Button("Upgrade Now") {
                                NSWorkspace.shared.open(URL(string: url)!)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlAccentColor))
                            .foregroundColor(Color(nsColor: .white))
                            .cornerRadius(6)
                            .font(.system(size: 12))
                            .fixedSize()
                        }
                        
                        Button("Dismiss") {
                            isDismissedUntilRelaunch = true
                            onDismiss()
                        }
                        .buttonStyle(.bordered)
                        .font(.system(size: 12))
                        .keyboardShortcut(.escape, modifiers: [])
                        .fixedSize()
                    }
                }
                .padding(.top, 24)
                .padding(
                    .leading,
                    firstLineIndent + 20 + CGFloat(
                        cursorPositionTracker.cursorPosition.character
                    )
                )
                .background(.clear)
            }
        }
    }
}

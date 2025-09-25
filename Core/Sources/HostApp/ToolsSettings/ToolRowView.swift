import SwiftUI
import ConversationServiceProvider

/// Individual tool row
struct ToolRow: View {
    let toolName: String
    let toolDescription: String?
    let toolStatus: ToolStatus
    let isServerEnabled: Bool
    @Binding var isToolEnabled: Bool
    let onToolToggleChanged: (Bool) -> Void

    var body: some View {
        HStack(alignment: .center) {
            Toggle(isOn: Binding(
                get: { isToolEnabled },
                set: { onToolToggleChanged($0) }
            )) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(toolName).fontWeight(.medium)
                        
                        if let description = toolDescription {
                            Text(description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .help(description)
                        }
                    }

                    Divider().padding(.vertical, 4)
                }
            }
        }
        .padding(.vertical, 0)
        .onChange(of: toolStatus) { isToolEnabled = $0 == .enabled }
        .onChange(of: isServerEnabled) { if !$0 { isToolEnabled = false } }
    }
}

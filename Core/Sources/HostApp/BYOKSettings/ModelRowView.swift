import GitHubCopilotService
import Logger
import SharedUIComponents
import SwiftUI

struct ModelRowView: View {
    var model: BYOKModelInfo
    @ObservedObject var dataManager: BYOKModelManagerObservable
    let isSelected: Bool
    let onSelection: () -> Void
    let onEditRequested: ((BYOKModelInfo) -> Void)? // New callback for edit action
    @State private var isHovered: Bool = false

    // Extract foreground colors to computed properties
    private var primaryForegroundColor: Color {
        isSelected ? Color(nsColor: .white) : .primary
    }

    private var secondaryForegroundColor: Color {
        isSelected ? Color(nsColor: .white) : .secondary
    }

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 4) {
                    Text(model.modelCapabilities?.name ?? model.modelId)
                        .foregroundColor(primaryForegroundColor)

                    Text(model.modelCapabilities?.name != nil ? model.modelId : "")
                        .foregroundColor(secondaryForegroundColor)
                        .font(.callout)

                    if model.isCustomModel {
                        Badge(
                            text: "Custom Model",
                            level: .info,
                            isSelected: isSelected
                        )
                    }
                }

                Group {
                    if let modelCapabilities = model.modelCapabilities,
                       modelCapabilities.toolCalling || modelCapabilities.vision {
                        HStack(spacing: 0) {
                            if modelCapabilities.toolCalling {
                                Text("Tools").help("Support Tool Calling")
                            }
                            if modelCapabilities.vision {
                                Text("・")
                                Text("Vision").help("Support Vision")
                            }
                        }
                    } else {
                        EmptyView()
                    }
                }
                .foregroundColor(secondaryForegroundColor)
            }

            Spacer()

            // Show edit icon for custom model when selected or hovered
            if model.isCustomModel {
                Button(action: {
                    onEditRequested?(model)
                }) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(HoverButtonStyle(
                    hoverColor: isSelected ? .white.opacity(0.1) : .hoverColor
                ))
                .foregroundColor(primaryForegroundColor)
                .opacity((isSelected || isHovered) ? 1.0 : 0.0)
                .padding(.horizontal, 12)
            }

            Toggle(" ", isOn: Binding(
                // Space in toggle label ensures proper checkbox centering alignment
                get: { model.isRegistered },
                set: { newValue in
                    // Only save when user directly toggles the checkbox
                    Task {
                        do {
                            var newModelInfo = model
                            newModelInfo.isRegistered = newValue
                            try await dataManager.saveModel(newModelInfo)
                        } catch {
                            Logger.client.error("Failed to update model: \(error.localizedDescription)")
                        }
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .labelStyle(.iconOnly)
            .padding(.vertical, 4)
        }
        .padding(.leading, 36)
        .padding(.trailing, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(
            isSelected ? Color(nsColor: .controlAccentColor) : Color.clear
        )
        .onTapGesture { onSelection() }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

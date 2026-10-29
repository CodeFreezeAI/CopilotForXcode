import SwiftUI
import GitHubCopilotService

/// Main list view containing all the tools
struct MCPToolsListContainerView: View {
    let mcpServerTools: [MCPServerToolsCollection]
    @Binding var serverToggleStates: [String: Bool]
    let searchKey: String
    let expandedServerNames: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(mcpServerTools, id: \.name) { serverTools in
                MCPServerToolsSection(
                    serverTools: serverTools,
                    isServerEnabled: serverToggleBinding(for: serverTools.name),
                    forceExpand: expandedServerNames.contains(serverTools.name) && !searchKey.isEmpty
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func serverToggleBinding(for serverName: String) -> Binding<Bool> {
        Binding<Bool>(
            get: { serverToggleStates[serverName] ?? true },
            set: { serverToggleStates[serverName] = $0 }
        )
    }
}

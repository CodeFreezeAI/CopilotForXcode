import SwiftUI
import Persist
import GitHubCopilotService
import Client
import Logger

/// Section for a single server's tools
struct MCPServerToolsSection: View {
    let serverTools: MCPServerToolsCollection
    @Binding var isServerEnabled: Bool
    var forceExpand: Bool = false
    @State private var toolEnabledStates: [String: Bool] = [:]
    @State private var isExpanded: Bool = true
    private var originalServerName: String { serverTools.name }

    private var serverToggleLabel: some View {
        HStack(spacing: 8) {
            Text("MCP Server: \(serverTools.name)").fontWeight(.medium)
            if serverTools.status == .error {
                let message = extractErrorMessage(serverTools.error?.description ?? "")
                Badge(text: message, level: .danger, icon: "xmark.circle.fill")
            }
            Spacer()
        }
    }
    
    private var serverToggle: some View {
        Toggle(isOn: Binding(
            get: { isServerEnabled },
            set: { updateAllToolsStatus(enabled: $0) }
        )) {
            serverToggleLabel
        }
        .toggleStyle(.checkbox)
        .padding(.leading, 4)
        .disabled(serverTools.status == .error)
    }
    
    private var divider: some View {
        Divider()
            .padding(.leading, 36)
            .padding(.top, 2)
            .padding(.bottom, 4)
    }
    
    private var toolsList: some View {
        VStack(spacing: 0) {
            divider
            ForEach(serverTools.tools, id: \.name) { tool in
                ToolRow(
                    toolName: tool.name,
                    toolDescription: tool.description,
                    toolStatus: tool._status,
                    isServerEnabled: isServerEnabled,
                    isToolEnabled: toolBindingFor(tool),
                    onToolToggleChanged: { handleToolToggleChange(tool: tool, isEnabled: $0) }
                )
                .padding(.leading, 36)
            }
        }
        .onChange(of: serverTools) { newValue in
            initializeToolStates(server: newValue)
        }
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Conditional view rendering based on error state
            if serverTools.status == .error {
                // No disclosure group for error state
                VStack(spacing: 0) {
                    serverToggle.padding(.leading, 12)
                    divider.padding(.top, 4)
                }
            } else {
                // Regular DisclosureGroup for non-error state
                DisclosureGroup(isExpanded: $isExpanded) {
                    toolsList
                } label: {
                    serverToggle
                }
                .onAppear {
                    initializeToolStates(server: serverTools)
                    if forceExpand {
                        isExpanded = true
                    }
                }
                .onChange(of: forceExpand) { newForceExpand in
                    if newForceExpand {
                        isExpanded = true
                    }
                }

                if !isExpanded {
                    divider
                }
            }
        }
    }

    private func extractErrorMessage(_ description: String) -> String {
        guard let messageRange = description.range(of: "message:"),
            let stackRange = description.range(of: "stack:") else {
            return description
        }
        let start = description.index(messageRange.upperBound, offsetBy: 0)
        let end = description.index(stackRange.lowerBound, offsetBy: 0)
        return description[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func initializeToolStates(server: MCPServerToolsCollection) {
        var disabled = 0
        toolEnabledStates = server.tools.reduce(into: [:]) { result, tool in
            result[tool.name] = tool._status == .enabled
            disabled += result[tool.name]! ? 0 : 1
        }

        let enabled = toolEnabledStates.count - disabled
        Logger.client.info("Server \(server.name) initialized with \(toolEnabledStates.count) tools (\(enabled) enabled, \(disabled) disabled).")

        // Check if all tools are disabled to properly set server state
        if !toolEnabledStates.isEmpty && toolEnabledStates.values.allSatisfy({ !$0 }) {
            DispatchQueue.main.async {
                isServerEnabled = false
            }
        }
    }

    private func toolBindingFor(_ tool: MCPTool) -> Binding<Bool> {
        Binding(
            get: { toolEnabledStates[tool.name] ?? (tool._status == .enabled) },
            set: { toolEnabledStates[tool.name] = $0 }
        )
    }

    private func handleToolToggleChange(tool: MCPTool, isEnabled: Bool) {
        toolEnabledStates[tool.name] = isEnabled
        
        // Update server state based on tool states
        updateServerState()
        
        // Update only this specific tool status
        updateToolStatus(tool: tool, isEnabled: isEnabled)
    }
    
    private func updateServerState() {
        // If any tool is enabled, server should be enabled
        // If all tools are disabled, server should be disabled
        let allToolsDisabled = serverTools.tools.allSatisfy { tool in
            !(toolEnabledStates[tool.name] ?? (tool._status == .enabled))
        }
        
        isServerEnabled = !allToolsDisabled
    }
    
    private func updateToolStatus(tool: MCPTool, isEnabled: Bool) {
        let serverUpdate = UpdateMCPToolsStatusServerCollection(
            name: serverTools.name,
            tools: [UpdatedMCPToolsStatus(name: tool.name, status: isEnabled ? .enabled : .disabled)]
        )

        updateMCPStatus([serverUpdate])
    }
    
    private func updateAllToolsStatus(enabled: Bool) {
        isServerEnabled = enabled
        
        // Get all tools for this server from the original collection
        let allServerTools = CopilotMCPToolManagerObservable.shared.availableMCPServerTools
            .first(where: { $0.name == originalServerName })?.tools ?? serverTools.tools
        
        // Update all tool states - includes both visible and filtered-out tools
        for tool in allServerTools {
            toolEnabledStates[tool.name] = enabled
        }

        // Create status update for all tools
        let serverUpdate = UpdateMCPToolsStatusServerCollection(
            name: serverTools.name,
            tools: allServerTools.map { 
                UpdatedMCPToolsStatus(name: $0.name, status: enabled ? .enabled : .disabled)
            }
        )
        
        updateMCPStatus([serverUpdate])
    }

    private func updateMCPStatus(_ serverUpdates: [UpdateMCPToolsStatusServerCollection]) {
        // Update status in AppState and CopilotMCPToolManager
        AppState.shared.updateMCPToolsStatus(serverUpdates)

        Task {
            do {
                let service = try getService()
                try await service.updateMCPServerToolsStatus(serverUpdates)
            } catch {
                Logger.client.error("Failed to update MCP status: \(error.localizedDescription)")
            }
        }
    }
}

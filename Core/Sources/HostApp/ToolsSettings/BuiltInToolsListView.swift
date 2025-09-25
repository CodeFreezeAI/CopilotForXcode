import Client
import Combine
import ConversationServiceProvider
import GitHubCopilotService
import Logger
import Persist
import SwiftUI

struct BuiltInToolsListView: View {
    @ObservedObject private var builtInToolManager = CopilotBuiltInToolManagerObservable.shared
    @State private var isSearchBarVisible: Bool = false
    @State private var searchText: String = ""
    @State private var toolEnabledStates: [String: Bool] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupBox(label: headerView) {
                contentView
            }
            .groupBoxStyle(CardGroupBoxStyle())
        }
        .onAppear {
            initializeToolStates()
        }
        .onChange(of: builtInToolManager.availableLanguageModelTools) { _ in
            initializeToolStates()
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .center) {
            Text("Built-In Tools").fontWeight(.bold)
            Spacer()
            SearchBar(isVisible: $isSearchBarVisible, text: $searchText)
        }
        .clipped()
    }

    // MARK: - Content View

    private var contentView: some View {
        let filteredTools = filteredLanguageModelTools()

        if filteredTools.isEmpty {
            return AnyView(EmptyStateView())
        } else {
            return AnyView(toolsListView(tools: filteredTools))
        }
    }

    // MARK: - Tools List View

    private func toolsListView(tools: [LanguageModelTool]) -> some View {
        VStack(spacing: 0) {
            ForEach(tools, id: \.name) { tool in
                ToolRow(
                    toolName: tool.displayName ?? tool.name,
                    toolDescription: tool.displayDescription,
                    toolStatus: tool.status,
                    isServerEnabled: true,
                    isToolEnabled: toolBindingFor(tool),
                    onToolToggleChanged: { isEnabled in
                        handleToolToggleChange(tool: tool, isEnabled: isEnabled)
                    }
                )
            }
        }
    }

    // MARK: - Helper Methods
    
    private func initializeToolStates() {
        var map: [String: Bool] = [:]
        for tool in builtInToolManager.availableLanguageModelTools {
            // Preserve existing state if already toggled locally
            if let existing = toolEnabledStates[tool.name] {
                map[tool.name] = existing
            } else {
                map[tool.name] = (tool.status == .enabled)
            }
        }
        toolEnabledStates = map
    }

    private func toolBindingFor(_ tool: LanguageModelTool) -> Binding<Bool> {
        Binding(
            get: { toolEnabledStates[tool.name] ?? (tool.status == .enabled) },
            set: { newValue in
                toolEnabledStates[tool.name] = newValue
            }
        )
    }

    private func filteredLanguageModelTools() -> [LanguageModelTool] {
        let key = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return builtInToolManager.availableLanguageModelTools }

        return builtInToolManager.availableLanguageModelTools.filter { tool in
            tool.name.lowercased().contains(key) ||
                (tool.description?.lowercased().contains(key) ?? false) ||
                (tool.displayName?.lowercased().contains(key) ?? false)
        }
    }

    private func handleToolToggleChange(tool: LanguageModelTool, isEnabled: Bool) {
        // Optimistically update local state already done in binding.
        let toolUpdate = ToolStatusUpdate(name: tool.name, status: isEnabled ? .enabled : .disabled)
        updateToolStatus([toolUpdate])
    }

    private func updateToolStatus(_ toolUpdates: [ToolStatusUpdate]) {
        Task {
            do {
                let service = try getService()
                let updatedTools = try await service.updateToolsStatus(toolUpdates)
                if updatedTools == nil {
                    Logger.client.error("Failed to update built-in tool status: No updated tools returned")
                }
                // CopilotLanguageModelToolManager will broadcast changes; our local
                // toolEnabledStates keep rows visible even if disabled.
            } catch {
                Logger.client.error("Failed to update built-in tool status: \(error.localizedDescription)")
            }
        }
    }
}

/// Empty state view when no tools are available
private struct EmptyStateView: View {
    var body: some View {
        Text("No built-in tools available. Make sure background permissions are granted.")
            .foregroundColor(.secondary)
    }
}

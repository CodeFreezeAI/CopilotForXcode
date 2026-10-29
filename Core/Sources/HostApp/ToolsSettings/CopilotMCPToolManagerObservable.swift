import SwiftUI
import Combine
import Persist
import GitHubCopilotService
import Client
import Logger

class CopilotMCPToolManagerObservable: ObservableObject {
    static let shared = CopilotMCPToolManagerObservable()

    @Published var availableMCPServerTools: [MCPServerToolsCollection] = []
    private var cancellables = Set<AnyCancellable>()

    private init() {
        DistributedNotificationCenter.default()
            .publisher(for: .gitHubCopilotMCPToolsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.refreshMCPServerTools()
                }
            }
            .store(in: &cancellables)

        Task {
            // Initial load of MCP server tools collections from ExtensionService process
            await refreshMCPServerTools()
        }
    }

    @MainActor
    private func refreshMCPServerTools() async {
        do {
            let service = try getService()
            let mcpTools = try await service.getAvailableMCPServerToolsCollections()
            refreshTools(tools: mcpTools)
        } catch {
            Logger.client.error("Failed to fetch MCP server tools: \(error)")
        }
    }

    private func refreshTools(tools: [MCPServerToolsCollection]?) {
        guard let tools = tools else {
            // nil means the tools data is ready, and skip it first.
            return
        }

        AppState.shared.cleanupMCPToolsStatus(availableTools: tools)
        AppState.shared.createMCPToolsStatus(tools)
        self.availableMCPServerTools = tools
    }
}

import Client
import Combine
import ConversationServiceProvider
import Logger
import Persist
import SwiftUI

class CopilotBuiltInToolManagerObservable: ObservableObject {
    static let shared = CopilotBuiltInToolManagerObservable()

    @Published var availableLanguageModelTools: [LanguageModelTool] = []
    private var cancellables = Set<AnyCancellable>()

    private init() {
        DistributedNotificationCenter.default()
            .publisher(for: .gitHubCopilotToolsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.refreshLanguageModelTools()
                }
            }
            .store(in: &cancellables)

        Task {
            await refreshLanguageModelTools()
        }
    }

    @MainActor
    public func refreshLanguageModelTools() async {
        do {
            let service = try getService()
            let languageModelTools = try await service.getAvailableLanguageModelTools()
            
            guard let tools = languageModelTools else { return }

            // Update the published list with all tools (both enabled and disabled)
            availableLanguageModelTools = tools

            // Update AppState for persistence
            let statusUpdates = tools.map {
                ToolStatusUpdate(name: $0.name, status: $0.status)
            }
            AppState.shared.updateLanguageModelToolsStatus(statusUpdates)
        } catch {
            Logger.client.error("Failed to fetch language model tools: \(error)")
        }
    }
}

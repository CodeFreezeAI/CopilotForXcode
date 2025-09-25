import Client
import GitHubCopilotService
import SwiftUI

public struct BYOKConfigView: View {
    @StateObject private var dataManager = BYOKModelManagerObservable()
    @State private var activeSheet: BYOKSheetType?
    @State private var expansionStates: [BYOKProvider: Bool] = [:]

    private let providers: [BYOKProvider] = [
        .Azure,
        .OpenAI,
        .Anthropic,
        .Gemini,
        .Groq,
        .OpenRouter,
    ]

    private var expansionHash: Int {
        expansionStates.values.map { $0 ? 1 : 0 }.reduce(0, +)
    }

    private func expansionBinding(for provider: BYOKProvider) -> Binding<Bool> {
        Binding(
            get: { expansionStates[provider] ?? false },
            set: { expansionStates[provider] = $0 }
        )
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(providers, id: \.self) { provider in
                    BYOKProviderConfigView(
                        provider: provider,
                        dataManager: dataManager,
                        onSheetRequested: presentSheet,
                        isExpanded: expansionBinding(for: provider)
                    )
                }
            }
            .padding(16)
        }
        .animation(.easeInOut(duration: 0.3), value: expansionHash)
        .onAppear {
            Task {
                await dataManager.refreshData()
            }
        }
        .sheet(item: $activeSheet) { sheetType in
            createSheetContent(for: sheetType)
        }
    }

    // MARK: - Sheet Management

    /// Presents the requested sheet type
    private func presentSheet(_ sheetType: BYOKSheetType) {
        activeSheet = sheetType
    }

    /// Creates the appropriate sheet content based on the sheet type
    @ViewBuilder
    private func createSheetContent(for sheetType: BYOKSheetType) -> some View {
        switch sheetType {
        case let .apiKey(provider):
            ApiKeySheet(dataManager: dataManager, provider: provider)
        case let .model(provider, model):
            ModelSheet(dataManager: dataManager, provider: provider, existingModel: model)
        }
    }
}

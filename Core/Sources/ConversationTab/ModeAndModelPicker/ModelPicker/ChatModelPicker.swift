import Persist
import SharedUIComponents
import SwiftUI

struct ChatModelPicker: View {
    let selectedModel: LLMModel?
    let copilotModels: [LLMModel]
    let byokModels: [LLMModel]
    let isBYOKFFEnabled: Bool
    let currentCache: ScopeCache

    @StateObject private var fontScaleManager = FontScaleManager.shared
    @State private var currentEffort: String?

    private var fontScale: Double {
        fontScaleManager.currentScale
    }

    var body: some View {
        ModelPickerButton(
            selectedModel: selectedModel,
            copilotModels: copilotModels,
            byokModels: byokModels,
            isBYOKFFEnabled: isBYOKFFEnabled,
            currentCache: currentCache,
            fontScale: fontScale,
            currentEffort: currentEffort
        )
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            currentEffort = computeEffort(for: selectedModel)
        }
        .onChange(of: selectedModel) { model in
            currentEffort = computeEffort(for: model)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .gitHubCopilotModelsDidChange
            )
        ) { _ in
            currentEffort = computeEffort(for: selectedModel)
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .gitHubCopilotSelectedReasoningEffortDidChange
            )
        ) { _ in
            currentEffort = computeEffort(for: selectedModel)
        }
    }

    private func computeEffort(for model: LLMModel?) -> String? {
        guard let model,
              model.supportsReasoningEffortLevel,
              !model.isAutoModel else { return nil }
        let effort = AppState.shared.effectiveReasoningEffort(for: model)
        guard let e = effort, e.lowercased() != "none" else { return nil }
        return e
    }
}

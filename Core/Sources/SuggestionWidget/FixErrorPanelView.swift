import SwiftUI
import ComposableArchitecture
import SuggestionBasic
import ConversationTab

private typealias FixErrorViewStore = ViewStore<ViewState, FixErrorPanelFeature.Action>

private struct ViewState: Equatable {
    let errorAnnotationsAtCursorPosition: [EditorInformation.LineAnnotation]
    let fixFailure: FixEditorErrorIssueFailure?
    let isPanelDisplayed: Bool
    
    init(state: FixErrorPanelFeature.State) {
        self.errorAnnotationsAtCursorPosition = state.errorAnnotationsAtCursorPosition
        self.fixFailure = state.fixFailure
        self.isPanelDisplayed = state.isPanelDisplayed
    }
}

struct FixErrorPanelView: View {
    let store: StoreOf<FixErrorPanelFeature>
    
    @State private var showFailurePopover = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        WithViewStore(self.store, observe: ViewState.init) { viewStore in 
            WithPerceptionTracking {                

                VStack {
                    buildFixErrorButton(viewStore: viewStore)
                        .popover(isPresented: $showFailurePopover) {
                            if let fixFailure = viewStore.fixFailure {
                                buildFailureView(failure: fixFailure)
                                    .padding(.horizontal, 4)
                            }
                        }
                }
                .onAppear { viewStore.send(.appear) }
                .onChange(of: viewStore.fixFailure) { 
                    showFailurePopover = $0 != nil
                }
                .animation(.easeInOut(duration: 0.2), value: viewStore.isPanelDisplayed)
            }
        }
    }
    
    @ViewBuilder
    private func buildFixErrorButton(viewStore: FixErrorViewStore) -> some View {
        let annotations = viewStore.errorAnnotationsAtCursorPosition
        let rect = annotations.first(where:  { $0.rect != nil })?.rect ?? nil
        let annotationHeight = rect?.height ?? 16
        let iconSize = annotationHeight * 0.7
        
        Group {
            if !annotations.isEmpty {
                ZStack {
                    Button(action: {
                        store.send(.fixErrorIssue(annotations))
                    }) {
                        Image("FixError")
                            .resizable()
                            .scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .padding((annotationHeight - iconSize) / 2)
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color("FixErrorBackgroundColor").opacity(0.8))
                    )
                }
            } else {
                Color.clear
                    .frame(width: 0, height: 0)
            }
        }
    }
    
    @ViewBuilder
    private func buildFailureView(failure: FixEditorErrorIssueFailure) -> some View {
        let message: String = {
            switch failure {
            case .isReceivingMessage: "Copilot is still processing the last message. Please wait…"
            }
        }()
        
        Text(message)
            .font(.system(size: 14))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .cornerRadius(4)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

import Client
import SwiftUI
import Toast

struct GlobalInstructionsView: View {
    var isOpen: Binding<Bool>
    @State var initValue: String = ""
    @AppStorage(\.globalCopilotInstructions) var globalInstructions: String
    @Environment(\.toast) var toast

    init(isOpen: Binding<Bool>) {
        self.isOpen = isOpen
        self.initValue = globalInstructions
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 28)

                HStack {
                    Button(action: {
                        self.isOpen.wrappedValue = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    .buttonStyle(.plain)
                    Text("Global Copilot Instructions")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $globalInstructions)
                    .font(.body)
                
                if globalInstructions.isEmpty {
                    Text("Type your global instructions here...")
                        .foregroundColor(Color(nsColor: .placeholderTextColor))
                        .font(.body)
                        .allowsHitTesting(false)
                        .padding(.horizontal, 6)
                }
            }
            .padding(8)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .focusable(false)
        .frame(width: 300, height: 400)
        .onAppear() {
            self.initValue = globalInstructions
        }
        .onDisappear(){
            self.isOpen.wrappedValue = false
            if globalInstructions != initValue {
                refreshConfiguration()
            }
        }
    }
    
    func refreshConfiguration() {
        NotificationCenter.default.post(
            name: .gitHubCopilotShouldRefreshEditorInformation,
            object: nil
        )
        Task {
            do {
                let service = try getService()
                // Notify extension service process to refresh all its CLS subprocesses to apply new configuration
                try await service.postNotification(
                    name: Notification.Name
                        .gitHubCopilotShouldRefreshEditorInformation.rawValue
                )
            } catch {
                toast(error.localizedDescription, .error)
            }
        }
    }
}

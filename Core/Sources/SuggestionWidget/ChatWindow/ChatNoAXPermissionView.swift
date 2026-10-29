import SwiftUI
import Perception
import SharedUIComponents

struct ChatNoAXPermissionView: View {
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 20) {
                    Spacer()
                    Image("CopilotError")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFill()
                        .frame(width: 64.0, height: 64.0)
                        .foregroundColor(.primary)
                    
                    Text("Accessibility Permission Required")
                        .scaledFont(.largeTitle)
                        .multilineTextAlignment(.center)
                    
                    Text("Please grant accessibility permission for Github Copilot to work with Xcode.")
                        .scaledFont(.body)
                        .multilineTextAlignment(.center)
                    
                    HStack{
                        Button("Open Permission Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                openURL(url)
                            }
                        }
                        .scaledFont(.body)
                        .buttonStyle(.borderedProminent)
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }
            .xcodeStyleFrame(cornerRadius: 10)
            .ignoresSafeArea(edges: .top)
        }
    }
}

struct ChatNoAXPermission_Previews: PreviewProvider {
    static var previews: some View {
        ChatNoAXPermissionView()
    }
}

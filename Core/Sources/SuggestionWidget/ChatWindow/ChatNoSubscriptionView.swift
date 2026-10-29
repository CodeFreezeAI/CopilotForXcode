import SwiftUI
import Perception
import GitHubCopilotViewModel
import SharedUIComponents

struct ChatNoSubscriptionView: View {
    @StateObject var viewModel: GitHubCopilotViewModel
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                VStack(alignment: .center, spacing: 20) {
                    Spacer()
                    Image("CopilotIssue")
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFill()
                        .scaledFrame(width: 60.0, height: 60.0)
                        .foregroundColor(.primary)
                    
                    Text("No Copilot Subscription Found")
                        .scaledFont(.system(size: 24))
                        .multilineTextAlignment(.center)
                    
                    Text("Request a license from your organization manager \nor start a 30-day [free trial](https://github.com/github-copilot/signup/copilot_individual) to explore Copilot")
                        .scaledFont(.system(size: 12))
                        .multilineTextAlignment(.center)
                    
                    HStack{
                        Button("Check Subscription Plans") {
                            if let url = URL(string: "https://github.com/settings/copilot") {
                                openURL(url)
                            }
                        }
                        .scaledFont(.body)
                        .buttonStyle(.borderedProminent)
                        
                        Button("Retry") { viewModel.checkStatus() }
                            .scaledFont(.body)
                            .buttonStyle(.bordered)
                        
                        if viewModel.isRunningAction || viewModel.waitingForSignIn {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    
                    Spacer()
                    
                    Text("Copilot Free and Copilot Pro may show [public code](https://aka.ms/github-copilot-match-public-code) suggestions and collect telemetry. You can change these [GitHub settings](https://aka.ms/github-copilot-settings) at any time. By continuing, you agree to our [terms](https://github.com/customer-terms/github-copilot-product-specific-terms) and [privacy policy](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).")
                        .scaledFont(.system(size: 12))
                }
                .padding()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }
            .xcodeStyleFrame()
            .ignoresSafeArea(edges: .top)
        }
    }
}

struct ChatNoSubcription_Previews: PreviewProvider {
    static var previews: some View {
        ChatNoSubscriptionView(viewModel: GitHubCopilotViewModel.shared)
    }
}

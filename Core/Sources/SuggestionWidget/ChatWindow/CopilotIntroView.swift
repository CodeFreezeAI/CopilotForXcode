import SwiftUI
import Perception
import SharedUIComponents

struct CopilotIntroView: View {
    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .center, spacing: 8) {
                CopilotIntroItemView(
                    imageName: "CopilotLogo",
                    title: "Agent Mode",
                    description: "Activate Agent Mode to handle multi-step coding tasks with Copilot."
                )
                
                CopilotIntroItemView(
                    systemImage: "wrench.and.screwdriver",
                    title: "MCP Support",
                    description: "Connect to MCP to extend your Copilot with custom tools and services for advanced workflows."
                )
                
                CopilotIntroItemView(
                    imageName: "ChatIcon",
                    title: "Ask Mode",
                    description: "Use Ask Mode to chat with Copilot to understand, debug, or improve your code."
                )
                
                CopilotIntroItemView(
                    systemImage: "option",
                    title: "Code Suggestions",
                    description: "Get smart code suggestions in Xcode. Press Tab ⇥ to accept a code suggestion, or Option ⌥ to see more alternatives."
                )
            }
            .padding(0)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

struct CopilotIntroItemView: View {
    let image: Image
    let title: String
    let description: String

    public init(imageName: String, title: String, description: String) {
        self.init(
            imageObject: Image(imageName),
            title: title,
            description: description
        )
    }

    public init(systemImage: String, title: String, description: String) {
        self.init(
            imageObject: Image(systemName: systemImage),
            title: title,
            description: description
        )
    }

    public init(imageObject: Image, title: String, description: String) {
        self.image = imageObject
        self.title = title
        self.description = description
    }
    
    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 0){
                HStack(alignment: .center, spacing: 8) {
                    image
                        .resizable()
                        .renderingMode(.template)
                        .scaledToFill()
                        .frame(width: 12, height: 12)
                        .foregroundColor(.primary)
                        .padding(.leading, 8)
                        
                    Text(title)
                        .kerning(0.096)
                        .scaledFont(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                    
                Text(description)
                    .scaledFont(.body)
                    .foregroundColor(.secondary)
                    .padding(.leading, 28)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(8)
            .frame(maxWidth: 360, alignment: .top)
            .background(.primary.opacity(0.1))
            .cornerRadius(2)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .inset(by: 0.5)
                    .stroke(lineWidth: 0)
            )
        }
    }
}

struct CopilotIntroView_Previews: PreviewProvider {
    static var previews: some View {
        CopilotIntroView()
    }
}

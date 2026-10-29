import ComposableArchitecture
import SwiftUI

public struct Instruction: View {
    @Binding var isAgentMode: Bool
    
    public init(isAgentMode: Binding<Bool>) {
        self._isAgentMode = isAgentMode
    }
    
    public var body: some View {
        WithPerceptionTracking {
            VStack {
                VStack(spacing: 24) {
                    
                    VStack(spacing: 16) {
                        Image("CopilotLogo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFill()
                            .scaledFrame(width: 60.0, height: 60.0)
                            .foregroundColor(.secondary)
                        
                        if isAgentMode {
                            Text("Copilot Agent Mode")
                                .scaledFont(.title)
                                .foregroundColor(.primary)
                            
                            Text("Ask Copilot to edit your files in agent mode.\nIt will automatically use multiple requests to \nedit files, run terminal commands, and fix errors.")
                                .scaledFont(size: 14, weight: .light)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        
                        Text("Copilot is powered by AI, so mistakes are possible. Review output carefully before use.")
                            .scaledFont(size: 14, weight: .light)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if isAgentMode {
                            Label("to configure MCP server", systemImage: "wrench.and.screwdriver")
                                .foregroundColor(Color("DescriptionForegroundColor"))
                                .scaledFont(.system(size: 14))
                        }
                        Label("to reference context", systemImage: "paperclip")
                            .foregroundColor(Color("DescriptionForegroundColor"))
                            .scaledFont(.system(size: 14))
                        if !isAgentMode {
                            Text("@ to chat with extensions")
                                .foregroundColor(Color("DescriptionForegroundColor"))
                                .scaledFont(.system(size: 14))
                            Text("Type / to use commands")
                                .foregroundColor(Color("DescriptionForegroundColor"))
                                .scaledFont(.system(size: 14))
                        }
                    }
                }
            }.frame(maxWidth: 350)
        }
    }
}


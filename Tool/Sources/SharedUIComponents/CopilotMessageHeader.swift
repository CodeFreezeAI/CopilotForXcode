import SwiftUI

public struct CopilotMessageHeader: View {
    let spacing: CGFloat
    
    public init(spacing: CGFloat = 4) {
        self.spacing = spacing
    }
    
    public var body: some View {
        HStack(spacing: spacing) {
            ZStack {
                Circle()
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    .scaledFrame(width: 24, height: 24)
                
                Image("CopilotLogo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .scaledFrame(width: 14, height: 14)
            }
            
            Text("GitHub Copilot")
                .scaledFont(size: 13, weight: .semibold)
                .padding(.leading, 4)
                
            Spacer()
        }
    }
}

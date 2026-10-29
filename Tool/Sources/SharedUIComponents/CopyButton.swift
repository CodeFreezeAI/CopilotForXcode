import AppKit
import SwiftUI

public struct CopyButton: View {
    public var copy: () -> Void
    @State var isCopied = false
    private var foregroundColor: Color?
    private var fontWeight: Font.Weight? 
    
    public init(copy: @escaping () -> Void, foregroundColor: Color? = nil, fontWeight: Font.Weight? = nil) { 
        self.copy = copy
        self.foregroundColor = foregroundColor
        self.fontWeight = fontWeight 
    }
    
    public var body: some View {
        Button(action: {
            withAnimation(.linear(duration: 0.1)) {
                isCopied = true
            }
            copy()
            Task {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                withAnimation(.linear(duration: 0.1)) {
                    isCopied = false
                }
            }
        }) {
            Image(systemName: isCopied ? "checkmark.circle" : "doc.on.doc")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaledFrame(width: 14, height: 14)
                .foregroundColor(foregroundColor ?? .secondary)
                .conditionalFontWeight(fontWeight)
                .padding(4)
        }
        .buttonStyle(HoverButtonStyle(padding: 0))
        .help("Copy")
    }
}

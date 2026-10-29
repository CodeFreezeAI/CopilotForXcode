import SwiftUI

public struct InsertButton: View {
    public var insert: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    private var icon: Image {
        return Image("CodeBlockInsertIcon")
    }
    
    public init(insert: @escaping () -> Void) {
        self.insert = insert
    }
    
    public var body: some View {
        Button(action: {
            insert()
        }) {
            self.icon
                .resizable()
                .scaledToFit()
                .scaledPadding(2)
                .scaledFrame(width: 16, height: 16)
                .foregroundColor(.secondary)
        }
        .buttonStyle(HoverButtonStyle(padding: 0))
        .help("Insert at Cursor")
    }
}

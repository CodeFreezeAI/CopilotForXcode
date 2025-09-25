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
                .aspectRatio(contentMode: .fit)
                .scaledFrame(width: 14, height: 14)
                .foregroundColor(.secondary)
                .padding(4)
        }
        .buttonStyle(HoverButtonStyle(padding: 0))
        .help("Insert at Cursor")
    }
}

import SwiftUI
import WebKit
import ComposableArchitecture
import Logger
import ConversationServiceProvider
import ChatService
import ChatTab
import ChatAPIService

extension FileEdit {
    var originalContentByStatus: String {
        return status == .kept ? modifiedContent : originalContent
    }
    
    var modifiedContentByStatus: String {
        return status == .undone ? originalContent : modifiedContent
    }
}

struct DiffView: View {
    @Perception.Bindable var chat: StoreOf<Chat>
    @State public var fileEdit: FileEdit
    
    var body: some View {
        WithPerceptionTracking {
            DiffWebView(
                chat: chat,
                fileEdit: fileEdit
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .edgesIgnoringSafeArea(.all)
        }
    }
}

// preview
struct DiffView_Previews: PreviewProvider {
    static var oldText = """
    import Foundation
    
    func calculateTotal(items: [Double]) -> Double {
        var sum = 0.0
        for item in items {
            sum += item
        }
        return sum
    }
    
    func main() {
        let prices = [10.5, 20.0, 15.75]
        let total = calculateTotal(items: prices)
        print("Total: \\(total)")
    }
    
    main()
    """
    
    static var newText = """
    import Foundation
    
    func calculateTotal(items: [Double], applyDiscount: Bool = false) -> Double {
        var sum = 0.0
        for item in items {
            sum += item
        }
        
        // Apply 10% discount if requested
        if applyDiscount {
            sum *= 0.9
        }
        
        return sum
    }
    
    func main() {
        let prices = [10.5, 20.0, 15.75, 5.0]
        let total = calculateTotal(items: prices)
        let discountedTotal = calculateTotal(items: prices, applyDiscount: true)
        
        print("Total: \\(total)")
        print("With discount: \\(discountedTotal)")
    }
    
    main()
    """
    static let chatTabInfo = ChatTabInfo(id: "", workspacePath: "path", username: "name")
    static var previews: some View {
        DiffView(
            chat: .init(
                initialState: .init(history: ChatPanel_Preview.history, isReceivingMessage: true),
                reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }
            ),
            fileEdit: .init(fileURL: URL(fileURLWithPath: "file:///f1.swift"), originalContent: "test", modifiedContent: "abc", toolName: ToolName.insertEditIntoFile)
        )
            .frame(width: 800, height: 600)
    }
}

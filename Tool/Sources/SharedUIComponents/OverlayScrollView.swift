import SwiftUI
import AppKit

public struct OverlayScrollView<Content: View>: NSViewRepresentable {
    let showsVerticalScroller: Bool
    let showsHorizontalScroller: Bool
    let content: Content
    
    public init(showsVerticalScroller: Bool = true,
         showsHorizontalScroller: Bool = false,
         @ViewBuilder content: () -> Content) {
        self.showsVerticalScroller = showsVerticalScroller
        self.showsHorizontalScroller = showsHorizontalScroller
        self.content = content()
    }
    
    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = showsVerticalScroller
        scrollView.hasHorizontalScroller = showsHorizontalScroller
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .automatic
        
        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.documentView = hosting
        
        if let docView = scrollView.contentView.documentView {
            docView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor).isActive = true
            docView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor).isActive = true
            docView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor).isActive = true
        }
        return scrollView
    }
    
    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let hosting = nsView.documentView as? NSHostingView<Content> {
            hosting.rootView = content
        }
    }
}

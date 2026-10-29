import SwiftUI
import ChatService
import ComposableArchitecture
import WebKit

enum Style {
    /// default diff view frame. Same as the `ChatPanel`
    static let diffViewHeight: Double = 560
    static let diffViewWidth: Double = 504
}

class DiffViewWindowController: NSObject, NSWindowDelegate {
    enum DiffViewerState {
        case shown, closed
    }
    
    private var diffWindow: NSWindow?
    private var hostingView: NSHostingView<DiffView>?
    private weak var chat: StoreOf<Chat>?
    public private(set) var currentFileEdit: FileEdit? = nil
    public private(set) var diffViewerState: DiffViewerState = .closed

    public init(chat: StoreOf<Chat>) {
        self.chat = chat
    }
    
    deinit {
        // Break the delegate cycle
        diffWindow?.delegate = nil
        
        // Close and release the wi
        diffWindow?.close()
        diffWindow = nil
        
        // Clear hosting view
        hostingView = nil
        
        // Reset state
        currentFileEdit = nil
        diffViewerState = .closed
    }

    @MainActor
    func showDiffWindow(fileEdit: FileEdit) {
        guard let chat else { return }
        
        currentFileEdit = fileEdit
        // Create diff view
        let newDiffView = DiffView(chat: chat, fileEdit: fileEdit)
        
        if let window = diffWindow, let _ = hostingView {
            window.title = "Diff View"
            
            let newHostingView = NSHostingView(rootView: newDiffView)
            // Ensure the hosting view fills the window
            newHostingView.translatesAutoresizingMaskIntoConstraints = false
            
            self.hostingView = newHostingView
            window.contentView = newHostingView
            
            // Set constraints to fill the window
            if let contentView = window.contentView {
                newHostingView.frame = contentView.bounds
                newHostingView.autoresizingMask = [.width, .height]
            }
            
            window.makeKeyAndOrderFront(nil)
        } else {
            let newHostingView = NSHostingView(rootView: newDiffView)
            newHostingView.translatesAutoresizingMaskIntoConstraints = false
            self.hostingView = newHostingView
            
            let window = NSWindow(
                contentRect: getDiffViewFrame(),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "Diff View"
            window.contentView = newHostingView
            
            // Set constraints to fill the window
            if let contentView = window.contentView {
                newHostingView.frame = contentView.bounds
                newHostingView.autoresizingMask = [.width, .height]
            }
            
            window.center()
            window.delegate = self
            window.isReleasedWhenClosed = false
            
            self.diffWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        diffWindow?.makeKeyAndOrderFront(nil)
        
        diffViewerState = .shown
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == diffWindow {
            DispatchQueue.main.async {
                self.diffWindow?.orderOut(nil)
            }
        }
    }
    
    @MainActor
    func hideWindow() {
        guard diffViewerState != .closed else { return }
        diffWindow?.orderOut(nil)
        diffViewerState = .closed
    }
    
    func getDiffViewFrame() -> NSRect {
        guard let mainScreen = NSScreen.screens.first(where: { $0.frame.origin == .zero })
        else {
            /// default value
            return .init(x: 0, y:0, width: Style.diffViewWidth, height: Style.diffViewHeight)
        }
        
        let visibleScreenFrame = mainScreen.visibleFrame
        // avoid too wide
        let width = min(Style.diffViewWidth, visibleScreenFrame.width * 0.3)
        let height = visibleScreenFrame.height
                
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
    
    func windowDidResize(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == diffWindow {
            if let hostingView = self.hostingView,
               let webView = findWebView(in: hostingView) {
                let script = """
                if (window.DiffViewer && window.DiffViewer.handleResize) {
                    window.DiffViewer.handleResize();
                }
                """
                webView.evaluateJavaScript(script)
            }
        }
    }
    
    private func findWebView(in view: NSView) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }
        
        for subview in view.subviews {
            if let webView = findWebView(in: subview) {
                return webView
            }
        }
        
        return nil
    }
}

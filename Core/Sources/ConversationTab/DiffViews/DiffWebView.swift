import ComposableArchitecture
import ChatService
import SwiftUI
import WebKit
import Logger
import ChatAPIService

struct DiffWebView: NSViewRepresentable {
    @Perception.Bindable var chat: StoreOf<Chat>
    var fileEdit: FileEdit
    
    init(chat: StoreOf<Chat>, fileEdit: FileEdit) {
        self.chat = chat
        self.fileEdit = fileEdit
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        #if DEBUG
        let scriptSource = """
        function captureLog(msg) { window.webkit.messageHandlers.logging.postMessage(Array.prototype.slice.call(arguments)); }
        console.log = captureLog;
        console.error = captureLog;
        console.warn = captureLog;
        console.info = captureLog;
        """
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        userContentController.addUserScript(script)
        userContentController.add(context.coordinator, name: "logging")
        #endif
        
        userContentController.add(context.coordinator, name: "swiftHandler")
        configuration.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        #if DEBUG
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        #endif
        
        // Configure WebView
        webView.wantsLayer = true
        webView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        webView.layer?.borderWidth = 1
        
        // Make the webview auto-resize with its container
        webView.autoresizingMask = [.width, .height]
        webView.translatesAutoresizingMaskIntoConstraints = true
        
        // Notify the webview of resize events explicitly
        let resizeNotificationScript = WKUserScript(
            source: """
            window.addEventListener('resize', function() {
                if (window.DiffViewer && window.DiffViewer.handleResize) {
                    window.DiffViewer.handleResize();
                }
            });
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(resizeNotificationScript)
        
        /// Load web asset resources
        let bundleBaseURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/webViewDist/diffView")
        let htmlFileURL = bundleBaseURL.appendingPathComponent("diffView.html")
        webView.loadFileURL(htmlFileURL, allowingReadAccessTo: bundleBaseURL)
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.shouldUpdate(fileEdit) {
            // Update content via JavaScript API
            let script = """
            if (typeof window.DiffViewer !== 'undefined') {
                window.DiffViewer.update(
                    `\(escapeJSString(fileEdit.originalContentByStatus))`,
                    `\(escapeJSString(fileEdit.modifiedContentByStatus))`,
                    `\(escapeJSString(fileEdit.fileURL.absoluteString))`,
                    `\(fileEdit.status.rawValue)`
                );
            } else {
                console.error("DiffViewer is not defined in update");
            }
            """
            webView.evaluateJavaScript(script)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: DiffWebView
        private var fileEdit: FileEdit
        
        init(_ parent: DiffWebView) {
            self.parent = parent
            self.fileEdit = parent.fileEdit
        }
        
        func shouldUpdate(_ fileEdit: FileEdit) -> Bool {
            let shouldUpdate = self.fileEdit != fileEdit
                              
            if shouldUpdate {
                self.fileEdit = fileEdit
            }
            
            return shouldUpdate
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            #if DEBUG
            if message.name == "logging" {
                if let logs = message.body as? [Any] {
                    let logString = logs.map { "\($0)" }.joined(separator: " ")
                    Logger.client.info("WebView console: \(logString)")
                }
                return
            }
            #endif
            
            guard message.name == "swiftHandler",
                  let body = message.body as? [String: Any],
                  let event = body["event"] as? String,
                  let data = body["data"] as? [String: String],
                  let filePath = data["filePath"],
                  let fileURL = URL(string: filePath)
            else { return }
            
            switch event {
            case "undoButtonClicked":
                self.parent.chat.send(.undoEdits(fileURLs: [fileURL]))
            case "keepButtonClicked":
                self.parent.chat.send(.keepEdits(fileURLs: [fileURL]))
            default:
                break
            }
        }
        
        // Initialize content when the page has finished loading
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let script = """
            if (typeof window.DiffViewer !== 'undefined') {
                window.DiffViewer.init(
                    `\(escapeJSString(fileEdit.originalContentByStatus))`,
                    `\(escapeJSString(fileEdit.modifiedContentByStatus))`,
                    `\(escapeJSString(fileEdit.fileURL.absoluteString))`,
                    `\(fileEdit.status.rawValue)`
                );
            } else {
                console.error("DiffViewer is not defined on page load");
            }
            """
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    Logger.client.error("Error evaluating JavaScript: \(error)")
                }
            }
        }
        
        // Handle navigation errors
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
           Logger.client.error("WebView navigation failed: \(error)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
           Logger.client.error("WebView provisional navigation failed: \(error)")
        }
    }
}

func escapeJSString(_ string: String) -> String {
    return string
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "`", with: "\\`")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\r", with: "\\r")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "$", with: "\\$")
}

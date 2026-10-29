import WebKit
import Logger
import Preferences

public class WebContentFetcher: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var loadingTimer: Timer?
    private static let converter = HTMLToMarkdownConverter()
    private var completion: ((Result<String, Error>) -> Void)?
    
    private struct Config {
        static let timeout: TimeInterval = 30.0
        static let contentLoadDelay: TimeInterval = 2.0
    }
    
    public enum WebContentError: Error, LocalizedError {
        case invalidURL(String)
        case timeout
        case noContent
        case navigationFailed(Error)
        case javascriptError(Error)
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL(let url): "Invalid URL: \(url)"
            case .timeout: "Request timed out"
            case .noContent: "No content found"
            case .navigationFailed(let error): "Navigation failed: \(error.localizedDescription)"
            case .javascriptError(let error): "JavaScript execution error: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Initialization
    public override init() {
        super.init()
        setupWebView()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    public func fetchContent(from urlString: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            completion(.failure(WebContentError.invalidURL(urlString)))
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.completion = completion
            self?.setupTimeout()
            self?.loadContent(from: url)
        }
    }
    
    public static func fetchContentAsync(from urlString: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let fetcher = WebContentFetcher()
            fetcher.fetchContent(from: urlString) { result in
                withExtendedLifetime(fetcher) {
                    continuation.resume(with: result)
                }
            }
        }
    }

    public static func fetchMultipleContentAsync(from urls: [String]) async -> [String] {
        var results: [String] = []
        
        for url in urls {
            do {
                let content = try await fetchContentAsync(from: url)
                results.append("Successfully fetched content from \(url): \(content)")
            } catch {
                Logger.client.error("Failed to fetch content from \(url): \(error.localizedDescription)")
                results.append("Failed to fetch content from \(url) with error: \(error.localizedDescription)")
            }
        }
        
        return results
    }
    
    // MARK: - Private Methods
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        let dataSource = WKWebsiteDataStore.nonPersistent()

        if #available(macOS 14.0, *) {
            configureProxy(for: dataSource)
        }
        
        configuration.websiteDataStore = dataSource
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView?.navigationDelegate = self
    }
    
    @available(macOS 14.0, *)
    private func configureProxy(for dataSource: WKWebsiteDataStore) {
        let proxyURL = UserDefaults.shared.value(for: \.gitHubCopilotProxyUrl)
        guard let url = URL(string: proxyURL),
              let host = url.host,
              let port = url.port,
              let proxyPort = NWEndpoint.Port(port.description) else { return }
        
        let tlsOptions = NWProtocolTLS.Options()
        let useStrictSSL = UserDefaults.shared.value(for: \.gitHubCopilotUseStrictSSL)
        
        if !useStrictSSL {
            let secOptions = tlsOptions.securityProtocolOptions
            sec_protocol_options_set_verify_block(secOptions, { _, _, completion in
                completion(true)
            }, .main)
        }
        
        let httpProxy = ProxyConfiguration(
            httpCONNECTProxy: NWEndpoint.hostPort(
                host: NWEndpoint.Host(host),
                port: proxyPort
            ),
            tlsOptions: tlsOptions
        )
        
        httpProxy.applyCredential(
            username: UserDefaults.shared.value(for: \.gitHubCopilotProxyUsername),
            password: UserDefaults.shared.value(for: \.gitHubCopilotProxyPassword)
        )
        
        dataSource.proxyConfigurations = [httpProxy]
    }
    
    private func cleanup() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        webView?.navigationDelegate = nil
        webView?.stopLoading()
        webView = nil
    }
    
    private func setupTimeout() {
        loadingTimer?.invalidate()
        loadingTimer = Timer.scheduledTimer(withTimeInterval: Config.timeout, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                Logger.client.error("Request timed out")
                self?.completeWithError(WebContentError.timeout)
            }
        }
    }
    
    private func loadContent(from url: URL) {
        if webView == nil {
            setupWebView()
        }
        
        guard let webView = webView else {
            completeWithError(WebContentError.navigationFailed(NSError(domain: "WebView creation failed", code: -1)))
            return
        }

        let request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: Config.timeout
        )
        webView.load(request)
    }
    
    private func processHTML(_ html: String) {
        do {
            let cleanedText = try Self.converter.convertToMarkdown(from: html)
            completeWithSuccess(cleanedText)
        } catch {
            Logger.client.error("SwiftSoup parsing error: \(error.localizedDescription)")
            completeWithError(error)
        }
    }
    
    private func completeWithSuccess(_ content: String) {
        completion?(.success(content))
        completion = nil
    }
    
    private func completeWithError(_ error: Error) {
        completion?(.failure(error))
        completion = nil
    }
    
    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingTimer?.invalidate()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Config.contentLoadDelay) {
            webView.evaluateJavaScript("document.body.innerHTML") { [weak self] result, error in
                DispatchQueue.main.async {
                    if let error = error {
                        Logger.client.error("JavaScript execution error: \(error.localizedDescription)")
                        self?.completeWithError(WebContentError.javascriptError(error))
                        return
                    }
                    
                    if let html = result as? String, !html.isEmpty {
                        self?.processHTML(html)
                    } else {
                        self?.completeWithError(WebContentError.noContent)
                    }
                }
            }
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }
    
    private func handleNavigationFailure(_ error: Error) {
        loadingTimer?.invalidate()
        DispatchQueue.main.async {
            Logger.client.error("Navigation failed: \(error.localizedDescription)")
            self.completeWithError(WebContentError.navigationFailed(error))
        }
    }
}

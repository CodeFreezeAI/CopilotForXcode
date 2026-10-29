import AppKit

public struct StatusResponse {
    public struct Icon {
        /// Name of the icon resource
        public let name: String

        public init(name: String) {
            self.name = name
        }

        public var nsImage: NSImage? {
            return NSImage(named: name)
        }
    }

    /// The icon to display in the menu bar
    public let icon: Icon
    /// Indicates if an operation is in progress
    public let inProgress: Bool
    /// Message from the CLS (Copilot Language Server) status
    public let clsMessage: String
    /// Additional message (for accessibility or extension status)
    public let message: String?
    /// Extension status
    public let extensionStatus: ExtensionPermissionStatus
    /// URL for system preferences or other actions
    public let url: String?
    /// Current authentication status
    public let authStatus: AuthStatus.Status
    /// GitHub username of the authenticated user
    public let userName: String?
    /// Quota information for GitHub Copilot
    public let quotaInfo: GitHubCopilotQuotaInfo?
}

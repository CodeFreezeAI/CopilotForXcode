import Foundation

public struct XcodeInspectorData: Codable {
    public let activeWorkspaceURL: String?
    public let activeProjectRootURL: String?
    public let realtimeActiveWorkspaceURL: String?
    public let realtimeActiveProjectURL: String?
    public let latestNonRootWorkspaceURL: String?
    
    public init(
        activeWorkspaceURL: String?,
        activeProjectRootURL: String?,
        realtimeActiveWorkspaceURL: String?,
        realtimeActiveProjectURL: String?,
        latestNonRootWorkspaceURL: String?
    ) {
        self.activeWorkspaceURL = activeWorkspaceURL
        self.activeProjectRootURL = activeProjectRootURL
        self.realtimeActiveWorkspaceURL = realtimeActiveWorkspaceURL
        self.realtimeActiveProjectURL = realtimeActiveProjectURL
        self.latestNonRootWorkspaceURL = latestNonRootWorkspaceURL
    }
}

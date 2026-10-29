import Foundation

let GitPath = "/usr/bin/git"

public enum GitFileStatus {
    case untracked
    case indexAdded
    case modified
    case deleted
    case indexRenamed
}

public struct GitChange {
    public let url: URL
    public let originalURL: URL
    public let status: GitFileStatus
    
    public init(url: URL, originalURL: URL, status: GitFileStatus) {
        self.url = url
        self.originalURL = originalURL
        self.status = status
    }
}

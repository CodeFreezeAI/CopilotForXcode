public struct AuthStatus: Codable, Equatable, Hashable {
    public enum Status: Codable, Equatable, Hashable {
        case unknown
        case loggedIn
        case notLoggedIn
        case notAuthorized
    }
    public let status: Status
    public let username: String?
    public let message: String?
    
    public init(status: Status, username: String? = nil, message: String? = nil) {
        self.status = status
        self.username = username
        self.message = message
    }
}

public struct CLSStatus: Equatable {
    public enum Status { case unknown, normal, error, warning, inactive }
    public let status: Status
    public let busy: Bool
    public let message: String
    
    public var isInactiveStatus: Bool { status == .inactive && !message.isEmpty }
    public var isErrorStatus: Bool { status == .error && !message.isEmpty }
    public var isWarningStatus: Bool { status == .warning && !message.isEmpty }
}

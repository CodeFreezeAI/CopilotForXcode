import Foundation
import TelemetryServiceProvider

struct TelemetryExceptionParams: Codable {
    public let transaction: String?
    public let stacktrace: String?
    public let properties: [String: String]?
    public let platform: String?
    public let exceptionDetail: [ExceptionDetail]?
    
    public init(
        transaction: String? = nil,
        stacktrace: String? = nil,
        properties: [String: String]? = nil,
        platform: String? = nil,
        exceptionDetail: [ExceptionDetail]? = nil
    ) {
        self.transaction = transaction
        self.stacktrace = stacktrace
        self.properties = properties
        self.platform = platform
        self.exceptionDetail = exceptionDetail
    }
    
    enum CodingKeys: String, CodingKey {
        case transaction
        case stacktrace
        case properties
        case platform
        case exceptionDetail = "exception_detail"
    }
}

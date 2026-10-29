import Foundation
import GitHubCopilotService
import LanguageServerProtocol

extension NSError {
    static func from(_ error: Error) -> NSError {
        if let error = error as? ServerError {
            var message = "Unknown"
            var errorData: Codable? = nil
            switch error {
            case let .handlerUnavailable(handler):
                message = "Handler unavailable: \(handler)."
            case let .unhandledMethod(method):
                message = "Methond unhandled: \(method)."
            case let .notificationDispatchFailed(error):
                message = "Notification dispatch failed: \(error.localizedDescription)."
            case let .requestDispatchFailed(error):
                message = "Request dispatch failed: \(error.localizedDescription)."
            case let .clientDataUnavailable(error):
                message = "Client data unavailable: \(error.localizedDescription)."
            case .serverUnavailable:
                message = "Server unavailable, please make sure you have installed Node."
            case .missingExpectedParameter:
                message = "Missing expected parameter."
            case .missingExpectedResult:
                message = "Missing expected result."
            case let .unableToDecodeRequest(error):
                message = "Unable to decode request: \(error.localizedDescription)."
            case let .unableToSendRequest(error):
                message = "Unable to send request: \(error.localizedDescription)."
            case let .unableToSendNotification(error):
                message = "Unable to send notification: \(error.localizedDescription)."
            case let .serverError(code, m, data):
                message = "Server error: (\(code)) \(m)."
                errorData = data
            case let .invalidRequest(error):
                message = "Invalid request: \(error?.localizedDescription ?? "Unknown")."
            case .timeout:
                message = "Timeout."
            case .unknownError:
                message = "Unknown error: \(error.localizedDescription)."
            }
            
            var userInfo: [String: Any] = [NSLocalizedDescriptionKey: message]
            
            // Try to encode errorData to JSON for XPC transfer
            if let errorData = errorData {
                // Try to decode as MCPRegistryErrorData first
                if let jsonData = try? JSONEncoder().encode(errorData),
                   let mcpErrorData = try? JSONDecoder().decode(MCPRegistryErrorData.self, from: jsonData) {
                    userInfo["errorType"] = mcpErrorData.errorType
                    if let status = mcpErrorData.status {
                        userInfo["status"] = status
                    }
                    if let shouldRetry = mcpErrorData.shouldRetry {
                        userInfo["shouldRetry"] = shouldRetry
                    }
                } else if let jsonData = try? JSONEncoder().encode(errorData) {
                    // Fallback to encoding any Codable type
                    userInfo["serverErrorData"] = jsonData
                }
            }
            
            return NSError(domain: "com.github.CopilotForXcode", code: -1, userInfo: userInfo)
        }
        if let error = error as? CancellationError {
            return NSError(domain: "com.github.CopilotForXcode", code: -100, userInfo: [
                NSLocalizedDescriptionKey: error.localizedDescription,
            ])
        }
        return NSError(domain: "com.github.CopilotForXcode", code: -1, userInfo: [
            NSLocalizedDescriptionKey: error.localizedDescription,
        ])
    }
}

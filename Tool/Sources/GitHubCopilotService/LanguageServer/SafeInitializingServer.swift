import LanguageClient
import LanguageServerProtocol

public actor SafeInitializingServer {
    private let underlying: InitializingServer
    private var initTask: Task<InitializationResponse, Error>? = nil

    public init(_ server: InitializingServer) {
        self.underlying = server
    }

    // Ensure initialize request is sent by once
    public func initializeIfNeeded() async throws -> InitializationResponse {
        if let task = initTask {
            return try await task.value
        }

        let task = Task {
            try await underlying.initializeIfNeeded()
        }
        initTask = task

        do {
            let result = try await task.value
            return result
        } catch {
            // Retryable failure
            initTask = nil
            throw error
        }
    }

    public func shutdownAndExit() async throws {
        try await underlying.shutdownAndExit()
    }

    public func sendNotification(_ notif: ClientNotification) async throws {
        _ = try await initializeIfNeeded()
        try await underlying.sendNotification(notif)
    }

    public func sendRequest<Response: Decodable & Sendable>(_ request: ClientRequest) async throws -> Response {
        _ = try await initializeIfNeeded()
        return try await underlying.sendRequest(request)
    }

    public var capabilities: ServerCapabilities? {
        get async {
            await underlying.capabilities
        }
    }

    public var serverInfo: ServerInfo? {
        get async {
            await underlying.serverInfo
        }
    }

    public nonisolated var eventSequence: ServerConnection.EventSequence {
        underlying.eventSequence
    }
}

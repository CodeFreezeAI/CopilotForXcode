import Foundation
import Status

public struct WarningAction: Equatable {
    public var title: String
    public var url: URL

    public init(title: String, url: URL) {
        self.title = title
        self.url = url
    }
}

public struct WarningContent: Equatable {
    public var message: String
    public var severity: String // "warning" or "info"
    public var actions: [WarningAction] // 0-2 CTAs

    public init(message: String, severity: String, actions: [WarningAction] = []) {
        self.message = message
        self.severity = severity
        self.actions = actions
    }
}

public class WarningStateManager: ObservableObject {
    public static let shared = WarningStateManager()

    @Published public var currentWarning: WarningContent?

    private init() {
        DistributedNotificationCenter.default().addObserver(
            forName: .authStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.dismissWarning()
        }
    }

    public func setWarning(_ warning: WarningContent) {
        DispatchQueue.main.async { [weak self] in
            guard self?.currentWarning != warning else { return }
            self?.currentWarning = warning
        }
    }

    public func dismissWarning() {
        DispatchQueue.main.async { [weak self] in
            self?.currentWarning = nil
        }
    }
}

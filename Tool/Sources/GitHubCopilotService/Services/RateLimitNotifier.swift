import AppKit
import Combine
import Foundation
import Logger
import NotificationCenterCoordinator
import UserNotifications

public struct UsageRateLimit: Hashable, Codable {
    public var entitlement: Int
    public var percentRemaining: Double
    public var resetDate: String
}

public struct RateLimitWarningParams: Hashable, Codable {
    public var type: String // "weekly" or "session"
    public var rateLimit: UsageRateLimit
    public var message: String
}

public protocol RateLimitNotifier {
    func handleRateLimitWarning(_ params: RateLimitWarningParams)
}

public class RateLimitNotifierImpl: NSObject, RateLimitNotifier {
    public static let shared = RateLimitNotifierImpl()

    private static let categoryIdentifier = "rateLimitWarningCategory"
    private static let learnMoreActionIdentifier = "rateLimitLearnMoreAction"
    private static let learnMoreURL = URL(
        string: "https://aka.ms/github-copilot-rate-limit-error"
    )!

    private var isCategoryRegistered = false

    private override init() {
        super.init()
    }

    private func registerCategoryIfNeeded() {
        guard !isCategoryRegistered else { return }
        isCategoryRegistered = true

        let learnMoreAction = UNNotificationAction(
            identifier: Self.learnMoreActionIdentifier,
            title: "Learn more",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [learnMoreAction],
            intentIdentifiers: [],
            options: []
        )

        NotificationCenterCoordinator.shared.register(
            category: category,
            handler: { response in
                if response.actionIdentifier == Self.learnMoreActionIdentifier {
                    NSWorkspace.shared.open(Self.learnMoreURL)
                }
            },
            for: Self.categoryIdentifier
        )
    }

    public func handleRateLimitWarning(_ params: RateLimitWarningParams) {
        WarningStateManager.shared.setWarning(WarningContent(
            message: params.message,
            severity: "warning",
            actions: [WarningAction(title: "Learn more", url: Self.learnMoreURL)]
        ))

        Task { @MainActor in
            await NotificationCenterCoordinator.shared.setupIfNeeded()
            self.registerCategoryIfNeeded()
            await sendAppleNotification(params)
        }
    }

    @MainActor
    private func sendAppleNotification(_ params: RateLimitWarningParams) async {
        let content = UNMutableNotificationContent()
        content.title = "GitHub Copilot for Xcode"
        content.body = params.message
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier

        let request = UNNotificationRequest(
            identifier: "rateLimitWarning",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.gitHubCopilot.error("Failed to show rate limit notification: \(error)")
        }
    }
}

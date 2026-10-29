import AppKit
import Combine
import Foundation
import Logger
import NotificationCenterCoordinator
import Status
import UserNotifications

public struct QuotaSnapshotNotificationParams: Hashable, Codable {
    public var quota: Int
    public var used: Int
    public var percentRemaining: Double
    public var overageUsed: Int
    public var overageEnabled: Bool
    public var resetDate: String
    public var unlimited: Bool
}

public struct QuotaChangeParams: Codable {
    public var chat: QuotaSnapshotNotificationParams?
    public var completions: QuotaSnapshotNotificationParams?
    public var premiumInteractions: QuotaSnapshotNotificationParams?
    public var copilotPlan: String?
    public var canUpgradePlan: Bool?

    enum CodingKeys: String, CodingKey {
        case chat
        case completions
        case premiumInteractions = "premium_interactions"
        case copilotPlan
        case canUpgradePlan
    }
}

public struct QuotaWarningParams: Hashable, Codable {
    public var title: String
    public var message: String
    public var severity: String // "warning" or "info"
    public var chat: QuotaSnapshotNotificationParams?
    public var completions: QuotaSnapshotNotificationParams?
    public var premiumInteractions: QuotaSnapshotNotificationParams?
    public var copilotPlan: String?
    public var canUpgradePlan: Bool?

    enum CodingKeys: String, CodingKey {
        case title
        case message
        case severity
        case chat
        case completions
        case premiumInteractions = "premium_interactions"
        case copilotPlan
        case canUpgradePlan
    }
}

public protocol QuotaNotifier {
    func handleQuotaChange(_ params: QuotaChangeParams)
    func handleQuotaWarning(_ params: QuotaWarningParams)
}

public class QuotaNotifierImpl: NSObject, QuotaNotifier {
    public static let shared = QuotaNotifierImpl()

    private static let enableUsageActionIdentifier = "quotaEnableUsageAction"
    private static let increaseBudgetActionIdentifier = "quotaIncreaseBudgetAction"
    private static let upgradeActionIdentifier = "quotaUpgradeAction"
    private static let categoryNone = "quotaWarning_none"
    private static let categoryUpgrade = "quotaWarning_upgrade"
    private static let categoryEnableUsage = "quotaWarning_enableUsage"
    private static let categoryEnableUsageUpgrade = "quotaWarning_enableUsage_upgrade"
    private static let categoryIncreaseBudget = "quotaWarning_increaseBudget"
    private static let categoryIncreaseBudgetUpgrade = "quotaWarning_increaseBudget_upgrade"

    private var areCategoriesRegistered = false

    private override init() {
        super.init()
    }

    private func registerCategoriesIfNeeded() {
        guard !areCategoriesRegistered else { return }
        areCategoriesRegistered = true

        let enableUsageAction = UNNotificationAction(
            identifier: Self.enableUsageActionIdentifier,
            title: "Enable additional usage",
            options: [.foreground]
        )
        let increaseBudgetAction = UNNotificationAction(
            identifier: Self.increaseBudgetActionIdentifier,
            title: "Increase budget",
            options: [.foreground]
        )
        let upgradeAction = UNNotificationAction(
            identifier: Self.upgradeActionIdentifier,
            title: "Upgrade Plan",
            options: [.foreground]
        )

        let handler: (UNNotificationResponse) -> Void = { response in
            switch response.actionIdentifier {
            case Self.enableUsageActionIdentifier, Self.increaseBudgetActionIdentifier:
                NSWorkspace.shared.open(URL(string: QuotaFormatting.manageOverageURL)!)
            case Self.upgradeActionIdentifier:
                NSWorkspace.shared.open(URL(string: QuotaFormatting.upgradePlanURL)!)
            default:
                break
            }
        }

        let definitions: [(String, [UNNotificationAction])] = [
            (Self.categoryNone, []),
            (Self.categoryUpgrade, [upgradeAction]),
            (Self.categoryEnableUsage, [enableUsageAction]),
            (Self.categoryEnableUsageUpgrade, [enableUsageAction, upgradeAction]),
            (Self.categoryIncreaseBudget, [increaseBudgetAction]),
            (Self.categoryIncreaseBudgetUpgrade, [increaseBudgetAction, upgradeAction]),
        ]
        for (id, actions) in definitions {
            let category = UNNotificationCategory(
                identifier: id,
                actions: actions,
                intentIdentifiers: [],
                options: []
            )
            NotificationCenterCoordinator.shared.register(
                category: category,
                handler: handler,
                for: id
            )
        }
    }

    private func notificationCategoryID(for actions: [WarningAction]) -> String {
        let manageURL = QuotaFormatting.manageOverageURL
        let upgradeURL = QuotaFormatting.upgradePlanURL
        let manageAction = actions.first { $0.url.absoluteString == manageURL }
        let hasUpgrade = actions.contains { $0.url.absoluteString == upgradeURL }
        switch (manageAction?.title, hasUpgrade) {
        case (nil, false): return Self.categoryNone
        case (nil, true): return Self.categoryUpgrade
        case ("Increase budget", false): return Self.categoryIncreaseBudget
        case ("Increase budget", true): return Self.categoryIncreaseBudgetUpgrade
        case (_, false): return Self.categoryEnableUsage
        case (_, true): return Self.categoryEnableUsageUpgrade
        }
    }

    public func handleQuotaChange(_ params: QuotaChangeParams) {
        Task {
            guard var quotaInfo = await Status.shared.getQuotaInfo() else { return }
            if let chat = params.chat {
                quotaInfo.chat = QuotaSnapshot(from: chat)
            }
            if let completions = params.completions {
                quotaInfo.completions = QuotaSnapshot(from: completions)
            }
            if let premium = params.premiumInteractions {
                quotaInfo.premiumInteractions = QuotaSnapshot(from: premium)
            }
            if let plan = params.copilotPlan {
                quotaInfo.copilotPlan = plan
            }
            if let canUpgradePlan = params.canUpgradePlan {
                quotaInfo.canUpgradePlan = canUpgradePlan
            }
            let resetDate = params.chat?.resetDate
                ?? params.completions?.resetDate
                ?? params.premiumInteractions?.resetDate
            if let date = resetDate {
                quotaInfo.resetDate = date
            }
            await Status.shared.updateQuotaInfo(quotaInfo)
        }
    }

    public func handleQuotaWarning(_ params: QuotaWarningParams) {
        Task { @MainActor in
            let quotaInfo = await Status.shared.getQuotaInfo()
            let actions = buildWarningActions(params: params, quotaInfo: quotaInfo)
            let isCompletionsWarning = params.message.localizedCaseInsensitiveContains("completions")
            if !isCompletionsWarning {
                WarningStateManager.shared.setWarning(WarningContent(
                    message: params.message,
                    severity: params.severity,
                    actions: actions
                ))
            }
            await NotificationCenterCoordinator.shared.setupIfNeeded()
            self.registerCategoriesIfNeeded()
            await sendAppleNotification(params, categoryID: notificationCategoryID(for: actions))
        }
    }

    private func buildWarningActions(
        params: QuotaWarningParams,
        quotaInfo: GitHubCopilotQuotaInfo?
    ) -> [WarningAction] {
        let overageEnabled = params.premiumInteractions?.overageEnabled
            ?? quotaInfo?.premiumInteractions?.overagePermitted
            ?? false
        let canUpgrade = params.canUpgradePlan ?? quotaInfo?.isUpgradePlanAllowed ?? true

        let overageAction = WarningAction(
            title: overageEnabled ? "Increase budget" : "Enable additional usage",
            url: URL(string: QuotaFormatting.manageOverageURL)!
        )
        let upgradeAction = WarningAction(
            title: "Upgrade plan",
            url: URL(string: QuotaFormatting.upgradePlanURL)!
        )

        var actions: [WarningAction] = []
        if quotaInfo?.isPaidIndividual ?? false {
            actions.append(overageAction)
        }
        if canUpgrade {
            actions.append(upgradeAction)
        }
        return actions
    }

    @MainActor
    private func sendAppleNotification(_ params: QuotaWarningParams, categoryID: String) async {
        let content = UNMutableNotificationContent()
        content.title = params.title
        content.body = params.message
        content.sound = .default
        content.categoryIdentifier = categoryID

        let request = UNNotificationRequest(
            identifier: "quotaWarning",
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            Logger.gitHubCopilot.error("Failed to show quota warning notification: \(error)")
        }
    }
}

private extension QuotaSnapshot {
    init(from params: QuotaSnapshotNotificationParams) {
        self.init(
            percentRemaining: Float(params.percentRemaining),
            unlimited: params.unlimited,
            overagePermitted: params.overageEnabled,
            overageCount: Float(params.overageUsed),
            entitlement: Double(params.quota),
            quotaRemaining: Double(params.quota - params.used)
        )
    }
}

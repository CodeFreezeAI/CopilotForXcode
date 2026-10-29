import Foundation

public struct QuotaSnapshot: Codable, Equatable, Hashable {
    public var percentRemaining: Float?
    public var unlimited: Bool
    public var overagePermitted: Bool
    public var overageCount: Float?
    public var entitlement: Double?
    public var quotaRemaining: Double?
    public var timeStamp: String?

    public init(
        percentRemaining: Float? = nil,
        unlimited: Bool,
        overagePermitted: Bool,
        overageCount: Float? = nil,
        entitlement: Double? = nil,
        quotaRemaining: Double? = nil,
        timeStamp: String? = nil
    ) {
        self.percentRemaining = percentRemaining
        self.unlimited = unlimited
        self.overagePermitted = overagePermitted
        self.overageCount = overageCount
        self.entitlement = entitlement
        self.quotaRemaining = quotaRemaining
        self.timeStamp = timeStamp
    }

    /// Percentage of the quota that has been consumed (0–100), or nil when it can't be derived.
    public var usedPercentage: Float? {
        if let percentRemaining = percentRemaining {
            return 100.0 - percentRemaining
        }
        if let entitlement = entitlement, entitlement > 0, let remaining = quotaRemaining {
            return Float(max(0, min(100, ((entitlement - remaining) / entitlement) * 100)))
        }
        return nil
    }

    /// Coarse health bucket used to pick progress-bar / status colors.
    public enum UsageLevel {
        case healthy   // >25% remaining
        case warning   // 10–25% remaining
        case critical  // ≤10% remaining
    }

    public var usageLevel: UsageLevel {
        let percentRemaining = self.percentRemaining ?? (100.0 - (usedPercentage ?? 0))
        if percentRemaining <= 10 { return .critical }
        if percentRemaining <= 25 { return .warning }
        return .healthy
    }
}

public struct GitHubCopilotQuotaInfo: Codable, Equatable, Hashable {
    public var chat: QuotaSnapshot
    public var completions: QuotaSnapshot
    public var premiumInteractions: QuotaSnapshot?
    public var resetDate: String
    public var resetDateUtc: String? // CB/CE User only
    public var copilotPlan: String
    public var tokenBasedBillingEnabled: Bool?
    public var canUpgradePlan: Bool?

    public var isFreeUser: Bool { copilotPlan == "free" }
    public var isUpgradePlanAllowed: Bool { canUpgradePlan ?? true }
    public var isTokenBasedBilling: Bool { tokenBasedBillingEnabled == true }
    public var isCBCE: Bool { copilotPlan == "business" || copilotPlan == "enterprise" }
    public var isCBCEUnlimited: Bool { isCBCE && (premiumInteractions?.unlimited ?? false) }
    public var isPaidIndividual: Bool {
        copilotPlan == "individual" || copilotPlan == "individual_pro" || copilotPlan == "individual_max"
    }
    public var overagePermitted: Bool { premiumInteractions?.overagePermitted ?? false }

    /// Human-readable plan name (e.g. "Copilot Pro Plan").
    public var planDisplayName: String {
        switch copilotPlan {
        case "free": return "Copilot Free Plan"
        case "individual": return "Copilot Pro Plan"
        case "individual_pro": return "Copilot Pro+ Plan"
        case "individual_max": return "Copilot Max Plan"
        case "business": return "Copilot Business Plan"
        case "enterprise": return "Copilot Enterprise Plan"
        default: return "Copilot Plan"
        }
    }

    public init(
        chat: QuotaSnapshot,
        completions: QuotaSnapshot,
        premiumInteractions: QuotaSnapshot? = nil,
        resetDate: String,
        resetDateUtc: String? = nil,
        copilotPlan: String,
        tokenBasedBillingEnabled: Bool? = nil,
        canUpgradePlan: Bool? = nil
    ) {
        self.chat = chat
        self.completions = completions
        self.premiumInteractions = premiumInteractions
        self.resetDate = resetDate
        self.resetDateUtc = resetDateUtc
        self.copilotPlan = copilotPlan
        self.tokenBasedBillingEnabled = tokenBasedBillingEnabled
        self.canUpgradePlan = canUpgradePlan
    }
}

// MARK: - Shared formatting

public enum QuotaFormatting {
    public static let upgradePlanURL = "https://aka.ms/github-copilot-upgrade-plan"
    public static let manageOverageURL = "https://aka.ms/github-copilot-manage-overage"
    public static let settingsURL = "https://aka.ms/github-copilot-settings"

    /// Formats a percentage as "12% used" / "12.3% used".
    public static func formatUsedPercentage(_ used: Float) -> String {
        let numberPart = used.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", used)
            : String(format: "%.1f", used)
        return "\(numberPart)% used"
    }

    /// Formats a reset date string into "Resets in N days on MMM d, yyyy." text.
    /// Accepts ISO8601 (with or without fractional seconds), `yyyy-MM-dd`, or `yyyy.MM.dd`.
    public static func formatResetText(_ dateString: String) -> String {
        guard let date = parseResetDate(dateString) else {
            return "Resets on \(dateString)."
        }
        let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0)
        let formattedDate = mediumDateFormatter.string(from: date)
        return "Resets in \(days) \(days == 1 ? "day" : "days") on \(formattedDate)."
    }

    private static func parseResetDate(_ dateString: String) -> Date? {
        if let date = isoFractionalFormatter.date(from: dateString) { return date }
        if let date = isoFormatter.date(from: dateString) { return date }
        for formatter in shortDateFormatters {
            if let date = formatter.date(from: dateString) { return date }
        }
        return nil
    }

    private static let isoFractionalFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let shortDateFormatters: [DateFormatter] = ["yyyy-MM-dd", "yyyy.MM.dd"].map { format in
        let f = DateFormatter()
        f.dateFormat = format
        return f
    }

    private static let mediumDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
}

import SwiftUI
import Status

// MARK: - Quota Popover View

public struct QuotaPopoverView: View {
    let quotaInfo: GitHubCopilotQuotaInfo?

    public init(quotaInfo: GitHubCopilotQuotaInfo?) {
        self.quotaInfo = quotaInfo
    }

    private var isUnlimited: Bool {
        quotaInfo?.isCBCEUnlimited == true
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let quotaInfo = quotaInfo {
                // Plan name
                HStack {
                    Text(quotaInfo.planDisplayName)
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    Button(action: { openURL(QuotaFormatting.settingsURL) }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help("Open Copilot Settings")
                    .accessibilityLabel("Open Copilot Settings")
                }

                quotaContent(quotaInfo)
            } else {
                Text("No usage data available.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(isUnlimited
            ? EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
            : EdgeInsets(top: 18, leading: 16, bottom: 18, trailing: 16))
        .frame(
            minWidth: isUnlimited ? 260 : 320,
            idealWidth: isUnlimited ? 300 : 400,
            maxWidth: .infinity
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func quotaContent(_ info: GitHubCopilotQuotaInfo) -> some View {
        if info.isCBCEUnlimited {
            Text("You have no monthly limit on AI credits usage set by your organization.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        } else {
            let items = buildQuotaItems(info)

            ForEach(items, id: \.title) { item in
                quotaRow(item)
            }

            if !info.isFreeUser {
                let overagePermitted = info.overagePermitted
                let isNonTBBPaid = !info.isTokenBasedBilling && !info.isCBCE
                let overageLabel: String = isNonTBBPaid
                    ? (overagePermitted ? "Additional paid premium requests enabled." : "Additional paid premium requests disabled.")
                    : (overagePermitted ? "Additional usage enabled" : "Additional usage not enabled")
                let overageTooltip: String = info.isCBCE
                    ? (overagePermitted
                        ? "Usage will continue until limits are reset."
                        : "Usage will pause if the monthly usage limit is reached. Request additional usage from your administrator.")
                    : "Pay-as-you-go usage of additional AI credits once you run out of your included usage. Set a budget to cap your maximum monthly spend."
                HStack(spacing: 2) {
                    Text(overageLabel)
                        .scaledFont(size: 13)
                        .foregroundColor(overagePermitted ? .primary : .secondary)

                    if !isNonTBBPaid {
                        Image(systemName: "info.circle")
                            .scaledFont(size: 10)
                            .foregroundColor(.secondary)
                            .help(overageTooltip)
                    }
                }
            }

            if !info.isCBCE, shouldShowQuotaButtons(info) {
                quotaButtons(info)
            }
        }
    }

    private func shouldShowQuotaButtons(_ info: GitHubCopilotQuotaInfo) -> Bool {
        let snapshots: [QuotaSnapshot] = [info.premiumInteractions, info.chat, info.completions].compactMap { $0 }
        for snapshot in snapshots {
            if snapshot.unlimited { continue }
            if let used = snapshot.usedPercentage, used >= 75 {
                return true
            }
        }
        return false
    }

    @ViewBuilder
    private func quotaButtons(_ info: GitHubCopilotQuotaInfo) -> some View {
        let canUpgrade = info.isUpgradePlanAllowed
        let hasOverage = info.isPaidIndividual
        let overageTitle: String = info.isTokenBasedBilling
            ? (info.overagePermitted ? "Increase Budget" : "Enable Additional Usage")
            : "Manage Paid Premium Requests"
        let upgradeTitle = (!info.isTokenBasedBilling && info.isFreeUser) ? "Upgrade to Pro" : "Upgrade Plan"

        HStack(spacing: 8) {
            if hasOverage {
                actionButton(title: overageTitle, urlString: QuotaFormatting.manageOverageURL, prominent: true)
            }
            if canUpgrade {
                actionButton(title: upgradeTitle, urlString: QuotaFormatting.upgradePlanURL, prominent: hasOverage ? false : true)
            }
        }
    }

    @ViewBuilder
    private func actionButton(title: String, urlString: String, prominent: Bool) -> some View {
        if prominent {
            Button(action: { openURL(urlString) }) {
                Text(title)
                    .scaledFont(size: 13, weight: .medium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        } else {
            Button(action: { openURL(urlString) }) {
                Text(title)
                    .scaledFont(size: 13, weight: .medium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    @ViewBuilder
    private func quotaRow(_ item: QuotaItem) -> some View {
        VStack(alignment: .leading, spacing: item.tightResetSpacing ? 2 : 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 13))

                    if item.showInfoIcon {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .help(item.tooltip)
                    }

                    Spacer()

                    if let parts = item.creditCountParts {
                        (Text(parts.used).foregroundColor(.primary)
                            + Text(parts.suffix).foregroundColor(.secondary))
                            .font(.system(size: 11))
                    } else {
                        Text(item.percentageText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if item.isUnlimited {
                    Text("You have no limit on AI credits usage")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(item.barColor.opacity(0.3))
                                .frame(height: 3)

                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(item.barColor)
                                .frame(width: geometry.size.width * CGFloat(min(item.usedFraction, 1.0)), height: 3)
                        }
                    }
                    .frame(height: 3)
                }
            }

            if let resetText = item.resetText {
                Text(resetText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Data helpers

    private struct QuotaItem {
        let title: String
        let percentageText: String
        let creditCountParts: (used: String, suffix: String)?
        let usedFraction: Float
        let isUnlimited: Bool
        let barColor: Color
        let tooltip: String
        let resetText: String?
        let showInfoIcon: Bool
        let tightResetSpacing: Bool
    }

    private func buildQuotaItems(_ info: GitHubCopilotQuotaInfo) -> [QuotaItem] {
        var items: [QuotaItem] = []
        let showInfoIcon = info.isTokenBasedBilling && !info.isFreeUser && !info.isCBCE
        let tightResetSpacing = !info.isFreeUser
        let creditsTooltip = "AI credits included with your plan, reset monthly. Enable additional usage to continue with pay-as-you-go credits once you run out of your included usage."

        if info.isCBCE {
            if let premium = info.premiumInteractions {
                items.append(makeQuotaItem(
                    title: "Monthly Limit",
                    snapshot: premium,
                    tooltip: "",
                    resetAt: info.resetDateUtc ?? info.resetDate,
                    showInfoIcon: false,
                    tightResetSpacing: tightResetSpacing
                ))
            }
        } else if info.isFreeUser {
            let completionsTitle = info.isTokenBasedBilling ? "Inline Suggestions" : "Code Completions"
            let chatTitle = info.isTokenBasedBilling ? "Included Credits" : "Chat Messages"
            items.append(makeQuotaItem(title: completionsTitle, snapshot: info.completions, tooltip: "", resetAt: nil, showInfoIcon: showInfoIcon, tightResetSpacing: tightResetSpacing))
            let chatResetAt = info.isTokenBasedBilling ? (info.resetDateUtc ?? info.resetDate) : nil
            let chatTooltip = info.isTokenBasedBilling ? creditsTooltip : ""
            items.append(makeQuotaItem(title: chatTitle, snapshot: info.chat, tooltip: chatTooltip, resetAt: chatResetAt, showInfoIcon: showInfoIcon, tightResetSpacing: tightResetSpacing))
        } else if info.isTokenBasedBilling {
            if let premium = info.premiumInteractions {
                items.append(makeQuotaItem(
                    title: "Included Credits",
                    snapshot: premium,
                    tooltip: creditsTooltip,
                    resetAt: info.resetDateUtc ?? info.resetDate,
                    showInfoIcon: showInfoIcon,
                    tightResetSpacing: tightResetSpacing
                ))
            }
        } else {
            if let premium = info.premiumInteractions {
                items.append(makeQuotaItem(title: "Premium Requests", snapshot: premium, tooltip: "", resetAt: nil, showInfoIcon: showInfoIcon, tightResetSpacing: tightResetSpacing))
            }
            if !info.completions.unlimited {
                items.append(makeQuotaItem(title: "Code Completions", snapshot: info.completions, tooltip: "", resetAt: nil, showInfoIcon: showInfoIcon, tightResetSpacing: tightResetSpacing))
            }
            if !info.chat.unlimited {
                items.append(makeQuotaItem(title: "Chat Messages", snapshot: info.chat, tooltip: "", resetAt: nil, showInfoIcon: showInfoIcon, tightResetSpacing: tightResetSpacing))
            }
        }

        return items
    }

    private func makeQuotaItem(title: String, snapshot: QuotaSnapshot, tooltip: String, resetAt: String?, showInfoIcon: Bool, tightResetSpacing: Bool) -> QuotaItem {
        let usedPercentage = snapshot.usedPercentage
        let showAsCreditCount = showInfoIcon
        let percentageText: String
        var creditCountParts: (used: String, suffix: String)? = nil
        if snapshot.unlimited {
            percentageText = "Included"
        } else if showAsCreditCount,
                  let entitlement = snapshot.entitlement,
                  let remaining = snapshot.quotaRemaining {
            let used = max(0, entitlement - remaining)
            let usedStr = Int(used).formatted()
            let totalStr = Int(entitlement).formatted()
            creditCountParts = (used: usedStr, suffix: " / \(totalStr) AI credits")
            percentageText = "\(usedStr) / \(totalStr) AI credits"
        } else if let used = usedPercentage {
            percentageText = QuotaFormatting.formatUsedPercentage(used)
        } else if let remaining = snapshot.quotaRemaining {
            percentageText = "\(Int(remaining)) remaining"
        } else {
            percentageText = "0%"
        }

        let usedFraction = (usedPercentage ?? 0) / 100.0
        let barColor = progressBarColor(for: snapshot.usageLevel)
        let noUsageYet = snapshot.usedPercentage == 0 || (snapshot.usedPercentage == nil && snapshot.percentRemaining == 100)

        let resetText: String?
        if let resetAt = resetAt, !snapshot.unlimited {
            resetText = noUsageYet ? "No usage yet" : QuotaFormatting.formatResetText(resetAt)
        } else {
            resetText = nil
        }

        return QuotaItem(
            title: title,
            percentageText: percentageText,
            creditCountParts: creditCountParts,
            usedFraction: usedFraction,
            isUnlimited: snapshot.unlimited,
            barColor: barColor,
            tooltip: tooltip,
            resetText: resetText,
            showInfoIcon: showInfoIcon,
            tightResetSpacing: tightResetSpacing
        )
    }

    private func progressBarColor(for level: QuotaSnapshot.UsageLevel) -> Color {
        switch level {
        case .critical: return .red
        case .warning: return .yellow
        case .healthy: return .blue
        }
    }
}

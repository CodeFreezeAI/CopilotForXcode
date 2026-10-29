import SwiftUI
import Foundation
import Status

// MARK: - QuotaView Main Class
public class QuotaView: NSView {

    // MARK: - Properties
    private let quotaInfo: GitHubCopilotQuotaInfo

    private var isFreeUser: Bool { quotaInfo.isFreeUser }
    private var isCBCE: Bool { quotaInfo.isCBCE }
    private var isCBCEUnlimited: Bool { quotaInfo.isCBCEUnlimited }
    private var tokenBasedBillingEnabled: Bool { quotaInfo.isTokenBasedBilling }
    private var isPaidIndividualUser: Bool { quotaInfo.isPaidIndividual }
    private var canUpgradePlan: Bool { quotaInfo.isUpgradePlanAllowed }

    private var isFreeQuotaUsedUp: Bool {
        let chatRemaining = quotaInfo.chat.percentRemaining ?? (100.0 - (quotaInfo.chat.usedPercentage ?? 0))
        let completionsRemaining = quotaInfo.completions.percentRemaining ?? (100.0 - (quotaInfo.completions.usedPercentage ?? 0))
        return chatRemaining == 0 && completionsRemaining == 0
    }

    private var isFreeQuotaRemaining: Bool {
        let chatRemaining = quotaInfo.chat.percentRemaining ?? (100.0 - (quotaInfo.chat.usedPercentage ?? 0))
        let completionsRemaining = quotaInfo.completions.percentRemaining ?? (100.0 - (quotaInfo.completions.usedPercentage ?? 0))
        return chatRemaining > 25 && completionsRemaining > 25
    }

    // MARK: - Initialization
    public init(quotaInfo: GitHubCopilotQuotaInfo) {
        self.quotaInfo = quotaInfo

        super.init(frame: NSRect(x: 0, y: 0, width: Layout.viewWidth, height: 0))

        configureView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Configuration
    private func configureView() {
        autoresizingMask = [.width]
        setupView()
        
        let calculatedHeight = fittingSize.height
        frame = NSRect(x: 0, y: 0, width: Layout.viewWidth, height: calculatedHeight)
    }
    
    private func setupView() {
        let components = createViewComponents()
        addSubviewsToHierarchy(components)
        setupLayoutConstraints(components)
    }
    
    // MARK: - Component Creation
    private func createViewComponents() -> ViewComponents {
        let (upsellView, upsellHeight) = createUpsellView()
        return ViewComponents(
            titleContainer: createTitleContainer(),
            progressViews: isCBCEUnlimited ? [] : createProgressViews(),
            statusMessageLabel: createStatusMessageLabel(),
            unlimitedMessageLabel: isCBCEUnlimited ? createUnlimitedMessageLabel() : nil,
            refreshTextLabel: (isCBCE && !isCBCEUnlimited) ? createRefreshTextLabel() : nil,
            resetTextLabel: createResetTextLabel(),
            upsellView: upsellView,
            upsellHeight: upsellHeight
        )
    }

    private func addSubviewsToHierarchy(_ components: ViewComponents) {
        addSubview(components.titleContainer)
        if isCBCEUnlimited {
            if let label = components.unlimitedMessageLabel {
                addSubview(label)
            }
            return
        }
        components.progressViews.forEach { addSubview($0) }
        if isCBCE, let refreshLabel = components.refreshTextLabel {
            if quotaInfo.premiumInteractions != nil {
                addSubview(components.statusMessageLabel)
            }
            addSubview(refreshLabel)
        } else {
            if !isFreeUser, quotaInfo.premiumInteractions != nil || isPaidIndividualUser {
                addSubview(components.statusMessageLabel)
            }
            addSubview(components.resetTextLabel)
            if !(isCBCE || (isFreeUser && isFreeQuotaRemaining)) {
                addSubview(components.upsellView)
            }
        }
    }
}

// MARK: - Title Section
extension QuotaView {
    private func createTitleContainer() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = createTitleLabel()
        let settingsButton = createSettingsButton()
        
        container.addSubview(titleLabel)
        container.addSubview(settingsButton)
        
        setupTitleConstraints(container: container, titleLabel: titleLabel, settingsButton: settingsButton)
        
        return container
    }
    
    private func createTitleLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "Copilot Usage")
        label.font = NSFont.systemFont(ofSize: Style.titleFontSize, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .systemGray
        return label
    }
    
    private func createSettingsButton() -> HoverButton {
        let button = HoverButton()
        
        if let image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Manage Copilot") {
            image.isTemplate = true
            button.image = image
        }
        
        button.imagePosition = .imageOnly
        button.alphaValue = Style.buttonAlphaValue
        button.toolTip = "Manage Copilot"
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(openCopilotSettings)
        
        return button
    }
    
    private func setupTitleConstraints(container: NSView, titleLabel: NSTextField, settingsButton: HoverButton) {
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            settingsButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            settingsButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonHoverSize),
            
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: settingsButton.leadingAnchor, constant: -Layout.settingsButtonSpacing)
        ])
    }
}

// MARK: - Progress Bars Section
extension QuotaView {
    private func createProgressViews() -> [NSView] {
        var items: [(String, QuotaSnapshot)] = []

        if isFreeUser {
            let completionsTitle = tokenBasedBillingEnabled ? "Inline Suggestions" : "Code Completions"
            let chatTitle = tokenBasedBillingEnabled ? "Included Credits" : "Chat Messages"
            items.append((completionsTitle, quotaInfo.completions))
            items.append((chatTitle, quotaInfo.chat))
        } else if tokenBasedBillingEnabled {
            if let premiumInteractions = quotaInfo.premiumInteractions {
                items.append(("Included Credits", premiumInteractions))
            }
        } else {
            // Original billing
            if let premiumInteractions = quotaInfo.premiumInteractions {
                items.append(("Premium Requests", premiumInteractions))
            }
            if !quotaInfo.completions.unlimited {
                items.append(("Code Completions", quotaInfo.completions))
            }
            if !quotaInfo.chat.unlimited {
                items.append(("Chat Messages", quotaInfo.chat))
            }
        }

        return items.map { createProgressBarSection(title: $0.0, snapshot: $0.1) }
    }

    private func createProgressBarSection(title: String, snapshot: QuotaSnapshot) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = createProgressTitleLabel(title: title)
        let percentageLabel = createPercentageLabel(snapshot: snapshot)
        
        container.addSubview(titleLabel)
        container.addSubview(percentageLabel)
        
        if !snapshot.unlimited {
            addProgressBar(to: container, snapshot: snapshot, titleLabel: titleLabel, percentageLabel: percentageLabel)
        } else {
            setupUnlimitedLayout(container: container, titleLabel: titleLabel, percentageLabel: percentageLabel)
        }
        
        return container
    }
    
    private func createProgressTitleLabel(title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: Style.progressFontSize, weight: .regular)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func createPercentageLabel(snapshot: QuotaSnapshot) -> NSTextField {
        let text: String
        if snapshot.unlimited {
            text = "Included"
        } else if let usedPercentage = snapshot.usedPercentage {
            text = QuotaFormatting.formatUsedPercentage(usedPercentage)
        } else if let quotaRemaining = snapshot.quotaRemaining {
            text = "\(Int(quotaRemaining)) remaining"
        } else {
            text = "0%"
        }

        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: Style.percentageFontSize, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.alignment = .right

        return label
    }

    private func addProgressBar(to container: NSView, snapshot: QuotaSnapshot, titleLabel: NSTextField, percentageLabel: NSTextField) {
        let usedPercentage = snapshot.usedPercentage ?? 0
        let color = progressBarColor(for: snapshot.usageLevel)
        
        let progressBackground = createProgressBackground(color: color)
        let progressFill = createProgressFill(color: color, usedPercentage: usedPercentage)
        
        progressBackground.addSubview(progressFill)
        container.addSubview(progressBackground)
        
        setupProgressBarConstraints(
            container: container,
            titleLabel: titleLabel,
            percentageLabel: percentageLabel,
            progressBackground: progressBackground,
            progressFill: progressFill,
            usedPercentage: usedPercentage
        )
    }
    
    private func createProgressBackground(color: NSColor) -> NSView {
        let background = NSView()
        background.wantsLayer = true
        background.layer?.backgroundColor = color.cgColor.copy(alpha: Style.progressBarBackgroundAlpha)
        background.layer?.cornerRadius = Layout.progressBarCornerRadius
        background.translatesAutoresizingMaskIntoConstraints = false
        return background
    }
    
    private func createProgressFill(color: NSColor, usedPercentage: Float) -> NSView {
        let fill = NSView()
        fill.wantsLayer = true
        fill.translatesAutoresizingMaskIntoConstraints = false
        fill.layer?.backgroundColor = color.cgColor
        fill.layer?.cornerRadius = Layout.progressBarCornerRadius
        return fill
    }
    
    private func setupProgressBarConstraints(
        container: NSView,
        titleLabel: NSTextField,
        percentageLabel: NSTextField,
        progressBackground: NSView,
        progressFill: NSView,
        usedPercentage: Float
    ) {
        NSLayoutConstraint.activate([
            // Title and percentage on the same line
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentageLabel.leadingAnchor, constant: -Layout.percentageLabelSpacing),
            
            percentageLabel.topAnchor.constraint(equalTo: container.topAnchor),
            percentageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            percentageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.percentageLabelMinWidth),
            
            // Progress bar background
            progressBackground.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Layout.progressBarVerticalOffset),
            progressBackground.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            progressBackground.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            progressBackground.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            progressBackground.heightAnchor.constraint(equalToConstant: Layout.progressBarThickness),
            
            // Progress bar fill
            progressFill.topAnchor.constraint(equalTo: progressBackground.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBackground.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBackground.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBackground.widthAnchor, multiplier: CGFloat(usedPercentage / 100.0))
        ])
    }
    
    private func setupUnlimitedLayout(container: NSView, titleLabel: NSTextField, percentageLabel: NSTextField) {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentageLabel.leadingAnchor, constant: -Layout.percentageLabelSpacing),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            percentageLabel.topAnchor.constraint(equalTo: container.topAnchor),
            percentageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            percentageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.percentageLabelMinWidth),
            percentageLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
    
    private func progressBarColor(for level: QuotaSnapshot.UsageLevel) -> NSColor {
        switch level {
        case .critical: return .systemRed
        case .warning: return .systemYellow
        case .healthy: return .systemBlue
        }
    }
}

// MARK: - Footer Section
extension QuotaView {
    private func createUnlimitedMessageLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "You have no monthly limit on AI credits usage set by your organization.")
        label.font = NSFont.systemFont(ofSize: Style.footerFontSize, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.alignment = .left
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = Layout.viewWidth - Layout.horizontalMargin * 2
        return label
    }

    private func createRefreshTextLabel() -> NSTextField {
        let dateString = quotaInfo.resetDateUtc ?? quotaInfo.resetDate
        let label = NSTextField(labelWithString: QuotaFormatting.formatResetText(dateString))
        label.font = NSFont.systemFont(ofSize: Style.footerFontSize, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.alignment = .left
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        label.preferredMaxLayoutWidth = Layout.viewWidth - Layout.horizontalMargin * 2
        return label
    }

    private func createStatusMessageLabel() -> NSTextField {
        let overagePermitted = quotaInfo.overagePermitted
        let message: String
        if tokenBasedBillingEnabled {
            message = overagePermitted ? "Additional usage enabled." : "Additional usage not enabled."
        } else {
            message = overagePermitted ?
                "Additional paid premium requests enabled." :
                "Additional paid premium requests disabled."
        }

        let label = NSTextField(labelWithString: isFreeUser ? "" : message)
        label.font = NSFont.systemFont(ofSize: Style.footerFontSize, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = (tokenBasedBillingEnabled && overagePermitted) ? .labelColor : .secondaryLabelColor
        label.alignment = .left
        return label
    }

    private func createResetTextLabel() -> NSTextField {
        let resetText: String
        if tokenBasedBillingEnabled {
            resetText = QuotaFormatting.formatResetText(quotaInfo.resetDateUtc ?? quotaInfo.resetDate)
        } else {
            resetText = legacyAllowanceResetText(quotaInfo.resetDate)
        }

        let label = NSTextField(labelWithString: resetText)
        label.font = NSFont.systemFont(ofSize: Style.footerFontSize, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.alignment = .left
        return label
    }

    private func legacyAllowanceResetText(_ dateString: String) -> String {
        for format in ["yyyy-MM-dd", "yyyy.MM.dd"] {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                let outputFormatter = DateFormatter()
                outputFormatter.dateFormat = "MMMM d, yyyy"
                return "Allowance resets \(outputFormatter.string(from: date))."
            }
        }
        return "Allowance resets \(dateString)."
    }
    
    private func createUpsellView() -> (NSView, CGFloat) {
        if tokenBasedBillingEnabled || isFreeUser {
            var buttons: [NSButton] = []
            if tokenBasedBillingEnabled, isPaidIndividualUser {
                let overagePermitted = quotaInfo.premiumInteractions?.overagePermitted ?? false
                let primaryTitle = overagePermitted ? "Increase Budget" : "Enable Additional Usage"
                buttons.append(makeProminentButton(title: primaryTitle, action: #selector(openCopilotManageOverage)))
            }
            if canUpgradePlan {
                if isFreeUser, !tokenBasedBillingEnabled {
                    buttons.append(createUpgradeToProButton())
                } else {
                    let upgrade = buttons.isEmpty
                        ? makeProminentButton(title: "Upgrade Plan", action: #selector(openCopilotUpgradePlan))
                        : makeBorderedButton(title: "Upgrade Plan", action: #selector(openCopilotUpgradePlan))
                    buttons.append(upgrade)
                }
            }
            switch buttons.count {
            case 1:
                let height = (isFreeUser && !tokenBasedBillingEnabled)
                    ? Layout.upgradeButtonHeight
                    : Layout.compactUpgradeButtonHeight
                return (buttons[0], height)
            case 2: return (makeButtonStack(buttons: buttons), Layout.dualButtonHeight)
            default:
                if isFreeUser { return (NSView(), 0) }
                break // TBB org/CBCE: fall through to default link
            }
        }

        let button = HoverButton()
        let title = tokenBasedBillingEnabled ? "Manage your Budget" : "Manage paid premium requests"
        button.setLinkStyle(title: title, fontSize: Style.footerFontSize)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.alphaValue = Style.labelAlphaValue
        button.alignment = .left
        button.target = self
        button.action = #selector(openCopilotManageOverage)
        return (button, Layout.linkLabelHeight)
    }

    private func createUpgradeToProButton() -> NSButton {
        let button = NSButton()
        let upgradeTitle = "Upgrade to Copilot Pro"

        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .push
        if isFreeQuotaUsedUp {
            if #available(macOS 26.0, *) {
                button.attributedTitle = NSAttributedString(
                    string: upgradeTitle,
                    attributes: [.foregroundColor: NSColor.controlTextColor]
                )
                button.bezelColor = .controlBackgroundColor
            } else {
                button.attributedTitle = NSAttributedString(
                    string: upgradeTitle,
                    attributes: [.foregroundColor: NSColor.white]
                )
                button.bezelColor = .controlAccentColor
            }
        } else {
            button.title = upgradeTitle
        }
        button.controlSize = .large
        button.target = self
        button.action = #selector(openCopilotUpgradePlan)
        return button
    }

    private func makeProminentButton(title: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .push
        button.controlSize = .regular
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        button.layer?.cornerRadius = 6
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.foregroundColor: NSColor.white]
        )
        button.target = self
        button.action = action
        return button
    }

    private func makeBorderedButton(title: String, action: Selector) -> NSButton {
        let button = NSButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .push
        button.controlSize = .regular
        button.title = title
        button.target = self
        button.action = action
        return button
    }

    private func makeButtonStack(buttons: [NSButton]) -> NSStackView {
        let stack = NSStackView(views: buttons)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.distribution = .fillEqually
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        for button in buttons {
            button.leadingAnchor.constraint(equalTo: stack.leadingAnchor).isActive = true
            button.trailingAnchor.constraint(equalTo: stack.trailingAnchor).isActive = true
            button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        }
        return stack
    }
}

// MARK: - Layout Constraints
extension QuotaView {
    private func setupLayoutConstraints(_ components: ViewComponents) {
        let constraints = buildConstraints(components)
        NSLayoutConstraint.activate(constraints)
    }
    
    private func buildConstraints(_ components: ViewComponents) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []

        // Title constraints
        constraints.append(contentsOf: buildTitleConstraints(components.titleContainer))

        if let unlimitedLabel = components.unlimitedMessageLabel {
            constraints.append(contentsOf: [
                unlimitedLabel.topAnchor.constraint(equalTo: components.titleContainer.bottomAnchor, constant: Layout.verticalSpacing),
                unlimitedLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
                unlimitedLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
                unlimitedLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
            return constraints
        }

        // Progress view constraints
        constraints.append(contentsOf: buildProgressViewConstraints(components))

        // Footer constraints
        constraints.append(contentsOf: buildFooterConstraints(components))

        return constraints
    }
    
    private func buildTitleConstraints(_ titleContainer: NSView) -> [NSLayoutConstraint] {
        return [
            titleContainer.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            titleContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
            titleContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
            titleContainer.heightAnchor.constraint(equalToConstant: Layout.titleHeight)
        ]
    }
    
    private func buildProgressViewConstraints(_ components: ViewComponents) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        var previousView: NSView = components.titleContainer

        for progressView in components.progressViews {
            constraints.append(contentsOf: [
                progressView.topAnchor.constraint(equalTo: previousView.bottomAnchor, constant: Layout.verticalSpacing),
                progressView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
                progressView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
                progressView.heightAnchor.constraint(equalToConstant: Layout.progressBarHeight)
            ])
            previousView = progressView
        }

        return constraints
    }

    private func buildFooterConstraints(_ components: ViewComponents) -> [NSLayoutConstraint] {
        let lastProgressView = components.progressViews.last ?? components.titleContainer
        let showResetText = true

        var constraints = [NSLayoutConstraint]()

        // CB/CE non-unlimited: show refresh text label + status message (if premium info exists)
        if let refreshLabel = components.refreshTextLabel {
            constraints.append(contentsOf: [
                refreshLabel.topAnchor.constraint(equalTo: lastProgressView.bottomAnchor, constant: Layout.smallVerticalSpacing),
                refreshLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
                refreshLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
                refreshLabel.heightAnchor.constraint(equalToConstant: Layout.footerTextHeight)
            ])
            var anchor: NSView = refreshLabel
            if quotaInfo.premiumInteractions != nil {
                let statusHeight = tokenBasedBillingEnabled ? Layout.statusMessageHeight : Layout.footerTextHeight
                constraints.append(contentsOf: [
                    components.statusMessageLabel.topAnchor.constraint(equalTo: anchor.bottomAnchor, constant: Layout.verticalSpacing),
                    components.statusMessageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
                    components.statusMessageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
                    components.statusMessageLabel.heightAnchor.constraint(equalToConstant: statusHeight)
                ])
                anchor = components.statusMessageLabel
            }
            constraints.append(anchor.bottomAnchor.constraint(equalTo: bottomAnchor))
            return constraints
        }

        // Anchor for the element after progress views
        var lastAnchorView: NSView = lastProgressView

        if showResetText {
            let resetTopSpacing = isFreeUser ? Layout.verticalSpacing : Layout.smallVerticalSpacing
            constraints.append(contentsOf: [
                components.resetTextLabel.topAnchor.constraint(equalTo: lastProgressView.bottomAnchor, constant: resetTopSpacing),
                components.resetTextLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
                components.resetTextLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
                components.resetTextLabel.heightAnchor.constraint(equalToConstant: Layout.footerTextHeight)
            ])
            lastAnchorView = components.resetTextLabel
        }

        if !isFreeUser, quotaInfo.premiumInteractions != nil || isPaidIndividualUser {
            let statusHeight = tokenBasedBillingEnabled ? Layout.statusMessageHeight : Layout.footerTextHeight
            constraints.append(contentsOf: [
                components.statusMessageLabel.topAnchor.constraint(equalTo: lastAnchorView.bottomAnchor, constant: Layout.verticalSpacing),
                components.statusMessageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
                components.statusMessageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
                components.statusMessageLabel.heightAnchor.constraint(equalToConstant: statusHeight)
            ])
            lastAnchorView = components.statusMessageLabel
        }

        if isCBCE || (isFreeUser && isFreeQuotaRemaining) {
            constraints.append(lastAnchorView.bottomAnchor.constraint(equalTo: bottomAnchor))
            return constraints
        }

        // Add link label constraints
        let isTallButton = components.upsellHeight == Layout.upgradeButtonHeight || components.upsellHeight == Layout.compactUpgradeButtonHeight
        let upsellTopSpacing: CGFloat = isTallButton ? Layout.smallVerticalSpacing : 0
        let upsellBottomSpacing: CGFloat = isTallButton ? -Layout.smallVerticalSpacing : 0
        constraints.append(contentsOf: [
            components.upsellView.topAnchor.constraint(equalTo: lastAnchorView.bottomAnchor, constant: upsellTopSpacing),
            components.upsellView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
            components.upsellView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
            components.upsellView.heightAnchor.constraint(equalToConstant: components.upsellHeight),

            components.upsellView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: upsellBottomSpacing)
        ])

        return constraints
    }
}

// MARK: - Actions
extension QuotaView {
    @objc private func openCopilotSettings() {
        openURL(QuotaFormatting.settingsURL)
    }

    @objc private func openCopilotManageOverage() {
        openURL(QuotaFormatting.manageOverageURL)
    }

    @objc private func openCopilotUpgradePlan() {
        openURL(QuotaFormatting.upgradePlanURL)
    }

    private func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Helper Types
private struct ViewComponents {
    let titleContainer: NSView
    let progressViews: [NSView]
    let statusMessageLabel: NSTextField
    let unlimitedMessageLabel: NSTextField?
    let refreshTextLabel: NSTextField?
    let resetTextLabel: NSTextField
    let upsellView: NSView
    let upsellHeight: CGFloat
}

// MARK: - Layout Constants
private struct Layout {
    static let viewWidth: CGFloat = 256
    static let horizontalMargin: CGFloat = 14
    static let verticalSpacing: CGFloat = 6
    static let unlimitedVerticalSpacing: CGFloat = 6
    static let smallVerticalSpacing: CGFloat = 2
    
    static let titleHeight: CGFloat = 20
    static let progressBarHeight: CGFloat = 22
    static let unlimitedProgressBarHeight: CGFloat = 16
    static let footerTextHeight: CGFloat = 16
    static let statusMessageHeight: CGFloat = 20
    static let linkLabelHeight: CGFloat = 16
    static let upgradeButtonHeight: CGFloat = 40
    static let compactUpgradeButtonHeight: CGFloat = 28
    static let dualButtonHeight: CGFloat = 54
    
    static let settingsButtonSize: CGFloat = 20
    static let settingsButtonHoverSize: CGFloat = 14
    static let settingsButtonSpacing: CGFloat = 8
    
    static let progressBarThickness: CGFloat = 3
    static let progressBarCornerRadius: CGFloat = 1.5
    static let progressBarVerticalOffset: CGFloat = -10
    static let percentageLabelMinWidth: CGFloat = 35
    static let percentageLabelSpacing: CGFloat = 8
}

// MARK: - Style Constants
private struct Style {
    static let labelAlphaValue: CGFloat = 0.85
    static let progressBarBackgroundAlpha: CGFloat = 0.3
    static let buttonAlphaValue: CGFloat = 0.85
    
    static let titleFontSize: CGFloat = 11
    static let progressFontSize: CGFloat = 13
    static let percentageFontSize: CGFloat = 11
    static let footerFontSize: CGFloat = 11
}

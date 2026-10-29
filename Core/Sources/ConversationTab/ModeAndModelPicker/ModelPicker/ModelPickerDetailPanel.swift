import AppKit
import Persist

// MARK: - Floating Detail Panel (shown on menu item hover)

private class MouseTrackingVisualEffectView: NSVisualEffectView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    private var mouseTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = mouseTrackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        mouseTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) { onMouseEntered?() }
    override func mouseExited(with event: NSEvent) { onMouseExited?() }
}

class ModelPickerDetailPanel: NSPanel {
    static let shared = ModelPickerDetailPanel()

    private let containerStack = NSStackView()
    private var hideTimer: Timer?

    private var containerConstraints: [NSLayoutConstraint] = []
    private var currentFontScale: CGFloat = 1.0
    private var currentModel: LLMModel?
    private var onModelSelect: (() -> Void)?

    // Clickable rows: (view in panel-local hierarchy, action, (label, restore color) pairs)
    private var clickableRows: [(view: NSView, action: () -> Void, labels: [(NSTextField, NSColor)])] = []
    private var hoveredRow: NSView?

    // Event interception during NSMenu tracking
    private var mousePollingTimer: Timer?
    private var localEventMonitor: Any?
    private var wasMouseDown: Bool = false

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        self.isFloatingPanel = true
        self.level = .popUpMenu + 1
        self.isOpaque = true
        self.backgroundColor = .clear
        self.hidesOnDeactivate = false
        self.hasShadow = true
        self.isMovable = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setupContent()
    }

    private static func roundedCornerMask(radius: CGFloat) -> NSImage {
        let diameter = radius * 2
        let image = NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private func setupContent() {
        let visual = MouseTrackingVisualEffectView()
        visual.onMouseEntered = { [weak self] in self?.cancelHide() }
        visual.onMouseExited = { [weak self] in self?.scheduleHide() }
        visual.material = .popover
        visual.state = .active
        visual.wantsLayer = true
        visual.maskImage = Self.roundedCornerMask(radius: 8)
        visual.translatesAutoresizingMaskIntoConstraints = false

        containerStack.orientation = .vertical
        containerStack.alignment = .leading
        containerStack.spacing = 6
        containerStack.translatesAutoresizingMaskIntoConstraints = false

        visual.addSubview(containerStack)
        self.contentView = visual

        applyScaledConstraints(to: visual, fontScale: 1.0)
    }

    private func applyScaledConstraints(to visual: NSView, fontScale: CGFloat) {
        NSLayoutConstraint.deactivate(containerConstraints)

        let padding: CGFloat = 8 * fontScale
        let horizontalPadding: CGFloat = 10 * fontScale

        containerConstraints = [
            containerStack.topAnchor.constraint(equalTo: visual.topAnchor, constant: padding),
            containerStack.leadingAnchor.constraint(equalTo: visual.leadingAnchor, constant: horizontalPadding),
            containerStack.trailingAnchor.constraint(equalTo: visual.trailingAnchor, constant: -horizontalPadding),
            containerStack.bottomAnchor.constraint(equalTo: visual.bottomAnchor, constant: -padding),
        ]

        NSLayoutConstraint.activate(containerConstraints)

        if let visual = visual as? NSVisualEffectView {
            visual.maskImage = Self.roundedCornerMask(radius: 8 * fontScale)
        }
        currentFontScale = fontScale
    }

    // MARK: - Interactivity (works during NSMenu event tracking)

    private func startInteractivity() {
        stopInteractivity()
        wasMouseDown = (NSEvent.pressedMouseButtons & 1) != 0

        // Poll mouse location every 50ms in .common mode so it fires during NSMenu tracking.
        // We also use this loop to detect clicks on the panel, because
        // `addLocalMonitorForEvents` does not reliably fire while NSMenu owns
        // the event loop (the menu eats clicks outside its bounds before our
        // monitor runs), so polling is the only thing that works here.
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            let mouse = NSEvent.mouseLocation
            let isMouseDown = (NSEvent.pressedMouseButtons & 1) != 0
            let isOverPanel = self.frame.contains(mouse)

            if isOverPanel {
                self.cancelHide()
                self.updateHoveredRow(at: mouse)

                // Detect mouse-down transition while over a row → trigger action.
                if isMouseDown, !self.wasMouseDown {
                    self.handleClickInPanel(at: mouse)
                }
            } else {
                self.clearHoveredRow()
            }

            self.wasMouseDown = isMouseDown
        }
        mousePollingTimer = timer
        RunLoop.current.add(timer, forMode: .common)

        // Local monitor as a secondary path (fires when no menu is tracking).
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            let screenLocation = NSEvent.mouseLocation
            if self.frame.contains(screenLocation) {
                self.handleClickInPanel(at: screenLocation)
                return nil
            }
            return event
        }
    }

    private func stopInteractivity() {
        mousePollingTimer?.invalidate()
        mousePollingTimer = nil
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        clearHoveredRow()
    }

    private func updateHoveredRow(at mouseLocation: NSPoint) {
        let target = rowAtScreenLocation(mouseLocation)?.view

        if target !== hoveredRow {
            restoreColors(for: hoveredRow)
            hoveredRow?.layer?.backgroundColor = NSColor.clear.cgColor
            if let target = target {
                target.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
                applyHoverColors(for: target)
            }
            hoveredRow = target
        }
    }

    private func clearHoveredRow() {
        restoreColors(for: hoveredRow)
        hoveredRow?.layer?.backgroundColor = NSColor.clear.cgColor
        hoveredRow = nil
    }

    private func applyHoverColors(for row: NSView) {
        guard let entry = clickableRows.first(where: { $0.view === row }) else { return }
        for (label, _) in entry.labels {
            label.textColor = .white
        }
    }

    private func restoreColors(for row: NSView?) {
        guard let row = row,
              let entry = clickableRows.first(where: { $0.view === row }) else { return }
        for (label, color) in entry.labels {
            label.textColor = color
        }
    }

    private func handleClickInPanel(at screenLocation: NSPoint) {
        rowAtScreenLocation(screenLocation)?.action()
    }

    private func rowAtScreenLocation(_ screenLocation: NSPoint) -> (view: NSView, action: () -> Void)? {
        let windowPoint = convertPoint(fromScreen: screenLocation)
        guard let contentView = contentView else { return nil }
        let contentPoint = contentView.convert(windowPoint, from: nil)
        return clickableRows.first {
            $0.view.convert($0.view.bounds, to: contentView).contains(contentPoint)
        }.map { (view: $0.view, action: $0.action) }
    }

    // MARK: - Helper: Create labels

    private func makeTitleLabel(_ text: String, scale: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13 * scale, weight: .bold)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }

    private func makeBodyLabel(_ text: String, scale: CGFloat, color: NSColor = .secondaryLabelColor) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = NSFont.systemFont(ofSize: 12 * scale)
        label.textColor = color
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.drawsBackground = false
        return label
    }

    private func makeSeparator() -> NSBox {
        let sep = NSBox()
        sep.boxType = .separator
        return sep
    }

    private func makeCategoryBadge(_ category: String, scale: CGFloat) -> NSView {
        let lowered = category.lowercased()
        let color: NSColor
        switch lowered {
        case "powerful": color = .systemBlue
        case "lightweight": color = .systemGreen
        default: color = .systemGray
        }

        let label = NSTextField(labelWithString: category.capitalized)
        let hPad: CGFloat = 6 * scale
        let vPad: CGFloat = 2 * scale
        label.font = NSFont.systemFont(ofSize: 10 * scale, weight: .medium)
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.wantsLayer = true
        container.layer?.borderColor = color.cgColor
        container.layer?.borderWidth = 1.0
        container.layer?.cornerRadius = (label.intrinsicContentSize.height + vPad * 2) / 2
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -hPad),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: vPad),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -vPad),
        ])

        return container
    }

    private func makeKeyValueRow(_ key: String, _ value: String, scale: CGFloat) -> NSStackView {
        let keyLabel = NSTextField(labelWithString: key)
        keyLabel.font = NSFont.systemFont(ofSize: 12 * scale)
        keyLabel.textColor = .secondaryLabelColor
        keyLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        keyLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let valueLabel = NSTextField(labelWithString: value)
        valueLabel.font = NSFont.systemFont(ofSize: 12 * scale)
        valueLabel.textColor = .labelColor
        valueLabel.alignment = .right
        valueLabel.setContentHuggingPriority(.required, for: .horizontal)
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = NSStackView(views: [keyLabel, valueLabel])
        row.orientation = .horizontal
        row.distribution = .fill
        row.spacing = 8 * scale
        return row
    }

    // MARK: - Thinking Effort Helpers

    private func effortDescription(for effort: String) -> String {
        switch effort.lowercased() {
        case "none": return "No reasoning applied"
        case "low": return "Faster responses with less reasoning"
        case "medium": return "Balanced reasoning and speed"
        case "high": return "Maximum reasoning depth"
        case "xhigh": return "Maximum reasoning depth but slower"
        default: return ""
        }
    }

    private func makeThinkingEffortRow(
        effort: String,
        isSelected: Bool,
        isDefault: Bool,
        scale: CGFloat,
        onSelect: @escaping () -> Void
    ) -> NSView {
        let checkmark = NSTextField(labelWithString: "✓")
        checkmark.font = NSFont.systemFont(ofSize: 12 * scale, weight: .medium)
        checkmark.textColor = .labelColor
        checkmark.alphaValue = isSelected ? 1.0 : 0.0
        checkmark.setContentHuggingPriority(.required, for: .horizontal)
        checkmark.setContentCompressionResistancePriority(.required, for: .horizontal)

        var effortName = effort.capitalized
        if isDefault { effortName += " (default)" }
        let effortLabel = NSTextField(labelWithString: effortName)
        effortLabel.font = NSFont.systemFont(ofSize: 12 * scale)
        effortLabel.textColor = .labelColor
        effortLabel.setContentHuggingPriority(.required, for: .horizontal)
        effortLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let description = effortDescription(for: effort)
        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: 12 * scale)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .right
        descLabel.lineBreakMode = .byTruncatingTail
        descLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        descLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let innerStack = NSStackView(views: [checkmark, effortLabel, descLabel])
        innerStack.orientation = .horizontal
        innerStack.spacing = 4 * scale
        innerStack.distribution = .fill
        innerStack.translatesAutoresizingMaskIntoConstraints = false

        // Outer container provides taller hover hit area without changing text spacing
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 4 * scale
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(innerStack)

        let vPad: CGFloat = 3 * scale
        let hPad: CGFloat = 4 * scale
        NSLayoutConstraint.activate([
            innerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: hPad),
            innerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -hPad),
            innerStack.topAnchor.constraint(equalTo: container.topAnchor, constant: vPad),
            innerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -vPad),
        ])

        clickableRows.append((container, onSelect, [
            (checkmark, .labelColor),
            (effortLabel, .labelColor),
            (descLabel, .secondaryLabelColor),
        ]))

        return container
    }

    // MARK: - Token formatting

    private func formatPrice(_ price: Float, tokenUnit: Int?) -> String {
        let unit = tokenUnit ?? 1_000_000
        let scaled = Double(price) * Double(unit) / 1_000_000.0
        if scaled == 0 { return "$ 0" }
        return scaled.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "$ %.0f", scaled)
            : String(format: "$ %.2f", scaled)
    }

    // MARK: - Show

    func show(
        for model: LLMModel,
        nearRect: NSRect,
        preferRight: Bool = true,
        fontScale: CGFloat = 1.0,
        onModelSelect: (() -> Void)? = nil
    ) {
        hideTimer?.invalidate()
        hideTimer = nil

        currentModel = model
        self.onModelSelect = onModelSelect

        if let visual = self.contentView {
            applyScaledConstraints(to: visual, fontScale: fontScale)
        }

        // Clear previous content
        containerStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        clickableRows.removeAll()
        hoveredRow = nil
        containerStack.spacing = 6 * fontScale

        let scale = fontScale

        // --- Title: Vendor + Display Name ---
        let displayName = model.displayName ?? model.modelName
        let vendorPrefix = model.vendor.map { "\($0) " } ?? ""
        let titleLabel = makeTitleLabel("\(vendorPrefix)\(displayName)", scale: scale)
        containerStack.addArrangedSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // --- Category badge ---
        if let category = model.modelPickerCategory, !category.isEmpty {
            let badge = makeCategoryBadge(category, scale: scale)
            containerStack.addArrangedSubview(badge)
        }

        // --- Degradation warning ---
        if let reason = model.degradationReason {
            let warningLabel = makeBodyLabel("\u{26A0} \(reason)", scale: scale, color: .labelColor)
            containerStack.addArrangedSubview(warningLabel)
        }

        // --- Auto model description ---
        if model.isAutoModel {
            let desc = makeBodyLabel(
                "Automatically selects the best model for your request based on capacity and performance.\n\nCost may vary based on the selected model.",
                scale: scale
            )
            containerStack.addArrangedSubview(desc)
            layoutAndShow(nearRect: nearRect, preferRight: preferRight, fontScale: fontScale)
            return
        }

        // --- Context Size section ---
        let hasInput = model.maxInputTokens != nil
        let hasOutput = model.maxOutputTokens != nil
        if hasInput || hasOutput {
            containerStack.addArrangedSubview(makeSeparator())

            let inputStr = model.maxInputTokens.map { "\u{2191} \(ModelMenuItemFormatter.formatContextWindow($0))" } ?? ""
            let outputStr = model.maxOutputTokens.map { "\u{2193} \(ModelMenuItemFormatter.formatContextWindow($0))" } ?? ""
            let contextValue = [inputStr, outputStr].filter { !$0.isEmpty }.joined(separator: "  ")
            let row = makeKeyValueRow("Context Size:", contextValue, scale: scale)
            containerStack.addArrangedSubview(row)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: containerStack.widthAnchor).isActive = true
        }

        // --- Cost / million tokens section ---
        if let tokenPrices = model.billing?.tokenPrices {
            containerStack.addArrangedSubview(makeSeparator())

            if let category = model.modelPickerPriceCategory, !category.isEmpty {
                let categoryRow = makeKeyValueRow("Cost Category:", category.capitalized, scale: scale)
                containerStack.addArrangedSubview(categoryRow)
                categoryRow.translatesAutoresizingMaskIntoConstraints = false
                categoryRow.widthAnchor.constraint(equalTo: containerStack.widthAnchor).isActive = true
            }

            let costHeader = NSTextField(labelWithString: "Cost per 1M Tokens:")
            costHeader.font = NSFont.systemFont(ofSize: 12 * scale)
            costHeader.textColor = .secondaryLabelColor
            containerStack.addArrangedSubview(costHeader)

            let tokenUnit = tokenPrices.tokenUnit

            if let inputPrice = tokenPrices.inputPrice {
                let row = makeKeyValueRow("Input:", formatPrice(inputPrice, tokenUnit: tokenUnit), scale: scale)
                containerStack.addArrangedSubview(row)
                row.translatesAutoresizingMaskIntoConstraints = false
                row.widthAnchor.constraint(equalTo: containerStack.widthAnchor).isActive = true
            }
            if let outputPrice = tokenPrices.outputPrice {
                let row = makeKeyValueRow("Output:", formatPrice(outputPrice, tokenUnit: tokenUnit), scale: scale)
                containerStack.addArrangedSubview(row)
                row.translatesAutoresizingMaskIntoConstraints = false
                row.widthAnchor.constraint(equalTo: containerStack.widthAnchor).isActive = true
            }
            if let cachePrice = tokenPrices.cachePrice {
                let row = makeKeyValueRow("Cached:", formatPrice(cachePrice, tokenUnit: tokenUnit), scale: scale)
                containerStack.addArrangedSubview(row)
                row.translatesAutoresizingMaskIntoConstraints = false
                row.widthAnchor.constraint(equalTo: containerStack.widthAnchor).isActive = true
            }
        }

        // --- Context Window ---
        if let maxContext = model.maxContextWindowTokens {
            containerStack.addArrangedSubview(makeSeparator())

            let row = makeKeyValueRow("Context Window:", "\(ModelMenuItemFormatter.formatContextWindow(maxContext))", scale: scale)
            containerStack.addArrangedSubview(row)
            row.translatesAutoresizingMaskIntoConstraints = false
            row.widthAnchor.constraint(equalTo: containerStack.widthAnchor).isActive = true
        }

        // --- Thinking Effort ---
        if model.supportsReasoningEffortLevel, !model.isAutoModel {
            let efforts = model.reasoningEfforts ?? []
            if !efforts.isEmpty {
                containerStack.addArrangedSubview(makeSeparator())

                let headerLabel = NSTextField(labelWithString: "Thinking Effort:")
                headerLabel.font = NSFont.systemFont(ofSize: 12 * scale)
                headerLabel.textColor = .secondaryLabelColor
                containerStack.addArrangedSubview(headerLabel)

                let currentEffort = AppState.shared.effectiveReasoningEffort(for: model) ?? ""
                let familyDefault = model.defaultReasoningEffort

                // Zero-spacing nested stack so container vPad doesn't add to inter-row gap
                let effortsStack = NSStackView()
                effortsStack.orientation = .vertical
                effortsStack.alignment = .leading
                effortsStack.spacing = 0
                effortsStack.translatesAutoresizingMaskIntoConstraints = false
                containerStack.addArrangedSubview(effortsStack)
                effortsStack.widthAnchor.constraint(equalTo: containerStack.widthAnchor).isActive = true

                for effort in efforts {
                    let isSelected = effort.lowercased() == currentEffort.lowercased()
                    let isDefault = effort.lowercased() == familyDefault
                    let row = makeThinkingEffortRow(
                        effort: effort,
                        isSelected: isSelected,
                        isDefault: isDefault,
                        scale: scale,
                        onSelect: { [weak self] in
                            AppState.shared.setSelectedReasoningEffort(effort, for: model)
                            let onModelSelect = self?.onModelSelect
                            DispatchQueue.main.async { [weak self] in
                                onModelSelect?()
                                self?.orderOut(nil)
                            }
                        }
                    )
                    effortsStack.addArrangedSubview(row)
                    row.translatesAutoresizingMaskIntoConstraints = false
                    row.widthAnchor.constraint(equalTo: effortsStack.widthAnchor).isActive = true
                }
            }
        }

        layoutAndShow(nearRect: nearRect, preferRight: preferRight, fontScale: fontScale)
        startInteractivity()
    }

    private func layoutAndShow(nearRect: NSRect, preferRight: Bool, fontScale: CGFloat) {
        let horizontalPadding: CGFloat = 10 * fontScale
        let verticalPadding: CGFloat = 8 * fontScale
        let hasThinkingEffort = (currentModel?.supportsReasoningEffortLevel == true)
            && !(currentModel?.reasoningEfforts?.isEmpty ?? true)
            && !(currentModel?.isAutoModel ?? false)
        let minPanelWidth: CGFloat = (hasThinkingEffort ? 320 : 220) * fontScale
        let maxPanelWidth: CGFloat = 560 * fontScale

        containerStack.layoutSubtreeIfNeeded()
        let fittingSize = containerStack.fittingSize

        let panelWidth = max(minPanelWidth, min(ceil(fittingSize.width + horizontalPadding * 2), maxPanelWidth))
        let contentWidth = panelWidth - horizontalPadding * 2

        for view in containerStack.arrangedSubviews {
            if let textField = view as? NSTextField {
                let wraps = textField.cell?.wraps == true
                let isTitleFont = textField.font?.pointSize == 13 * fontScale

                if isTitleFont {
                    textField.lineBreakMode = .byWordWrapping
                    textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    textField.preferredMaxLayoutWidth = contentWidth
                } else if wraps {
                    textField.preferredMaxLayoutWidth = contentWidth
                }
            }
        }

        containerStack.layoutSubtreeIfNeeded()
        let finalFittingSize = containerStack.fittingSize
        let panelHeight = ceil(finalFittingSize.height + verticalPadding * 2)

        let gap: CGFloat = 4 * fontScale
        var origin: NSPoint
        if preferRight {
            origin = NSPoint(x: nearRect.maxX + gap, y: nearRect.midY - panelHeight / 2)
        } else {
            origin = NSPoint(x: nearRect.minX - panelWidth - gap, y: nearRect.midY - panelHeight / 2)
        }

        let menuScreen = NSScreen.screens.first(where: { $0.frame.contains(nearRect.origin) }) ?? NSScreen.main

        if let screen = menuScreen {
            let screenFrame = screen.visibleFrame
            if origin.x + panelWidth > screenFrame.maxX {
                origin.x = nearRect.minX - panelWidth - gap
            }
            if origin.x < screenFrame.minX {
                origin.x = nearRect.maxX + gap
            }
            origin.x = max(origin.x, screenFrame.minX)
            origin.x = min(origin.x, screenFrame.maxX - panelWidth)
            origin.y = max(origin.y, screenFrame.minY)
            origin.y = min(origin.y, screenFrame.maxY - panelHeight)
        }

        setContentSize(NSSize(width: panelWidth, height: panelHeight))
        setFrameOrigin(origin)
        orderFront(nil)
    }

    func scheduleHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // Don't hide if mouse is still over the panel
            if self.frame.contains(NSEvent.mouseLocation) { return }
            self.stopInteractivity()
            self.orderOut(nil)
        }
    }

    func cancelHide() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    override func orderOut(_ sender: Any?) {
        stopInteractivity()
        super.orderOut(sender)
    }

    override func close() {
        hideTimer?.invalidate()
        hideTimer = nil
        stopInteractivity()
        super.close()
    }
}

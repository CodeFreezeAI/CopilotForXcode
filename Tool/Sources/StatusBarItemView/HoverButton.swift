import AppKit

class HoverButton: NSButton {
    private var isLinkMode = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupButton()
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.layer?.cornerRadius = 3
    }
    
    private func resetToDefaultState() {
        self.layer?.backgroundColor = NSColor.clear.cgColor
        if isLinkMode {
            updateLinkAppearance(isHovered: false)
        }
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        DispatchQueue.main.async {
            self.updateTrackingAreas()
        }
    }
    
    override func layout() {
        super.layout()
        updateTrackingAreas()
    }
    
    func configureLinkMode() {
        isLinkMode = true
        self.isBordered = false
        self.setButtonType(.momentaryChange)
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    func setLinkStyle(title: String, fontSize: CGFloat) {
        configureLinkMode()
        updateLinkAppearance(title: title, fontSize: fontSize, isHovered: false)
    }
    
    override func mouseEntered(with event: NSEvent) {
        if isLinkMode {
            updateLinkAppearance(isHovered: true)
        } else {
            self.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.15).cgColor
            super.mouseEntered(with: event)
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        if isLinkMode {
            updateLinkAppearance(isHovered: false)
        } else {
            super.mouseExited(with: event)
            resetToDefaultState()
        }
    }
    
    private func updateLinkAppearance(title: String? = nil, fontSize: CGFloat? = nil, isHovered: Bool = false) {
        let buttonTitle = title ?? self.title
        let font = fontSize != nil ? NSFont.systemFont(ofSize: fontSize!, weight: .regular) : NSFont.systemFont(ofSize: 11)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.controlAccentColor,
            .font: font,
            .underlineStyle: isHovered ? NSUnderlineStyle.single.rawValue : 0
        ]
        
        let attributedTitle = NSAttributedString(string: buttonTitle, attributes: attributes)
        self.attributedTitle = attributedTitle
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Reset state immediately after click
        DispatchQueue.main.async {
            self.resetToDefaultState()
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        // Ensure state is reset
        DispatchQueue.main.async {
            self.resetToDefaultState()
        }
    }

    override func viewDidHide() {
        super.viewDidHide()
        // Reset state when view is hidden (like when menu closes)
        resetToDefaultState()
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        // Ensure clean state when view reappears
        resetToDefaultState()
    }

    override func removeFromSuperview() {
        super.removeFromSuperview()
        // Reset state when removed from superview
        resetToDefaultState()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        for trackingArea in self.trackingAreas {
            self.removeTrackingArea(trackingArea)
        }
        
        guard self.bounds.width > 0 && self.bounds.height > 0 else { return }
        
        let trackingArea = NSTrackingArea(
            rect: self.bounds,
            options: [
                .mouseEnteredAndExited,
                .activeAlways,
                .inVisibleRect
            ],
            owner: self,
            userInfo: nil
        )
        self.addTrackingArea(trackingArea)
    }
}

import SwiftUI
import Cache

public class AccountItemView: NSView {
    private var target: AnyObject?
    private var action: Selector?
    private var isHovered = false
    private var visualEffect: NSVisualEffectView
    private let menuItemPadding: CGFloat = 6
    private let topInset: CGFloat = 4  // Customize this value
    private let bottomInset: CGFloat = 0

    private var userName: String
    private var nameLabel: NSTextField!
    let avatarSize = 28.0
    let horizontalPadding = 14.0
    let verticalPadding = 8.0

    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateVisualEffectFrame()
    }

    public init(
        target: AnyObject? = nil,
        action: Selector? = nil,
        userName: String = ""
    ) {
        self.target = target
        self.action = action
        self.userName = userName
        
        // Initialize visualEffect with zero frame - it will be updated in layout
        self.visualEffect = NSVisualEffectView(frame: .zero)
        self.visualEffect.material = .selection
        self.visualEffect.state = .active
        self.visualEffect.blendingMode = .withinWindow
        self.visualEffect.isHidden = true
        self.visualEffect.wantsLayer = true
        self.visualEffect.layer?.cornerRadius = 4
        self.visualEffect.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        self.visualEffect.isEmphasized = true

        // Initialize with a reasonable starting size
        super.init(
            frame: NSRect(
                x: 0,
                y: 0,
                width: 240,
                height: avatarSize+verticalPadding+topInset
            )
        )
        
        // Set up autoresizing mask to allow the view to resize with its superview
        self.autoresizingMask = [.width]
        self.visualEffect.autoresizingMask = [.width, .height]
        
        wantsLayer = true
        addSubview(visualEffect)
        
        // Create and configure subviews
        setupSubviews()
    }

    private func setupSubviews() {
        // Create avatar view with hover state
        let avatarView = NSHostingView(rootView: AvatarView(userName: userName, isHovered: isHovered))
        avatarView.frame = NSRect(
            x: horizontalPadding,
            y: 4,
            width: avatarSize,
            height: avatarSize
        )
        addSubview(avatarView)

        // Store nameLabel as property and configure it
        nameLabel = NSTextField(
            labelWithString: userName.isEmpty ? "Sign In to GitHub Account" : userName
        )
        nameLabel.font =
            .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        nameLabel.frame = NSRect(
            x: horizontalPadding*1.5 + avatarSize,
            y: 0,
            width: 180,
            height: avatarSize
        )
        nameLabel.cell?.truncatesLastVisibleLine = true
        nameLabel.cell?.lineBreakMode = .byTruncatingTail
        nameLabel.textColor = .labelColor
        addSubview(nameLabel)

        // Make sure nameLabel resizes with the view
        nameLabel.autoresizingMask = [.width]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func mouseUp(with event: NSEvent) {
        if let target = target, let action = action {
            NSApp.sendAction(action, to: target, from: self)
        }
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        visualEffect.isHidden = false
        nameLabel.textColor = .white
        if let avatarView = subviews.first(where: { $0 is NSHostingView<AvatarView> }) as? NSHostingView<AvatarView> {
            avatarView.rootView = AvatarView(userName: userName, isHovered: true)
        }
    }

    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        visualEffect.isHidden = true
        nameLabel.textColor = .labelColor
        if let avatarView = subviews.first(where: { $0 is NSHostingView<AvatarView> }) as? NSHostingView<AvatarView> {
            avatarView.rootView = AvatarView(userName: userName, isHovered: false)
        }
    }

    public override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    public override func layout() {
        super.layout()
        updateVisualEffectFrame()
    }

    private func updateVisualEffectFrame() {
        var paddedFrame = bounds
        paddedFrame.origin.x += menuItemPadding
        paddedFrame.origin.y += bottomInset
        paddedFrame.size.width -= menuItemPadding*2
        paddedFrame.size.height -= (topInset + bottomInset)
        visualEffect.frame = paddedFrame
    }
}

struct AvatarView: View {
    let userName: String
    let isHovered: Bool
    @ObservedObject private var viewModel = AvatarViewModel.shared

    init(userName: String, isHovered: Bool = false) {
        self.userName = userName
        self.isHovered = isHovered
    }

    var body: some View {
        Group {
            if let avatarImage = viewModel.avatarImage {
                avatarImage
                    .resizable()
                    .scaledToFit()
                    .clipShape(Circle())
            } else if userName.isEmpty {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(isHovered ? .white : .primary)
            } else {
                ProgressView()
                    .clipShape(Circle())
            }
        }
    }
}

struct NSViewPreview: NSViewRepresentable {
    var userName: String = ""
    
    func makeNSView(context: Context) -> NSView {
        let NSView = AccountItemView(
            userName: userName
        )
        return NSView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update as needed...
    }
}

#Preview("Not Signed In") {
    NSViewPreview().frame(width: 245, height: 52)
}
#Preview("Signed In, Active") {
    NSViewPreview(userName: "xcode-test").frame(width: 245, height: 52)
}

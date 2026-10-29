import SwiftUI
import ComposableArchitecture
import SharedUIComponents
import AppKit

struct CheckPoint: View {
    let chat: StoreOf<Chat>
    let messageId: String
    
    @State private var isHovering: Bool = false
    @State private var window: NSWindow?
    @AppStorage(\.chatFontSize) var chatFontSize
    @AppStorage(\.suppressRestoreCheckpointConfirmation) var suppressRestoreCheckpointConfirmation
    @Environment(\.colorScheme) var colorScheme
    
    private var isPendingCheckpoint: Bool {
        chat.pendingCheckpointMessageId == messageId
    }
    
    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: 4) {
                checkpointIcon
                
                checkpointLine
                    .overlay(alignment: .leading) {
                        checkpointContent
                    }
            }
            .scaledFrame(height: chatFontSize)
            .onHover { isHovering = $0 }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .background(WindowAccessor { window in
                // Store window reference for later use
                self.window = window
            })
        }
    }

    var checkpointIcon: some View {
        Image(systemName: "bookmark")
            .resizable()
            .scaledToFit()
            .scaledFrame(width: chatFontSize, height: chatFontSize)
            .foregroundStyle(.secondary)
    }
    
    var checkpointLine: some View {
        DashedLine()
            .stroke(style: StrokeStyle(dash: [3]))
            .foregroundStyle(.gray)
            .scaledFrame(height: 1)
    }
    
    @ViewBuilder
    var checkpointContent: some View {
        HStack(spacing: 12) {
            if isPendingCheckpoint {
                HStack(spacing: 12) {
                    undoButton
                    
                    Text("Checkpoint Restored")
                        .scaledFont(size: chatFontSize)
                        .foregroundStyle(.secondary)
                        .scaledPadding(.horizontal, 2)
                        .background(Color.chatWindowBackgroundColor)
                }
            } else if isHovering {
                restoreButton
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
            
            Spacer()
        }
    }
    
    var hasSubsequentFileEdit: Bool {
        for message in chat.state.getMessages(after: messageId, through: chat.pendingCheckpointMessageId) {
            if !message.fileEdits.isEmpty {
                return true
            }
        }
        
        return false
    }
    
    var restoreButton: some View {
        ActionButton(
            title: "Restore Checkpoint",
            helpText: "Restore workspace and chat to this point",
            action: {
                if !suppressRestoreCheckpointConfirmation && hasSubsequentFileEdit {
                    showRestoreAlert()
                } else {
                    handleRestore()
                }
            }
        )
    }
    
    func handleRestore() {
        Task { @MainActor in
            await chat.send(.restoreCheckPoint(messageId)).finish()
        }
    }
    
    var undoButton: some View {
        ActionButton(
            title: "Undo",
            helpText: "Reapply discarded workspace changes and chat",
            action: { 
                Task { @MainActor in 
                    await chat.send(.undoCheckPoint).finish()
                }
            }
        )
    }
    
    var accessibilityLabel: String {
        if isPendingCheckpoint {
            "Checkpoint restored. Tap to redo changes."
        } else {
            "Checkpoint. Tap to restore to this point."
        }
    }
    
    func showRestoreAlert() {
        let alert = NSAlert()
        alert.messageText = "Restore Checkpoint"
        alert.informativeText = "This will remove all subsequent requests and edits. Do you want to proceed?"
        
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"
        
        alert.alertStyle = .warning
        
        let targetWindow = window ?? NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first {
            $0.isVisible
         }
        
        if let targetWindow = targetWindow {
            alert.beginSheetModal(for: targetWindow) { response in
                self.handleAlertResponse(response, alert: alert)
            }
        } else {
            let response = alert.runModal()
            handleAlertResponse(response, alert: alert)
        }
    }
    
    private func handleAlertResponse(_ response: NSApplication.ModalResponse, alert: NSAlert) {
        if response == .alertFirstButtonReturn {
            handleRestore()
        }
        
        suppressRestoreCheckpointConfirmation = alert.suppressionButton?.state == .on
    }
}

private struct ActionButton: View {
    let title: String
    let helpText: String
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(\.chatFontSize) private var chatFontSize
    
    private var adaptiveTextColor: Color {
        colorScheme == .light ? .black.opacity(0.75) : .white.opacity(0.75)
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .scaledFont(.footnote)
                .scaledPadding(4)
                .foregroundStyle(adaptiveTextColor)
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(.gray, lineWidth: 0.5)
                )
        )
        .buttonStyle(HoverButtonStyle(padding: 0))
        .scaledPadding(.leading, 8)
        .help(helpText)
        .accessibilityLabel(title)
        .accessibilityHint(helpText)
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

struct WindowAccessor: NSViewRepresentable {
    var callback: (NSWindow?) -> Void
    
    func makeNSView(context: Context) -> NSView {
        return WindowTrackingView(callback: callback)
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let windowTrackingView = nsView as? WindowTrackingView {
            windowTrackingView.callback = callback
        }
    }
}

private class WindowTrackingView: NSView {
    var callback: (NSWindow?) -> Void
    
    init(callback: @escaping (NSWindow?) -> Void) {
        self.callback = callback
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        callback(window)
    }
}

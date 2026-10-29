import SwiftUI

public enum TextEditorState {
    case empty
    case singleLine
    case multipleLines(cursorAt: TextEditorLinePosition)
}

public enum TextEditorLinePosition {
    case first, last, middle
}

public struct AutoresizingCustomTextEditor: View {
    @Binding public var text: String
    public let font: NSFont
    public let isEditable: Bool
    public let maxHeight: Double
    public let minHeight: Double
    public let onSubmit: () -> Void
    public let onTextEditorStateChanged: ((TextEditorState?) -> Void)?
    
    @State private var textEditorHeight: CGFloat
    
    public init(
        text: Binding<String>,
        font: NSFont,
        isEditable: Bool,
        maxHeight: Double,
        onSubmit: @escaping () -> Void,
        onTextEditorStateChanged: ((TextEditorState?) -> Void)? = nil
    ) {
        _text = text
        self.font = font
        self.isEditable = isEditable
        self.maxHeight = maxHeight
        self.minHeight = Double(font.ascender + abs(font.descender) + font.leading) // Following the original padding: .top(1), .bottom(2)
        self.onSubmit = onSubmit
        self.onTextEditorStateChanged = onTextEditorStateChanged
        
        // Initialize with font height + 3 as in the original logic
        _textEditorHeight = State(initialValue: self.minHeight)
    }

    public var body: some View {
        CustomTextEditor(
            text: $text,
            font: font,
            isEditable: isEditable,
            maxHeight: maxHeight,
            minHeight: minHeight,
            onSubmit: onSubmit,
            heightDidChange: { height in
                self.textEditorHeight = min(height, maxHeight)
            },
            onTextEditorStateChanged: onTextEditorStateChanged
        )
        .frame(height: textEditorHeight)
    }
}

public struct CustomTextEditor: NSViewRepresentable {
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @Binding public var text: String
    public let font: NSFont
    public let maxHeight: Double
    public let minHeight: Double
    public let isEditable: Bool
    public let onSubmit: () -> Void
    public let heightDidChange: (CGFloat) -> Void
    public let onTextEditorStateChanged: ((TextEditorState?) -> Void)?

    public init(
        text: Binding<String>,
        font: NSFont,
        isEditable: Bool = true,
        maxHeight: Double,
        minHeight: Double,
        onSubmit: @escaping () -> Void,
        heightDidChange: @escaping (CGFloat) -> Void,
        onTextEditorStateChanged: ((TextEditorState?) -> Void)? = nil
    ) {
        _text = text
        self.font = font
        self.isEditable = isEditable
        self.maxHeight = maxHeight
        self.minHeight = minHeight
        self.onSubmit = onSubmit
        self.heightDidChange = heightDidChange
        self.onTextEditorStateChanged = onTextEditorStateChanged
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let textView = (context.coordinator.theTextView.documentView as! NSTextView)
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = font
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.setAccessibilityLabel("Chat Input, Ask Copilot. Type to ask questions or type / for topics, press enter to send out the request. Use the Chat Accessibility Help command for more information.")
        
        // Set up text container for dynamic height
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: textView.frame.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        // Configure scroll view
        let scrollView = context.coordinator.theTextView
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false // We'll manage the scrolling ourselves
        
        // Initialize height calculation
        context.coordinator.view = self
        context.coordinator.calculateAndUpdateHeight(textView: textView)
        
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        let textView = (context.coordinator.theTextView.documentView as! NSTextView)
        textView.isEditable = isEditable
        
        if textView.font != font {
            textView.font = font
            // Update height calculation when text changes
            context.coordinator.calculateAndUpdateHeight(textView: textView)
        }
        
        if textView.string != text {
            textView.string = text
            textView.undoManager?.removeAllActions()
            // Update height calculation when text changes
            context.coordinator.calculateAndUpdateHeight(textView: textView)
        }
        
    }
}

public extension CustomTextEditor {
    class Coordinator: NSObject, NSTextViewDelegate {
        var view: CustomTextEditor
        var theTextView = NSTextView.scrollableTextView()
        var affectedCharRange: NSRange?

        init(_ view: CustomTextEditor) {
            self.view = view
        }
        
        private func getEditorState(textView: NSTextView) -> TextEditorState? {
            let selectedRange = textView.selectedRange()
            let text = textView.string
            
            guard !text.isEmpty else { return .empty }
            
            // Get actual visual lines
            guard let layoutManager = textView.layoutManager,
                  let _ = textView.textContainer else {
                return nil
            }
            let textRange = NSRange(location: 0, length: text.count)
            var lineCount = 0
            var cursorLineIndex: Int?
            
            // Ensure including wrapped line
            layoutManager
                .enumerateLineFragments(
                    forGlyphRange: layoutManager.glyphRange(forCharacterRange: textRange, actualCharacterRange: nil)
                ) { (_, _, _, glyphRange, _) in
                    let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
                    
                    if selectedRange.location >= charRange.location && selectedRange.location <= NSMaxRange(charRange) {
                        cursorLineIndex = lineCount
                    }
                    
                    lineCount += 1
                }
            
            guard let cursorLineIndex else { return nil }
            
            guard lineCount > 1 else { return .singleLine }
            
            if cursorLineIndex == 0 {
                return .multipleLines(cursorAt: .first)
            } else if cursorLineIndex == lineCount - 1 {
                return .multipleLines(cursorAt: .last)
            } else {
                return .multipleLines(cursorAt: .middle)
            }
        }
        
        func calculateAndUpdateHeight(textView: NSTextView) {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                return
            }
            
            layoutManager.ensureLayout(for: textContainer)
            
            let usedRect = layoutManager.usedRect(for: textContainer)
            
            // Add padding for text insets if needed
            let textInsets = textView.textContainerInset
            let newHeight = max(view.minHeight, usedRect.height + textInsets.height * 2)
            
            // Update scroll behavior based on height vs maxHeight
            theTextView.hasVerticalScroller = newHeight >= view.maxHeight
            
            // Only report the height that will be used for display
            let heightToReport = min(newHeight, view.maxHeight)
            
            // Inform the SwiftUI view of the height
            DispatchQueue.main.async {
                self.view.heightDidChange(heightToReport)
            }
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            
            // Defer updating the binding for large text changes
            DispatchQueue.main.async {
                self.view.text = textView.string
            }
            
            // Update height after text changes
            calculateAndUpdateHeight(textView: textView)
        }
        
        // Add selection change detection
        public func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // Prevent layout interference during input method composition (Chinese, Japanese, Korean)
            // when text view is empty, layout calculations on marked text can trigger NSSecureCoding warnings 
            // which can disrupt composition
            if textView.hasMarkedText()  {
                return
            }
            
            let editorState = getEditorState(textView: textView)
            view.onTextEditorStateChanged?(editorState)
        }
        
        public func textView(
            _ textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSTextView.insertNewline(_:)) {
                if let event = NSApplication.shared.currentEvent,
                   !event.modifierFlags.contains(.shift),
                   event.keyCode == 36 // enter
                {
                    view.onSubmit()
                    return true
                }
            }

            return false
        }

        public func textView(
            _ textView: NSTextView,
            shouldChangeTextIn affectedCharRange: NSRange,
            replacementString: String?
        ) -> Bool {
            return true
        }
    }
}

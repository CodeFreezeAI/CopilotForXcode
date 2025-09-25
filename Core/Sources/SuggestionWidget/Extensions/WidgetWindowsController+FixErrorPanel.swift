import AppKit
import XcodeInspector
import Preferences

extension WidgetWindowsController {
    
    @MainActor
    var isFixErrorEnabled: Bool {
        UserDefaults.shared.value(for: \.enableFixError)
    }
    
    @MainActor
    func hideFixErrorWindow() {
        windows.fixErrorPanelWindow.alphaValue = 0
        windows.fixErrorPanelWindow.setIsVisible(false)
    }
    
    @MainActor
    func displayFixErrorWindow() {
        windows.fixErrorPanelWindow.setIsVisible(true)
        windows.fixErrorPanelWindow.alphaValue = 1
        windows.fixErrorPanelWindow.orderFrontRegardless()
    }
    
    func setupFixErrorPanelObservers() {
        Task { @MainActor in 
            let errorAnnotationsPublisher = store.publisher
                .map(\.fixErrorPanelState.errorAnnotationsAtCursorPosition)
                .removeDuplicates()
                .sink { [weak self] _ in 
                    Task { [weak self] in 
                        await self?.updateFixErrorPanelWindowLocation()
                    }
                }
            
            let isPanelDisplayedPublisher = store.publisher
                .map(\.fixErrorPanelState.isPanelDisplayed)
                .removeDuplicates()
                .sink { [weak self ] _ in
                    Task { [weak self] in 
                        await self?.updateFixErrorPanelWindowLocation()
                    }
                }
            
            await self.storeCancellables([errorAnnotationsPublisher, isPanelDisplayedPublisher])
        }
    }
    
    @MainActor
    func updateFixErrorPanelWindowLocation() async {
        guard isFixErrorEnabled else {
            hideFixErrorWindow()
            return
        }
        
        guard let activeApp = await XcodeInspector.shared.safe.activeApplication,
              (activeApp.isXcode || activeApp.isCopilotForXcodeExtensionService)
        else {
            hideFixErrorWindow()
            return
        }
        
        let state = store.withState { $0.fixErrorPanelState }
        guard state.isPanelDisplayed,
              let focusedEditor = state.focusedEditor,
              let scrollViewRect = focusedEditor.element.parent?.rect
        else {
            hideFixErrorWindow()
            return
        }
        
        let annotations = state.errorAnnotationsAtCursorPosition
        
        guard !annotations.isEmpty,
              let annotationRect = annotations.first(where: { $0.rect != nil})?.rect,
              scrollViewRect.contains(annotationRect),
              let screen = NSScreen.screens.first(where: { $0.frame.origin == .zero })
        else {
            hideFixErrorWindow()
            return
        }
        
        var fixErrorPanelWindowFrame = windows.fixErrorPanelWindow.frame
        fixErrorPanelWindowFrame.origin.x = annotationRect.minX - fixErrorPanelWindowFrame.width - Style.fixPanelToAnnotationSpacing
        // Locate the window to the middle in Y
        fixErrorPanelWindowFrame.origin.y = screen.frame.maxY - annotationRect.minY - annotationRect.height / 2 - fixErrorPanelWindowFrame.height / 2 + screen.frame.minY
        
        windows.fixErrorPanelWindow.setFrame(fixErrorPanelWindowFrame, display: true, animate: false)
        displayFixErrorWindow()
    }
    
    @MainActor
    func handleFixErrorEditorNotification(notification: SourceEditor.AXNotification) async {
        guard isFixErrorEnabled else {
            hideFixErrorWindow()
            return
        }
        
        switch notification.kind {
        case .scrollPositionChanged:
            store.send(.fixErrorPanel(.onScrollPositionChanged))
        case .valueChanged:
            store.send(.fixErrorPanel(.onEditorContentChanged))
        case .selectedTextChanged:
            store.send(.fixErrorPanel(.onCursorPositionChanged))
        default:
            break
        }
    }
}

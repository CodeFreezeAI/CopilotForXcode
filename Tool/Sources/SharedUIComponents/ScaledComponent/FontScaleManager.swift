import SwiftUI
import Combine

extension Notification.Name {
    static let fontScaleDidChange = Notification
        .Name("com.github.CopilotForXcode.FontScaleDidChange")
}

@MainActor
public class FontScaleManager: ObservableObject {
    @AppStorage(\.fontScale) private var fontScale {
        didSet {
            // Only post notification if this change originated locally
            postNotificationIfNeeded()
        }
    }
    
    public static let shared: FontScaleManager = .init()
    
    public static let maxScale: Double = 2.0
    public static let minScale: Double = 0.8
    public static let scaleStep: Double = 0.1
    public static let defaultScale: Double = 1.0
    
    private let processIdentifier = UUID().uuidString
    private var lastReceivedNotificationId: String?
    
    private init() { 
        // Listen for font scale changes from other processes
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleFontScaleChanged(_:)),
            name: .fontScaleDidChange,
            object: nil
        )
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    private func postNotificationIfNeeded() {
        // Don't post notification if we're processing an external notification
        guard lastReceivedNotificationId == nil else { return }
        
        let notificationId = UUID().uuidString
        DistributedNotificationCenter.default().postNotificationName(
            .fontScaleDidChange,
            object: nil,
            userInfo: [
                "fontScale": fontScale,
                "sourceProcess": processIdentifier,
                "notificationId": notificationId
            ],
            deliverImmediately: true
        )
    }
    
    @objc private func handleFontScaleChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let scale = userInfo["fontScale"] as? Double,
              let sourceProcess = userInfo["sourceProcess"] as? String,
              let notificationId = userInfo["notificationId"] as? String else {
            return
        }
        
        // Ignore notifications from this process
        guard sourceProcess != processIdentifier else { return }
        
        // Ignore duplicate notifications
        guard notificationId != lastReceivedNotificationId else { return }
        
        // Only update if the value actually changed (with epsilon for floating-point)
        guard abs(fontScale - scale) > 0.001 else { return }
        
        lastReceivedNotificationId = notificationId
        fontScale = scale
        lastReceivedNotificationId = nil
    }
    
    public func increaseFontScale() {
        fontScale = min(fontScale + Self.scaleStep, Self.maxScale)
    }
    
    public func decreaseFontScale() {
        fontScale = max(fontScale - Self.scaleStep, Self.minScale)
    }
    
    public func setFontScale(_ scale: Double) {
        guard scale <= Self.maxScale && scale >= Self.minScale else {
            return
        }
        
        fontScale = scale
    } 
    
    public func resetFontScale() {
        fontScale = Self.defaultScale
    }
    
    public var currentScale: Double {
        fontScale
    }
}

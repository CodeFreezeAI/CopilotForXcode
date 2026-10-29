import Foundation
import UserNotifications

/// A single shared delegate for `UNUserNotificationCenter`.
///
/// `UNUserNotificationCenter` has only one `delegate` and one set of categories.
/// Multiple features (rate limit warnings, show-message requests, etc.) need to
/// post notifications and handle action taps, so they register handlers here
/// keyed by category identifier instead of each assigning themselves as the
/// delegate.
public final class NotificationCenterCoordinator: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationCenterCoordinator()

    public typealias ActionHandler = (UNNotificationResponse) -> Void

    private var isNotificationSetup = false
    private var categories: [String: UNNotificationCategory] = [:]
    private var actionHandlers: [String: ActionHandler] = [:]
    private let lock = NSLock()

    private override init() {
        super.init()
    }

    /// Ensures the notification center delegate is set and authorization has
    /// been requested. Safe to call multiple times.
    @MainActor
    public func setupIfNeeded() async {
        guard !isNotificationSetup else { return }
        guard Bundle.main.bundleIdentifier != nil else {
            // Skip notification setup in test environment.
            return
        }
        isNotificationSetup = true
        UNUserNotificationCenter.current().delegate = self
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    /// Registers a category (optional) and an action handler for notifications
    /// whose `categoryIdentifier` matches.
    public func register(
        category: UNNotificationCategory?,
        handler: @escaping ActionHandler,
        for categoryIdentifier: String
    ) {
        lock.lock()
        if let category {
            categories[categoryIdentifier] = category
        }
        actionHandlers[categoryIdentifier] = handler
        let allCategories = Set(categories.values)
        lock.unlock()

        UNUserNotificationCenter.current().setNotificationCategories(allCategories)
    }

    // MARK: - UNUserNotificationCenterDelegate

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .badge, .sound])
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        lock.lock()
        let handler = actionHandlers[categoryIdentifier]
        lock.unlock()
        Task { @MainActor in
            handler?(response)
            completionHandler()
        }
    }
}

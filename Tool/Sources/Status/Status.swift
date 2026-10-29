import AppKit
import Preferences
import Foundation

@objc public enum ExtensionPermissionStatus: Int {
    case unknown = -1, notGranted = 0, disabled = 1, granted = 2
}

@objc public enum ObservedAXStatus: Int {
    case unknown = -1, granted = 1, notGranted = 0
}

private struct AuthStatusInfo {
    let authIcon: StatusResponse.Icon?
    let authStatus: AuthStatus.Status
    let userName: String?
}

private struct CLSStatusInfo {
    let icon: StatusResponse.Icon?
    let message: String
}

private struct AccessibilityStatusInfo {
    let icon: StatusResponse.Icon?
    let message: String?
    let url: String?
}

public extension Notification.Name {
    static let authStatusDidChange = Notification.Name("com.github.CopilotForXcode.authStatusDidChange")
    static let serviceStatusDidChange = Notification.Name("com.github.CopilotForXcode.serviceStatusDidChange")
}

private var currentUserName: String? = nil
private var currentUserCopilotPlan: String? = nil

public final actor Status {
    public static let shared = Status()

    private var extensionStatus: ExtensionPermissionStatus = .unknown
    private var axStatus: ObservedAXStatus = .unknown
    private var clsStatus = CLSStatus(status: .unknown, busy: false, message: "")
    private var authStatus = AuthStatus(status: .unknown, username: nil, message: nil)
    
    private var currentUserQuotaInfo: GitHubCopilotQuotaInfo? = nil

    private let okIcon = StatusResponse.Icon(name: "MenuBarIcon")
    private let errorIcon = StatusResponse.Icon(name: "MenuBarErrorIcon")
    private let warningIcon = StatusResponse.Icon(name: "MenuBarWarningIcon")
    private let inactiveIcon = StatusResponse.Icon(name: "MenuBarInactiveIcon")

    private init() {}

    public static func currentUser() -> String? {
        return currentUserName
    }
    
    public func currentUserPlan() -> String? {
        return currentUserCopilotPlan
    }

    public func updateQuotaInfo(_ quotaInfo: GitHubCopilotQuotaInfo?) {
        guard quotaInfo != currentUserQuotaInfo else { return }
        currentUserQuotaInfo = quotaInfo
        currentUserCopilotPlan = quotaInfo?.copilotPlan
        broadcast()
    }

    public func updateExtensionStatus(_ status: ExtensionPermissionStatus) {
        guard status != extensionStatus else { return }
        extensionStatus = status
        broadcast()
    }

    public func updateAXStatus(_ status: ObservedAXStatus) {
        guard status != axStatus else { return }
        axStatus = status
        broadcast()
    }

    public func updateCLSStatus(_ status: CLSStatus.Status, busy: Bool, message: String) {
        let newStatus = CLSStatus(status: status, busy: busy, message: message)
        guard newStatus != clsStatus else { return }
        clsStatus = newStatus
        broadcast()
    }

    public func updateAuthStatus(_ status: AuthStatus.Status, username: String? = nil, message: String? = nil) {
        currentUserName = username
        UserDefaults.shared.set(username ?? "", for: \.currentUserName)
        let newStatus = AuthStatus(status: status, username: username, message: message)
        guard newStatus != authStatus else { return }
        authStatus = newStatus
        broadcast()
    }
    
    public func getExtensionStatus() -> ExtensionPermissionStatus {
        extensionStatus
    }

    public func getAXStatus() -> ObservedAXStatus {
        if isXcodeRunning() {
            return axStatus
        } else if AXIsProcessTrusted() {
            return .granted
        } else {
            return axStatus
        }
    }

    private func isXcodeRunning() -> Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dt.Xcode"
        ).isEmpty
    }

    public func getAuthStatus() -> AuthStatus {
        authStatus
    }

    public func getCLSStatus() -> CLSStatus {
        clsStatus
    }
    
    public func getQuotaInfo() -> GitHubCopilotQuotaInfo? {
        currentUserQuotaInfo
    }

    public func getStatus() -> StatusResponse {
        let authStatusInfo: AuthStatusInfo = getAuthStatusInfo()
        let clsStatusInfo: CLSStatusInfo = getCLSStatusInfo()
        let extensionStatusIcon = (
            extensionStatus == ExtensionPermissionStatus.disabled || extensionStatus == ExtensionPermissionStatus.notGranted
        ) ? errorIcon : nil
        let accessibilityStatusInfo: AccessibilityStatusInfo = getAccessibilityStatusInfo()
        return .init(
            icon: authStatusInfo.authIcon ?? clsStatusInfo.icon ?? extensionStatusIcon ?? accessibilityStatusInfo.icon ?? okIcon,
            inProgress: clsStatus.busy,
            clsMessage: clsStatus.message,
            message: accessibilityStatusInfo.message,
            extensionStatus: extensionStatus,
            url: accessibilityStatusInfo.url,
            authStatus: authStatusInfo.authStatus,
            userName: authStatusInfo.userName,
            quotaInfo: currentUserQuotaInfo
        )
    }

    private func getAuthStatusInfo() -> AuthStatusInfo {
        switch authStatus.status {
        case .unknown, .loggedIn:
            return AuthStatusInfo(
                authIcon: nil,
                authStatus: authStatus.status,
                userName: authStatus.username
            )
        case .notLoggedIn:
            return AuthStatusInfo(
                authIcon: errorIcon,
                authStatus: authStatus.status,
                userName: nil
            )
        case .notAuthorized:
            return AuthStatusInfo(
                authIcon: inactiveIcon,
                authStatus: authStatus.status,
                userName: authStatus.username
            )
        }
    }
    
    private func getCLSStatusInfo() -> CLSStatusInfo {
        if clsStatus.isInactiveStatus {
            return CLSStatusInfo(icon: inactiveIcon, message: clsStatus.message)
        }
        if clsStatus.isWarningStatus {
            return CLSStatusInfo(icon: warningIcon, message: clsStatus.message)
        }
        if clsStatus.isErrorStatus {
            return CLSStatusInfo(icon: errorIcon, message: clsStatus.message)
        }
        return CLSStatusInfo(icon: nil, message: "")
    }

    private func getAccessibilityStatusInfo() -> AccessibilityStatusInfo {
        switch getAXStatus() {
        case .granted:
            return AccessibilityStatusInfo(icon: nil, message: nil, url: nil)
        case .notGranted:
            return AccessibilityStatusInfo(
                icon: errorIcon,
                message: """
                Enable accessibility in system preferences
                """,
                url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        case .unknown:
            return AccessibilityStatusInfo(
                icon: errorIcon,
                message: """
                Enable accessibility or restart Copilot
                """,
                url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        }
    }

    private func broadcast() {
        NotificationCenter.default.post(name: .serviceStatusDidChange, object: nil)
        // Can remove DistributedNotificationCenter if the settings UI moves in-process
        DistributedNotificationCenter.default().post(name: .serviceStatusDidChange, object: nil)
    }
}

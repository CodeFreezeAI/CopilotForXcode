import SwiftUI
import Cache

@MainActor
public class StatusObserver: ObservableObject {
    @Published public private(set) var authStatus = AuthStatus(status: .unknown, username: nil, message: nil)
    @Published public private(set) var clsStatus = CLSStatus(status: .unknown, busy: false, message: "")
    @Published public private(set) var observedAXStatus = ObservedAXStatus.unknown
    @Published public private(set) var quotaInfo: GitHubCopilotQuotaInfo? = nil
    
    public static let shared = StatusObserver()
    
    private init() {
        Task { @MainActor in
            await observeAuthStatus()
            await observeCLSStatus()
            await observeAXStatus()
            await observeQuotaInfo()
        }
    }
    
    private func observeAuthStatus() async {
        await updateAuthStatus()
        setupAuthStatusNotificationObserver()
    }
    
    private func observeCLSStatus() async {
        await updateCLSStatus()
        setupCLSStatusNotificationObserver()
    }
    
    private func observeAXStatus() async {
        await updateAXStatus()
        setupAXStatusNotificationObserver()
    }
    
    private func observeQuotaInfo() async {
        await updateQuotaInfo()
        setupQuotaInfoNotificationObserver()
    }
    
    private func updateAuthStatus() async {
        let authStatus = await Status.shared.getAuthStatus()
        let statusInfo = await Status.shared.getStatus()
        
        if authStatus.status == .notLoggedIn {
            await Status.shared.updateQuotaInfo(nil)
        }
        
        self.authStatus = AuthStatus(
            status: authStatus.status,
            username: statusInfo.userName,
            message: nil
        )
        
        // load avatar when auth status changed
        AvatarViewModel.shared.loadAvatar(forUser: self.authStatus.username)
    }
    
    private func updateCLSStatus() async {
        self.clsStatus = await Status.shared.getCLSStatus()
    }
    
    private func updateAXStatus() async {
        self.observedAXStatus = await Status.shared.getAXStatus()
    }
    
    private func updateQuotaInfo() async {
        self.quotaInfo = await Status.shared.getQuotaInfo()
    }
    
    private func setupAuthStatusNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .serviceStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [self] in
                await self.updateAuthStatus()
            }
        }
        
        DistributedNotificationCenter.default().addObserver(
            forName: .authStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [self] in
                await self.updateAuthStatus()
            }
        }
    }
    
    private func setupCLSStatusNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .serviceStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [self] in
                await self.updateCLSStatus()
            }
        }
    }
    
    private func setupAXStatusNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .serviceStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [self] in
                await self.updateAXStatus()
            }
        }
    }
    
    private func setupQuotaInfoNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .serviceStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor [self] in
                await self.updateQuotaInfo()
            }
        }
    }
}

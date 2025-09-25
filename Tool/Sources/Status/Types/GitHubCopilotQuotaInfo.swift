import Foundation

public struct QuotaSnapshot: Codable, Equatable, Hashable {
    public var percentRemaining: Float
    public var unlimited: Bool
    public var overagePermitted: Bool
}

public struct GitHubCopilotQuotaInfo: Codable, Equatable, Hashable {
    public var chat: QuotaSnapshot
    public var completions: QuotaSnapshot
    public var premiumInteractions: QuotaSnapshot
    public var resetDate: String
    public var copilotPlan: String
    
    public var isFreeUser: Bool { copilotPlan == "free" }
}

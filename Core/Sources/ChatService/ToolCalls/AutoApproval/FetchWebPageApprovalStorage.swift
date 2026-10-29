import Foundation

struct FetchWebPageApprovalStorage {
    private var approvals: [ConversationID: Set<String>] = [:]

    mutating func allowURLs(conversationId: ConversationID, urls: [String]) {
        guard !conversationId.isEmpty else { return }
        let normalizedURLs = Set(urls.compactMap(normalize))
        guard !normalizedURLs.isEmpty else { return }
        approvals[conversationId, default: []].formUnion(normalizedURLs)
    }

    func areAllowed(conversationId: ConversationID, urls: [String]) -> Bool {
        guard !conversationId.isEmpty else { return false }
        let normalizedURLs = Set(urls.compactMap(normalize))
        guard !normalizedURLs.isEmpty,
              let approvedURLs = approvals[conversationId]
        else {
            return false
        }
        return normalizedURLs.isSubset(of: approvedURLs)
    }

    mutating func clear(conversationId: ConversationID) {
        guard !conversationId.isEmpty else { return }
        approvals.removeValue(forKey: conversationId)
    }

    private func normalize(_ url: String) -> String? {
        let normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedURL.isEmpty ? nil : normalizedURL
    }
}

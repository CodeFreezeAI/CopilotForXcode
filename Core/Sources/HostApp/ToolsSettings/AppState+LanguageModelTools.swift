import ConversationServiceProvider
import Foundation
import Persist

public let LANGUAGE_MODEL_TOOLS_STATUS = "languageModelToolsStatus"

extension AppState {
    public func getLanguageModelToolsStatus() -> [ToolStatusUpdate]? {
        guard let savedJSON = get(key: LANGUAGE_MODEL_TOOLS_STATUS),
              let data = try? JSONEncoder().encode(savedJSON),
              let savedStatus = try? JSONDecoder().decode([ToolStatusUpdate].self, from: data) else {
            return nil
        }
        return savedStatus
    }

    public func updateLanguageModelToolsStatus(_ updates: [ToolStatusUpdate]) {
        update(key: LANGUAGE_MODEL_TOOLS_STATUS, value: updates)
    }

    public func clearLanguageModelToolsStatus() {
        update(key: LANGUAGE_MODEL_TOOLS_STATUS, value: "")
    }
}

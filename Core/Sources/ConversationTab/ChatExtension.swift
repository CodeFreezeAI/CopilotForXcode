import ChatService
import ConversationServiceProvider

extension Chat.State {
    func buildSkillSet(isCurrentEditorContextEnabled: Bool) -> [ConversationSkill] {
        guard let currentFile = self.currentEditor, isCurrentEditorContextEnabled else {
            return []
        }
        let fileReference = ConversationFileReference(
            url: currentFile.url,
            relativePath: currentFile.relativePath,
            fileName: currentFile.fileName,
            isCurrentEditor: currentFile.isCurrentEditor,
            selection: currentFile.selection
        )
        return [CurrentEditorSkill(currentFile: fileReference), ProblemsInActiveDocumentSkill()]
    }
    
    func getChatContext(of mode: Chat.EditorMode) -> ChatContext {
        return editor.context(for: mode)
    }
    
    func getSubsequentMessages(after messageId: String) -> [DisplayedChatMessage] {
        conversation.subsequentMessages(after: messageId)
    }
}

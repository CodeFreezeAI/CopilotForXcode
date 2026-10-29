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
}

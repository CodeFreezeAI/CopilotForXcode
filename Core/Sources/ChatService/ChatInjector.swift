import SuggestionBasic
import AppKit
import XcodeInspector
import AXHelper
import ApplicationServices
import AppActivator
import LanguageServerProtocol

public struct ChatInjector {
    public init() {}
    
    public func insertCodeBlock(codeBlock: String) {
        do {
            guard let editorContent = XcodeInspector.shared.focusedEditor?.getContent(),
                  let focusElement = XcodeInspector.shared.focusedElement,
                  focusElement.description == "Source Editor"
            else { return }
            
            var cursorPosition = editorContent.cursorPosition
            guard cursorPosition.line >= 0, cursorPosition.character >= 0 else { return }
            
            var lines = editorContent.content.splitByNewLine(
                omittingEmptySubsequences: false
            ).map { String($0) }
            
            guard cursorPosition.line <= lines.count else { return }
            
            var modifications: [Modification] = []
            
            // Handle selection deletion
            if let selection = editorContent.selections.first,
               selection.isValid,
               selection.start.line < lines.endIndex {
                let selectionEndLine = min(selection.end.line, lines.count - 1)
                let deletedSelection = CursorRange(
                    start: selection.start,
                    end: .init(line: selectionEndLine, character: selection.end.character)
                )
                modifications.append(.deletedSelection(deletedSelection))
                lines = lines.applying([.deletedSelection(deletedSelection)])
                cursorPosition = selection.start
            }
            
            let insertionRange = CursorRange(
                start: cursorPosition,
                end: cursorPosition
            )
            
            try Self.performInsertion(
                content: codeBlock,
                range: insertionRange,
                lines: &lines,
                modifications: &modifications,
                focusElement: focusElement
            )
            
        } catch {
            print("Failed to insert code block: \(error)")
        }
    }
    
    public static func insertSuggestion(suggestion: String, range: CursorRange, lines: [String]) {
        do {
            guard let focusElement = XcodeInspector.shared.focusedElement,
                  focusElement.description == "Source Editor"
            else { return }

            guard range.start.line >= 0,
                  range.start.line < lines.count,
                  range.end.line >= 0,
                  range.end.line < lines.count
            else { return }
            
            var lines = lines
            var modifications: [Modification] = []
            
            if range.isValid {
                modifications.append(.deletedSelection(range))
                lines = lines.applying([.deletedSelection(range)])
            }
            
            try performInsertion(
                content: suggestion,
                range: range,
                lines: &lines,
                modifications: &modifications,
                focusElement: focusElement
            )
            
        } catch {
            print("Failed to insert suggestion: \(error)")
        }
    }
    
    private static func performInsertion(
        content: String,
        range: CursorRange,
        lines: inout [String],
        modifications: inout [Modification],
        focusElement: AXUIElement
    ) throws {
        let targetLine = lines[range.start.line]
        let leadingWhitespace = range.start.character > 0 ? targetLine.prefix { $0.isWhitespace } : ""
        let indentation = String(leadingWhitespace)
        
        let index = targetLine.index(targetLine.startIndex, offsetBy: min(range.start.character, targetLine.count))
        let before = targetLine[..<index]
        let after = targetLine[index...]
        
        let contentLines = content.splitByNewLine(
            omittingEmptySubsequences: false
        ).enumerated().map { (index, element) -> String in
            return index == 0 ? String(element) : indentation + String(element)
        }
        
        var toBeInsertedLines = [String]()
        if contentLines.count > 1 {
            toBeInsertedLines.append(String(before) + contentLines.first!)
            toBeInsertedLines.append(contentsOf: contentLines.dropFirst().dropLast())
            toBeInsertedLines.append(contentLines.last! + String(after))
        } else {
            toBeInsertedLines.append(String(before) + contentLines.first! + String(after))
        }
        
        lines.replaceSubrange((range.start.line)...(range.start.line), with: toBeInsertedLines)
        
        let newContent = String(lines.joined(separator: "\n"))
        let newCursorPosition = CursorPosition(
            line: range.start.line + contentLines.count - 1,
            character: contentLines.last?.count ?? 0
        )
        
        modifications.append(.inserted(range.start.line, toBeInsertedLines))
        
        try AXHelper().injectUpdatedCodeWithAccessibilityAPI(
            .init(
                content: newContent,
                newSelection: .cursor(newCursorPosition),
                modifications: modifications
            ),
            focusElement: focusElement,
            onSuccess: {
                NSWorkspace.activatePreviousActiveXcode()
            }
        )
    }
}

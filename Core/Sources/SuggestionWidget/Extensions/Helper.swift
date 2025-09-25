import AppKit

struct LocationStrategyHelper {
    
    /// `lineNumber` is 0-based
    static func getLineFrame(_ lineNumber: Int, in editor: AXUIElement, with lines: [String]) -> CGRect? {
        guard editor.isSourceEditor,
              lineNumber < lines.count && lineNumber >= 0
        else {
            return nil
        }
        
        var characterPosition = 0
        for i in 0..<lineNumber {
            // +1 for newline character
            characterPosition += lines[i].count + 1
        }
        
        var range = CFRange(location: characterPosition, length: lines[lineNumber].count)
        guard let rangeValue = AXValueCreate(AXValueType.cfRange, &range) else {
            return nil
        }
        
        guard let boundsValue: AXValue = try? editor.copyParameterizedValue(
            key: kAXBoundsForRangeParameterizedAttribute,
            parameters: rangeValue
        ) else {
            return nil
        }
        
        var rect = CGRect.zero
        let success = AXValueGetValue(boundsValue, .cgRect, &rect)
        
        return success ? rect : nil
    }
}

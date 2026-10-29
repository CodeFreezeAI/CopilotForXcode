import AppKit
import Foundation

public struct ScopeCache {
    var modelMultiplierCache: [String: String] = [:]
    var cachedMaxWidth: CGFloat = 0
    var lastModelsHash: Int = 0
}

// MARK: - Model Menu Item Formatting
public struct ModelMenuItemFormatter {
    public static let minimumPadding: Int = 24

    public static let attributes: [NSAttributedString.Key: NSFont] = [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]
    
    public static var spaceWidth: CGFloat {
        "\u{200A}".size(withAttributes: attributes).width
    }

    public static var minimumPaddingWidth: CGFloat {
        spaceWidth * CGFloat(minimumPadding)
    }

    /// Creates an attributed string for model menu items with proper spacing and formatting
    public static func createModelMenuItemAttributedString(
        modelName: String,
        isSelected: Bool,
        multiplierText: String,
        targetWidth: CGFloat? = nil,
        isDegraded: Bool = false
    ) -> AttributedString {
        let prefix: String
        if isDegraded {
            prefix = "⚠ "
        } else if isSelected {
            prefix = "✓ "
        } else {
            prefix = "    "
        }
        let displayName = "\(prefix)\(modelName)"

        var fullString = displayName
        var attributedString = AttributedString(fullString)

        if !multiplierText.isEmpty {
            let displayNameWidth = displayName.size(withAttributes: attributes).width
            let multiplierTextWidth = multiplierText.size(withAttributes: attributes).width

            // Calculate padding needed
            let neededPaddingWidth: CGFloat
            
            if let targetWidth = targetWidth {
                neededPaddingWidth = targetWidth - displayNameWidth - multiplierTextWidth
            } else {
                neededPaddingWidth = minimumPaddingWidth
            }
            
            let finalPaddingWidth = max(neededPaddingWidth, minimumPaddingWidth)
            let numberOfSpaces = Int(round(finalPaddingWidth / spaceWidth))
            let padding = String(repeating: "\u{200A}", count: max(minimumPadding, numberOfSpaces))
            fullString = "\(displayName)\(padding)\(multiplierText)"

            attributedString = AttributedString(fullString)

            if let range = attributedString.range(
                of: multiplierText,
                options: .backwards
            ) {
                attributedString[range].foregroundColor = .secondary
            }
        }

        return attributedString
    }
    
    /// Gets the trailing text for a model menu item.
    /// - BYOK models: provider name
    /// - Copilot models with token-based billing: "<context window> [· <thinking effort>] · <price category>"
    /// - Copilot models without token-based billing: "<multiplier>x"
    /// - Auto model: "Variable"
    public static func getMultiplierText(for model: LLMModel, reasoningEffort: String? = nil) -> String {
        if let providerName = model.providerName, !providerName.isEmpty {
            return providerName
        }
        if model.isAutoModel {
            return "Variable"
        }
        if model.billing?.tokenBasedBillingEnabled == true {
            var parts: [String] = []
            if let tokens = model.maxContextWindowTokens {
                parts.append(formatContextWindow(tokens))
            }
            if let effort = reasoningEffort, !effort.isEmpty, effort.lowercased() != "none" {
                parts.append(effort.capitalized)
            }
            if let category = model.modelPickerPriceCategory, !category.isEmpty {
                parts.append(priceCategorySymbol(category))
            }
            return parts.joined(separator: " · ")
        }
        if let multiplier = model.billing?.multiplier {
            return formatMultiplier(multiplier)
        }
        return ""
    }

    public static func priceCategorySymbol(_ category: String) -> String {
        switch category.lowercased() {
        case "low": return "$"
        case "medium": return "$$"
        case "high": return "$$$"
        default: return "$$$$"
        }
    }

    public static func formatContextWindow(_ count: Int) -> String {
        if count >= 1_000_000 {
            let m = Double(count) / 1_000_000.0
            return m.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0fM", m)
                : String(format: "%.1fM", m)
        }
        if count >= 1_000 {
            let k = Double(count) / 1_000.0
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0fK", k)
                : String(format: "%.1fK", k)
        }
        return "\(count)"
    }

    private static func formatMultiplier(_ multiplier: Float) -> String {
        if multiplier == 0 { return "Included" }
        return multiplier.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0fx", multiplier)
            : String(format: "%.2fx", multiplier)
    }

    /// Draws the standard menu-item highlight background (accent-colored rounded rect).
    static func drawMenuItemHighlight(
        in frame: NSRect,
        fontScale: Double,
        hoverEdgeInset: CGFloat
    ) {
        NSGraphicsContext.saveGraphicsState()
        NSColor.controlAccentColor.setFill()

        let cornerRadius: CGFloat
        if #available(macOS 26.0, *) {
            cornerRadius = 8.0 * fontScale
        } else {
            cornerRadius = 4.0 * fontScale
        }

        let hoverWidth = frame.width - (hoverEdgeInset * 2)
        let insetRect = NSRect(
            x: hoverEdgeInset,
            y: 0,
            width: hoverWidth,
            height: frame.height
        )
        let path = NSBezierPath(
            roundedRect: insetRect,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}

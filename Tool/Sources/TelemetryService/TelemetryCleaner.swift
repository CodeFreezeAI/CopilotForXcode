import Foundation

// reference the redact algorithm from https://github.com/microsoft/vscode/blame/main/src/vs/platform/telemetry/common/telemetryUtils.ts
public struct TelemetryCleaner {
    private let cleanupPatterns: [NSRegularExpression]

    public init(cleanupPatterns: [NSRegularExpression]) {
        self.cleanupPatterns = cleanupPatterns
    }

    public func redactMap(_ data: [String: Any]?) -> [String: Any]? {
        guard let data = data else {
            return nil
        }
        return data.mapValues { value in
            if let stringValue = value as? String {
                return redact(stringValue) ?? ""
            }

            return value
        }
    }

    public func redact(_ value: String?) -> String? {
        guard let value = value else {
            return nil
        }
        var cleanedValue = value.replacingOccurrences(of: "%20", with: " ")
        cleanedValue = anonymizeFilePaths(cleanedValue)
        cleanedValue = removeUserInfo(cleanedValue)
        return cleanedValue
    }

    private func anonymizeFilePaths(_ stack: String) -> String {
        guard stack.contains("/") || stack.contains("\\") else {
            return stack
        }

        var updatedStack = stack
        for pattern in cleanupPatterns {
            updatedStack = pattern.stringByReplacingMatches(
                in: updatedStack,
                range: NSRange(updatedStack.startIndex..., in: updatedStack),
                withTemplate: ""
            )
        }

        // Replace file paths with redacted marker
        let filePattern = try! NSRegularExpression(
            pattern: "(file:\\/\\/)?([a-zA-Z]:(\\\\|\\/)|(\\\\\\\\/|\\\\|\\/))?([\\w-\\._]+(\\\\|\\/))+"
        )
        updatedStack = filePattern.stringByReplacingMatches(
            in: updatedStack,
            range: NSRange(updatedStack.startIndex..., in: updatedStack),
            withTemplate: "<REDACTED: user-file-path>"
        )

        return updatedStack
    }

    private func removeUserInfo(_ value: String) -> String {
        let patterns: [(label: String, pattern: String)] = [
            ("Google API Key", "AIza[A-Za-z0-9_\\\\\\-]{35}"),
            ("Slack Token", "xox[pbar]\\-[A-Za-z0-9]"),
            ("GitHub Token", "(gh[psuro]_[a-zA-Z0-9]{36}|github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59})"),
            ("Generic Secret", "(key|token|sig|secret|signature|password|passwd|pwd|android:value)[^a-zA-Z0-9]"),
            ("CLI Credentials", "((login|psexec|(certutil|psexec)\\.exe).{1,50}(\\s-u(ser(name)?)?\\s+.{3,100})?\\s-(admin|user|vm|root)?p(ass(word)?)?\\s+[\"']?[^$\\-\\/\\s]|(^|[\\s\\r\\n\\])net(\\.exe)?.{1,5}(user\\s+|share\\s+\\/user:| user -? secrets ? set) \\s + [^ $\\s \\/])"),
            ("Microsoft Entra ID", "eyJ(?:0eXAiOiJKV1Qi|hbGci|[a-zA-Z0-9\\-_]+\\.[a-zA-Z0-9\\-_]+\\.)"),
            ("Email", "@[a-zA-Z0-9-]+\\.[a-zA-Z0-9-]+")
        ]

        let cleanedValue = value
        for (label, pattern) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                if regex.firstMatch(
                    in: cleanedValue,
                    range: NSRange(cleanedValue.startIndex..., in: cleanedValue)
                ) != nil {
                    return "<REDACTED: \(label)>"
                }
            }
        }

        return cleanedValue
    }
}

import Foundation
import SystemUtils

public struct GitShow {
    public static func showHeadContent(of filePath: String, repositoryURL: URL) -> String? {
        let escapedFilePath = Self.escapePath(filePath)
        let arguments = ["show", "HEAD:\(escapedFilePath)"]
        
        let result = try? SystemUtils.executeCommand(
            inDirectory: repositoryURL.path, 
            path: GitPath, 
            arguments: arguments
        )
        
        return result
    }
    
    private static func escapePath(_ string: String) -> String {
        let charactersToEscape = CharacterSet(charactersIn: " '\"&()[]{}$`\\|;<>*?~")
        return string.unicodeScalars.map { scalar in
            charactersToEscape.contains(scalar) ? "\\\(Character(scalar))" : String(Character(scalar))
        }.joined()
    }
}

import Foundation
import CryptoKit
import Logger

let BaseAppDirectory = "github-copilot/xcode"

/// String extension for hashing functionality
extension String {
    /// Generates a SHA256 hash of the string
    /// - Parameter length: The length of the hash to return, defaults to 16 characters
    /// - Returns: The hashed string
    func hashed(_ length: Int = 16) -> String {
        let data = Data(self.utf8)
        let hashData = SHA256.hash(data: data)
        let hashValue = hashData.compactMap { String(format: "%02x", $0 ) }.joined()
        let index = hashValue.index(hashValue.startIndex, offsetBy: length)
        return String(hashValue[..<index])
    }
}

/// Utilities for working with configuration file paths
struct ConfigPathUtils {
    
    /// Returns the XDG config home directory, respecting the XDG_CONFIG_HOME environment variable if set.
    /// Falls back to ~/.config if the environment variable is not set.
    static func getXdgConfigHome() -> URL {
        if let xdgConfigHome = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"],
           xdgConfigHome.hasPrefix("/") {
            return URL(fileURLWithPath: xdgConfigHome)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
    }
    
    /// Generates a config file path for a specific user.
    /// - Parameters:
    ///   - userName: The user name to generate a path for
    ///   - appDirectory: The application directory name, defaults to "github-copilot/xcode"
    ///   - fileName: The file name to append to the path
    /// - Returns: The complete URL for the config file
    static func configFilePath(
        userName: String,
        baseDirectory: String = BaseAppDirectory,
        subDirectory: String? = nil,
        fileName: String
    ) -> URL {
        var baseURL: URL = getXdgConfigHome()
            .appendingPathComponent(baseDirectory)
            .appendingPathComponent(toHash(contents: userName))
        
        if let subDirectory = subDirectory {
            baseURL = baseURL.appendingPathComponent(subDirectory)
        }
        
        ensureDirectoryExists(at: baseURL)
        return baseURL.appendingPathComponent(fileName)
    }
    
    /// Ensures a directory exists at the specified URL, creating it if necessary.
    /// - Parameter url: The directory URL
    private static func ensureDirectoryExists(at url: URL) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                if error.domain == NSPOSIXErrorDomain && error.code == EACCES {
                    Logger.client.error("Permission denied when trying to create directory: \(url.path)")
                } else {
                    Logger.client.info("Failed to create directory: \(error)")
                }
            }
        }
    }
    
    /// Generates a hash from a string using SHA256.
    /// - Parameters:
    ///   - contents: The string to hash
    ///   - length: The length of the hash to return, defaults to 16 characters
    /// - Returns: The hashed string
    static func toHash(contents: String, _ length: Int = 16) -> String {
        let data = Data(contents.utf8)
        let hashData = SHA256.hash(data: data)
        let hashValue = hashData.compactMap { String(format: "%02x", $0 ) }.joined()
        let index = hashValue.index(hashValue.startIndex, offsetBy: length)
        return String(hashValue[..<index])
    }
}

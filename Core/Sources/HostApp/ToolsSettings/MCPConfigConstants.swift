import Foundation

let configDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/github-copilot/xcode")
let mcpConfigFilePath = configDirectory.appendingPathComponent("mcp.json").path

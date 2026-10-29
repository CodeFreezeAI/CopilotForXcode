import Persist
import GitHubCopilotService
import Foundation

public let MCP_TOOLS_STATUS = "mcpToolsStatus"

extension AppState {
    public func getMCPToolsStatus() -> [UpdateMCPToolsStatusServerCollection]? {
        guard let savedJSON = get(key: MCP_TOOLS_STATUS),
              let data = try? JSONEncoder().encode(savedJSON),
              let savedStatus = try? JSONDecoder().decode([UpdateMCPToolsStatusServerCollection].self, from: data) else {
            return nil
        }
        return savedStatus
    }
    
    public func updateMCPToolsStatus(_ servers: [UpdateMCPToolsStatusServerCollection]) {
        var existingServers = getMCPToolsStatus() ?? []
        
        // Update or add servers
        for newServer in servers {
            if let existingIndex = existingServers.firstIndex(where: { $0.name == newServer.name }) {
                // Update existing server
                let updatedTools = mergeTools(original: existingServers[existingIndex].tools, new: newServer.tools)
                existingServers[existingIndex].tools = updatedTools
            } else {
                // Add new server
                existingServers.append(newServer)
            }
        }
        
        update(key: MCP_TOOLS_STATUS, value: existingServers)
    }
    
    private func mergeTools(original: [UpdatedMCPToolsStatus], new: [UpdatedMCPToolsStatus]) -> [UpdatedMCPToolsStatus] {
        var result = original
        
        for newTool in new {
            if let index = result.firstIndex(where: { $0.name == newTool.name }) {
                result[index].status = newTool.status
            } else {
                result.append(newTool)
            }
        }
        
        return result
    }

    public func createMCPToolsStatus(_ serverCollections: [MCPServerToolsCollection]) {
        var existingServers = getMCPToolsStatus() ?? []
        var serversChanged = false
        
        for serverCollection in serverCollections {
            // Find or create a server entry
            let serverIndex = existingServers.firstIndex(where: { $0.name == serverCollection.name })
            var toolsToUpdate: [UpdatedMCPToolsStatus]
            
            if let index = serverIndex {
                toolsToUpdate = existingServers[index].tools
            } else {
                toolsToUpdate = []
                serversChanged = true
            }
            
            // Add new tools with default enabled status
            let existingToolNames = Set(toolsToUpdate.map { $0.name })
            let newTools = serverCollection.tools
                .filter { !existingToolNames.contains($0.name) }
                .map { UpdatedMCPToolsStatus(name: $0.name, status: .enabled) }
            
            if !newTools.isEmpty {
                serversChanged = true
                toolsToUpdate.append(contentsOf: newTools)
            }
            
            // Update or add the server
            if let index = serverIndex {
                existingServers[index].tools = toolsToUpdate
            } else {
                existingServers.append(UpdateMCPToolsStatusServerCollection(
                    name: serverCollection.name,
                    tools: toolsToUpdate
                ))
            }
        }
        
        // Only update storage if changes were made
        if serversChanged {
            update(key: MCP_TOOLS_STATUS, value: existingServers)
        }
    }

    public func cleanupMCPToolsStatus(availableTools: [MCPServerToolsCollection]) {
        guard var existingServers = getMCPToolsStatus() else { return }
        
        // Get all available server names and their respective tool names
        let availableServerMap = Dictionary(
            uniqueKeysWithValues: availableTools.map { collection in
                (collection.name, Set(collection.tools.map { $0.name }))
            }
        )
        
        // Remove servers that don't exist in available tools
        existingServers.removeAll { !availableServerMap.keys.contains($0.name) }
        
        // For each remaining server, remove tools that don't exist in available tools
        for i in 0..<existingServers.count {
            if let availableToolNames = availableServerMap[existingServers[i].name] {
                existingServers[i].tools.removeAll { !availableToolNames.contains($0.name) }
            }
        }
        
        // Update the stored state
        update(key: MCP_TOOLS_STATUS, value: existingServers)
    }
}

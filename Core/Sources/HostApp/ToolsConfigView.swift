import Client
import Foundation
import Logger
import SharedUIComponents
import SwiftUI
import Toast
import ConversationServiceProvider
import GitHubCopilotService
import ComposableArchitecture

struct MCPConfigView: View {
    @State private var mcpConfig: String = ""
    @Environment(\.toast) var toast
    @State private var configFilePath: String = mcpConfigFilePath
    @State private var isMonitoring: Bool = false
    @State private var lastModificationDate: Date? = nil
    @State private var fileMonitorTask: Task<Void, Error>? = nil
    @State private var isMCPFFEnabled = false
    @State private var selectedOption = ToolType.MCP
    @Environment(\.colorScheme) var colorScheme

    private static var lastSyncTimestamp: Date? = nil
    
    enum ToolType: String, CaseIterable, Identifiable {
        case MCP, BuiltIn
        var id: Self { self }
    }

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                Picker("", selection: $selectedOption) {
                    Text("MCP").tag(ToolType.MCP)
                    Text("Built-In").tag(ToolType.BuiltIn)
                }
                .pickerStyle(.segmented)
                .frame(width: 400)
                
                Group {
                    if selectedOption == .MCP {
                        VStack(alignment: .leading, spacing: 8) {
                            MCPIntroView(isMCPFFEnabled: $isMCPFFEnabled)
                            if isMCPFFEnabled {
                                MCPManualInstallView()
                                MCPToolsListView()
                            }
                        }
                        .onAppear {
                            setupConfigFilePath()
                            Task {
                                await updateMCPFeatureFlag()
                            }
                        }
                        .onDisappear {
                            stopMonitoringConfigFile()
                        }
                        .onChange(of: isMCPFFEnabled) { newMCPFFEnabled in
                            if newMCPFFEnabled {
                                startMonitoringConfigFile()
                                refreshConfiguration(())
                            } else {
                                stopMonitoringConfigFile()
                            }
                        }
                        .onReceive(DistributedNotificationCenter.default()
                            .publisher(for: .gitHubCopilotFeatureFlagsDidChange)) { _ in
                                Task {
                                    await updateMCPFeatureFlag()
                                }
                            }
                    } else {
                        BuiltInToolsListView()
                    }
                }
                .padding(20)
            }
        }
    }
    
    private func updateMCPFeatureFlag() async {
        do {
            let service = try getService()
            if let featureFlags = try await service.getCopilotFeatureFlags() {
                isMCPFFEnabled = featureFlags.mcp
            }
        } catch {
            Logger.client.error("Failed to get copilot feature flags: \(error)")
        }
    }

    private func setupConfigFilePath() {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: configDirectory.path) {
            try? fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }

        // If the file doesn't exist, create one with a proper structure
        let configFileURL = URL(fileURLWithPath: configFilePath)
        if !fileManager.fileExists(atPath: configFilePath) {
            try? """
            {
                "servers": {
                    
                }
            }
            """.write(to: configFileURL, atomically: true, encoding: .utf8)
        }

        // Read the current content from file and ensure it's valid JSON
        mcpConfig = readAndValidateJSON(from: configFileURL) ?? "{}"

        // Get initial modification date
        lastModificationDate = getFileModificationDate(url: configFileURL)
    }

    /// Reads file content and validates it as JSON, returning only the "servers" object
    private func readAndValidateJSON(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        // Try to parse as JSON to validate
        do {
            // First verify it's valid JSON
            let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Extract the "servers" object
            guard let servers = jsonObject?["servers"] as? [String: Any] else {
                Logger.client.info("No 'servers' key found in MCP configuration")
                toast("No 'servers' key found in MCP configuration", .error)
                // Return empty object if no servers section
                return "{}"
            }

            // Convert the servers object back to JSON data
            let serversData = try JSONSerialization.data(
                withJSONObject: servers, options: [.prettyPrinted])

            // Return as a string
            return String(data: serversData, encoding: .utf8)
        } catch {
            // If parsing fails, return nil
            Logger.client.info("Parsing MCP JSON error: \(error)")
            toast("Invalid JSON in MCP configuration file", .error)
            return nil
        }
    }

    private func getFileModificationDate(url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }

    private func startMonitoringConfigFile() {
        stopMonitoringConfigFile()  // Stop existing monitoring if any

        isMonitoring = true

        fileMonitorTask = Task {
            let configFileURL = URL(fileURLWithPath: configFilePath)

            // Check for file changes periodically
            while isMonitoring {
                try? await Task.sleep(nanoseconds: 3_000_000_000)  // Check every 3 seconds

                let currentDate = getFileModificationDate(url: configFileURL)

                if let currentDate = currentDate, currentDate != lastModificationDate {
                    // File modification date has changed, update our record
                    lastModificationDate = currentDate

                    // Read and validate the updated content
                    if let validJson = readAndValidateJSON(from: configFileURL) {
                        await MainActor.run {
                            mcpConfig = validJson
                            refreshConfiguration(validJson)
                            toast("MCP configuration file updated", .info)
                        }
                    } else {
                        // If JSON is invalid, show error
                        await MainActor.run {
                            toast("Invalid JSON in MCP configuration file", .error)
                        }
                    }
                }
            }
        }
    }

    private func stopMonitoringConfigFile() {
        isMonitoring = false
        fileMonitorTask?.cancel()
        fileMonitorTask = nil
    }

    func refreshConfiguration(_: Any) {
        if MCPConfigView.lastSyncTimestamp == lastModificationDate {
            return
        }

        MCPConfigView.lastSyncTimestamp = lastModificationDate

        let fileURL = URL(fileURLWithPath: configFilePath)
        if let jsonString = readAndValidateJSON(from: fileURL) {
            UserDefaults.shared.set(jsonString, for: \.gitHubCopilotMCPConfig)
        }

        Task {
            do {
                let service = try getService()
                try await service.postNotification(
                    name: Notification.Name
                        .gitHubCopilotShouldRefreshEditorInformation.rawValue
                )
                toast("MCP configuration updated", .info)
            } catch {
                toast(error.localizedDescription, .error)
            }
        }
    }
}

#Preview {
    MCPConfigView()
        .frame(width: 800, height: 600)
}

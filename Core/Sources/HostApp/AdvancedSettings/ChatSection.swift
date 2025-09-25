import Client
import ComposableArchitecture
import SwiftUI
import Toast
import XcodeInspector
import SharedUIComponents
import Logger

struct ChatSection: View {
    @AppStorage(\.autoAttachChatToXcode) var autoAttachChatToXcode
    @AppStorage(\.enableFixError) var enableFixError
    @State private var isEditorPreviewEnabled: Bool = false

    var body: some View {
        SettingsSection(title: "Chat Settings") {
            // Copilot instructions - .github/copilot-instructions.md
            CopilotInstructionSetting()
                .padding(SettingsToggle.defaultPadding)

            Divider()

            // Custom Instructions - .github/instructions/*.instructions.md
            PromptFileSetting(promptType: .instructions)
                .padding(SettingsToggle.defaultPadding)

            Divider()

            if isEditorPreviewEnabled {
                // Custom Prompts - .github/prompts/*.prompt.md
                PromptFileSetting(promptType: .prompt)
                    .padding(SettingsToggle.defaultPadding)

                Divider()
            }
            
            // Auto Attach toggle
            SettingsToggle(
                title: "Auto-attach Chat Window to Xcode",
                isOn: $autoAttachChatToXcode
            )

            Divider()
            
            // Fix error toggle
            SettingsToggle(
                title: "Quick fix for error", 
                isOn: $enableFixError
            )
            
            Divider()

            // Response language picker
            ResponseLanguageSetting()
                .padding(SettingsToggle.defaultPadding)
            
            Divider()
            
            // Font Size
            FontSizeSetting()
                .padding(SettingsToggle.defaultPadding)
        }
        .onAppear {
            Task {
                await updateEditorPreviewFeatureFlag()
            }
        }
        .onReceive(DistributedNotificationCenter.default()
            .publisher(for: .gitHubCopilotFeatureFlagsDidChange)) { _ in
                Task {
                    await updateEditorPreviewFeatureFlag()
                }
            }
    }
    
    private func updateEditorPreviewFeatureFlag() async {
        do {
            let service = try getService()
            if let featureFlags = try await service.getCopilotFeatureFlags() {
                isEditorPreviewEnabled = featureFlags.editorPreviewFeatures
            }
        } catch {
            Logger.client.error("Failed to get copilot feature flags: \(error)")
        }
    }
}

struct ResponseLanguageSetting: View {
    @AppStorage(\.chatResponseLocale) var chatResponseLocale

    // Locale codes mapped to language display names
    // reference: https://code.visualstudio.com/docs/configure/locales#_available-locales
    private let localeLanguageMap: [String: String] = [
        "en": "English",
        "zh-cn": "Chinese, Simplified",
        "zh-tw": "Chinese, Traditional",
        "fr": "French",
        "de": "German",
        "it": "Italian",
        "es": "Spanish",
        "ja": "Japanese",
        "ko": "Korean",
        "ru": "Russian",
        "pt-br": "Portuguese (Brazil)",
        "tr": "Turkish",
        "pl": "Polish",
        "cs": "Czech",
        "hu": "Hungarian",
    ]

    var selectedLanguage: String {
        if chatResponseLocale == "" {
            return "English"
        }

        return localeLanguageMap[chatResponseLocale] ?? "English"
    }

    // Display name to locale code mapping (for the picker UI)
    var sortedLanguageOptions: [(displayName: String, localeCode: String)] {
        localeLanguageMap.map { (displayName: $0.value, localeCode: $0.key) }
            .sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        WithPerceptionTracking {
            HStack {
                VStack(alignment: .leading) {
                    Text("Response Language")
                        .font(.body)
                    Text("This change applies only to new chat sessions. Existing ones won't be impacted.")
                        .font(.footnote)
                }

                Spacer()

                Picker("", selection: $chatResponseLocale) {
                    ForEach(sortedLanguageOptions, id: \.localeCode) { option in
                        Text(option.displayName).tag(option.localeCode)
                    }
                }
                .frame(maxWidth: 200, alignment: .trailing)
            }
        }
    }
}

struct FontSizeSetting: View {
    static let defaultSliderThumbRadius: CGFloat = Font.body.builtinSize
    
    @AppStorage(\.chatFontSize) var chatFontSize
    @ScaledMetric(relativeTo: .body) var scaledPadding: CGFloat = 100
    
    @State private var sliderValue: Double = 0
    @State private var textWidth: CGFloat = 0
    @State private var sliderWidth: CGFloat = 0
    
    @StateObject private var fontScaleManager: FontScaleManager = .shared
    
    var maxSliderValue: Double {
        FontScaleManager.maxScale * 100
    }
    
    var minSliderValue: Double {
        FontScaleManager.minScale * 100
    }
    
    var defaultSliderValue: Double {
        FontScaleManager.defaultScale * 100
    }
    
    var sliderFontSize: Double {
        chatFontSize * sliderValue / 100
    }
    
    var maxScaleFontSize: Double {
        FontScaleManager.maxScale * chatFontSize
    }
    
    var body: some View {
        WithPerceptionTracking {
            HStack {
                VStack(alignment: .leading) {
                    Text("Font Size")
                        .font(.body)
                    Text("Use the slider to set the preferred size.")
                        .font(.footnote)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 8) {
                        Text("A")
                            .font(.system(size: sliderFontSize))
                            .frame(width: maxScaleFontSize)
                        
                        Slider(value: $sliderValue, in: minSliderValue...maxSliderValue, step: 10) { _ in
                            fontScaleManager.setFontScale(sliderValue / 100)
                        }
                        .background(
                            GeometryReader { geometry in 
                                Color.clear
                                    .onAppear {
                                        sliderWidth = geometry.size.width
                                    }
                            }
                        )
                        
                        Text("\(Int(sliderValue))%")
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(width: 40, alignment: .center)
                    }
                    .frame(height: maxScaleFontSize)
                    
                    Text("Default")
                        .font(.caption)
                        .foregroundColor(.primary)
                        .background(
                            GeometryReader { geometry in 
                                Color.clear
                                    .onAppear {
                                        textWidth = geometry.size.width
                                    }
                            }
                        )
                        .padding(.leading, calculateDefaultMarkerXPosition() + 6)
                        .onHover {
                            if $0 {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .onTapGesture {
                            fontScaleManager.resetFontScale()
                        }
                }
                .frame(width: 350, height: 35)
            }
            .onAppear {
                sliderValue = fontScaleManager.currentScale * 100
            }
            .onChange(of: fontScaleManager.currentScale) {
                // Use rounded value for floating-point precision issue
                sliderValue = round($0 * 10) / 10 * 100
            }
        }
    }
    
    private func calculateDefaultMarkerXPosition() -> CGFloat {
        let sliderRange = maxSliderValue - minSliderValue
        let normalizedPosition = (defaultSliderValue - minSliderValue) / sliderRange
        
        let usableWidth = sliderWidth - (Self.defaultSliderThumbRadius * 2)
        
        let markerPosition = Self.defaultSliderThumbRadius + (CGFloat(normalizedPosition) * usableWidth)
        
        return markerPosition - textWidth / 2 + maxScaleFontSize
    }
}

struct CopilotInstructionSetting: View {
    @State var isGlobalInstructionsViewOpen = false
    @Environment(\.toast) var toast

    var body: some View {
        WithPerceptionTracking {
            HStack {
                VStack(alignment: .leading) {
                    Text("Copilot Instructions")
                        .font(.body)
                    Text("Configure `.github/copilot-instructions.md` to apply to all chat requests.")
                        .font(.footnote)
                }

                Spacer()

                Button("Current Workspace") {
                    openCustomInstructions()
                }

                Button("Global") {
                    isGlobalInstructionsViewOpen = true
                }
            }
            .sheet(isPresented: $isGlobalInstructionsViewOpen) {
                GlobalInstructionsView(isOpen: $isGlobalInstructionsViewOpen)
            }
        }
    }

    func openCustomInstructions() {
        Task {
            guard let projectURL = await getCurrentProjectURL() else {
                toast("No active workspace found", .error)
                return
            }

            let configFile = projectURL.appendingPathComponent(".github/copilot-instructions.md")

            // If the file doesn't exist, create one with a proper structure
            if !FileManager.default.fileExists(atPath: configFile.path) {
                do {
                    // Create directory if it doesn't exist using reusable helper
                    let gitHubDir = projectURL.appendingPathComponent(".github")
                    try ensureDirectoryExists(at: gitHubDir)

                    // Create empty file
                    try "".write(to: configFile, atomically: true, encoding: .utf8)
                } catch {
                    toast("Failed to create config file .github/copilot-instructions.md: \(error)", .error)
                }
            }

            if FileManager.default.fileExists(atPath: configFile.path) {
                NSWorkspace.shared.open(configFile)
            }
        }
    }
}

struct PromptFileSetting: View {
    let promptType: PromptType
    @State private var isCreateSheetPresented = false
    @Environment(\.toast) var toast

    var body: some View {
        WithPerceptionTracking {
            HStack {
                VStack(alignment: .leading) {
                    Text(promptType.settingTitle)
                        .font(.body)
                    Text(
                        (try? AttributedString(markdown: promptType.description)) ?? AttributedString(
                            promptType.description
                        )
                    )
                    .font(.footnote)
                }

                Spacer()

                Button("Create") {
                    isCreateSheetPresented = true
                }

                Button("Open \(promptType.directoryName.capitalized) Folder") {
                    openDirectory()
                }
            }
            .sheet(isPresented: $isCreateSheetPresented) {
                CreateCustomCopilotFileView(
                    isOpen: $isCreateSheetPresented,
                    promptType: promptType
                )
            }
        }
    }

    private func openDirectory() {
        Task {
            guard let projectURL = await getCurrentProjectURL() else {
                toast("No active workspace found", .error)
                return
            }

            let directory = promptType.getDirectoryPath(projectURL: projectURL)

            do {
                try ensureDirectoryExists(at: directory)
                NSWorkspace.shared.open(directory)
            } catch {
                toast("Failed to create \(promptType.directoryName) directory: \(error)", .error)
            }
        }
    }
}

#Preview {
    ChatSection()
        .frame(width: 600)
}

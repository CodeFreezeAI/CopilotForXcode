# Copilot Agent Instructions for GitHub Copilot for Xcode

## Project Overview
- **Purpose:** This project is an Xcode extension and companion app that brings GitHub Copilot's AI code suggestions and chat to Xcode, with deep integration for inline completions, chat, and agent-driven codebase modifications.
- **Architecture:**
  - **Core/**: Swift Package containing main business logic, services, and UI components. Organized by feature (e.g., `ChatService`, `SuggestionService`, `PromptToCodeService`).
  - **EditorExtension/**: Implements Xcode Source Editor Extension commands (e.g., Accept/Reject Suggestion, Open Chat, etc.).
  - **CommunicationBridge/**: Handles XPC communication between the main app and extension services.
  - **ExtensionService/**: Manages the lifecycle and UI of the extension's background service.
  - **Server/**: Node.js backend for advanced features (optional, rarely modified).
  - **Docs/**: Images and documentation assets.

## Key Workflows
- **Build & Run:**
  - Open `Copilot for Xcode.xcworkspace` in Xcode.
  - Build the `GitHub Copilot for Xcode` app target for macOS 12+.
  - The extension is enabled via System Preferences > Extensions > Xcode Source Editor.
- **Testing:**
  - Run Swift Package tests from the `Core/` directory using Xcode or `swift test`.
- **Debugging:**
  - Use the `CommunicationBridge` and `ExtensionService` logs for troubleshooting XPC and extension issues.
  - See `TROUBLESHOOTING.md` for permission and integration issues.

## Project Conventions
- **Feature Folders:** Each major feature in `Core/Sources/` is a separate folder with its own logic and tests.
- **Dependency Injection:** Uses [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) and [Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) for state and effect management.
- **XPC Communication:** All cross-process calls use protocols in `Tool/` and are implemented in `CommunicationBridge/` and `ExtensionService/`.
- **Permissions:** Requires `Accessibility`, `Background`, and `Xcode Source Editor Extension` permissions. See `TROUBLESHOOTING.md` for details.
- **External Packages:** Managed in `Core/Package.swift`. Do not add dependencies directly to Xcode project files.

## Integration Points
- **Xcode Extension:** Commands in `EditorExtension/` are registered in `Info.plist` and invoked via the Xcode Editor menu.
- **App ↔ Extension:** Communication via XPC, with protocols defined in `Tool/` and implemented in `CommunicationBridge/ServiceDelegate.swift`.
- **Updates:** Uses [Sparkle](https://sparkle-project.org/) for in-app updates.

## Examples
- To add a new chat feature: create a folder in `Core/Sources/`, add logic, register in `Package.swift`, and connect via the appropriate service.
- To add a new editor command: implement in `EditorExtension/`, update `Info.plist`, and test in Xcode.

## References
- See `README.md` for user setup and onboarding.
- See `TROUBLESHOOTING.md` for common integration and permission issues.
- See `Core/Package.swift` for dependency and target structure.

---
For questions about unclear patterns or missing documentation, ask for clarification or check the latest onboarding docs in `Docs/`.

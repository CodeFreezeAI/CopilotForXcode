import Client
import SwiftUI
import XcodeInspector

struct CreateCustomCopilotFileView: View {
    var isOpen: Binding<Bool>
    let promptType: PromptType

    @State private var fileName = ""
    @State private var projectURL: URL?
    @State private var fileAlreadyExists = false

    @Environment(\.toast) var toast

    init(isOpen: Binding<Bool>, promptType: PromptType) {
        self.isOpen = isOpen
        self.promptType = promptType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Button(action: { self.isOpen.wrappedValue = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                .buttonStyle(.plain)

                Text("Create \(promptType.displayName)")
                    .font(.system(size: 13, weight: .bold))
                Spacer()

                AdaptiveHelpLink(action: openHelpLink)
                    .padding()
            }
            .frame(height: 28)
            .background(Color(nsColor: .separatorColor))

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter the name of \(promptType.rawValue) file:")
                    .font(.body)

                TextField("File name", text: $fileName)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await createPromptFile() }
                    }
                    .onChange(of: fileName) { _ in
                        updateFileExistence()
                    }

                validationMessageView

                Spacer()

                HStack(spacing: 12) {
                    Spacer()

                    Button("Cancel") {
                        self.isOpen.wrappedValue = false
                    }
                    .buttonStyle(.bordered)

                    Button("Create") {
                        Task { await createPromptFile() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(disableCreateButton)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
        }
        .frame(width: 350, height: 160)
        .onAppear {
            fileName = ""
            Task { await resolveProjectURL() }
        }
    }

    // MARK: - Derived values

    private var trimmedFileName: String {
        fileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var disableCreateButton: Bool {
        trimmedFileName.isEmpty || fileAlreadyExists
    }

    @ViewBuilder
    private var validationMessageView: some View {
        HStack(alignment: .center, spacing: 6) {
            if fileAlreadyExists && !trimmedFileName.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("'.github/\(promptType.directoryName)/\(trimmedFileName)\(promptType.fileExtension)' already exists")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            } else if trimmedFileName.isEmpty {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Enter a file name")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(".github/\(promptType.directoryName)/\(trimmedFileName)\(promptType.fileExtension)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Actions / Helpers

    private func openHelpLink() {
        if let url = URL(string: promptType.helpLink) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Resolves the active project URL (if any) and updates state.
    private func resolveProjectURL() async {
        let projectURL = await getCurrentProjectURL()
        await MainActor.run {
            self.projectURL = projectURL
            updateFileExistence()
        }
    }

    private func updateFileExistence() {
        let name = trimmedFileName
        guard !name.isEmpty, let projectURL else {
            fileAlreadyExists = false
            return
        }
        let filePath = promptType.getFilePath(fileName: name, projectURL: projectURL)
        fileAlreadyExists = FileManager.default.fileExists(atPath: filePath.path)
    }

    /// Creates the prompt file if it doesn't already exist.
    private func createPromptFile() async {
        guard let projectURL else {
            await MainActor.run {
                toast("No active workspace found", .error)
            }
            return
        }

        let directoryPath = promptType.getDirectoryPath(projectURL: projectURL)
        let filePath = promptType.getFilePath(fileName: trimmedFileName, projectURL: projectURL)

        // Re-check existence to avoid race with external creation.
        if FileManager.default.fileExists(atPath: filePath.path) {
            await MainActor.run {
                self.fileAlreadyExists = true
                toast("\(promptType.displayName) '\(trimmedFileName)\(promptType.fileExtension)' already exists", .warning)
            }
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: directoryPath,
                withIntermediateDirectories: true
            )

            try promptType.defaultTemplate.write(to: filePath, atomically: true, encoding: .utf8)

            await MainActor.run {
                toast("Created \(promptType.rawValue) file '\(trimmedFileName)\(promptType.fileExtension)'", .info)
                NSWorkspace.shared.open(filePath)
                self.isOpen.wrappedValue = false
            }
        } catch {
            await MainActor.run {
                toast("Failed to create \(promptType.rawValue) file: \(error)", .error)
            }
        }
    }
}

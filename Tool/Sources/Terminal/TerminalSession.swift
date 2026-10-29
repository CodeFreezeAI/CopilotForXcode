import Foundation
import SystemUtils
import Logger
import Combine

/**
 * Manages shell processes for terminal emulation
 */
class ShellProcessManager {
    private var process: Process?
    private var outputPipe: Pipe?
    private var inputPipe: Pipe?
    private var isRunning = false
    var onOutputReceived: ((String) -> Void)?

    private let shellIntegrationScript = """
    # Shell integration for tracking command execution and exit codes
    __terminal_command_start() {
        printf "\\033]133;C\\007"  # Command started
    }

    __terminal_command_finished() {
        local EXIT="$?"
        printf "\\033]133;D;%d\\007" "$EXIT"  # Command finished with exit code
        return $EXIT
    }

    # Set up precmd and preexec hooks
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd __terminal_command_finished
    add-zsh-hook preexec __terminal_command_start

    # print the initial prompt to output
    echo -n 
    """
    
    /**
     * Starts a shell process
     */
    func startShell(inDirectory directory: String = NSHomeDirectory()) {
        guard !isRunning else { return }
        
        process = Process()
        outputPipe = Pipe()
        inputPipe = Pipe()
        
        // Configure the process
        process?.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process?.arguments = ["-i", "-l"]
        
        // Create temporary file for shell integration
        let tempDir = FileManager.default.temporaryDirectory
        let copilotZshPath = tempDir.appendingPathComponent("xcode-copilot-zsh")

        var zshdir = tempDir
        if !FileManager.default.fileExists(atPath: copilotZshPath.path) {
            do {
                try FileManager.default.createDirectory(at: copilotZshPath, withIntermediateDirectories: true, attributes: nil)
                zshdir = copilotZshPath
            } catch {
                Logger.client.info("Error creating zsh directory: \(error.localizedDescription)")
            }
        } else {
            zshdir = copilotZshPath
        }

        let integrationFile = zshdir.appendingPathComponent("shell_integration.zsh")
        try? shellIntegrationScript.write(to: integrationFile, atomically: true, encoding: .utf8)
        
        var environment = ProcessInfo.processInfo.environment
        // Fetch login shell environment to get correct PATH
        if let shellEnv = SystemUtils.shared.getLoginShellEnvironment(shellPath: "/bin/zsh") {
            for (key, value) in shellEnv {
                environment[key] = value
            }
        }
        // Append common bin paths to PATH
        environment["PATH"] = SystemUtils.shared.appendCommonBinPaths(path: environment["PATH"] ?? "")

        let userZdotdir = environment["ZDOTDIR"] ?? NSHomeDirectory()
        environment["ZDOTDIR"] = zshdir.path
        environment["USER_ZDOTDIR"] = userZdotdir
        environment["SHELL_INTEGRATION"] = integrationFile.path
        process?.environment = environment
        
        // Source shell integration in zsh startup
        let zshrcContent = "source \"$SHELL_INTEGRATION\"\n"
        try? zshrcContent.write(to: zshdir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

        process?.standardOutput = outputPipe
        process?.standardError = outputPipe
        process?.standardInput = inputPipe
        process?.currentDirectoryURL = URL(fileURLWithPath: directory)
        
        // Handle output from the process
        outputPipe?.fileHandleForReading.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.onOutputReceived?(output)
                }
            }
        }

        do {
            try process?.run()
            isRunning = true
        } catch {
            onOutputReceived?("Failed to start shell: \(error.localizedDescription)\r\n")
            Logger.client.error("Failed to start shell: \(error.localizedDescription)")
        }
    }

    /**
     * Sends a command to the shell process
     * @param command The command to send
     */
    func sendCommand(_ command: String) {
        guard isRunning, let inputPipe = inputPipe else { return }
        
        if let data = (command).data(using: .utf8) {
            try? inputPipe.fileHandleForWriting.write(contentsOf: data)
        }
    }

    func stopCommand() {
        // Send SIGINT (Ctrl+C) to the running process
        guard let process = process else { return }
        process.interrupt() // Sends SIGINT to the process
    }

    /**
     * Terminates the shell process
     */
    func terminateShell() {
        guard isRunning else { return }
        
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        isRunning = false
    }
    
    deinit {
        terminateShell()
    }
}

public struct CommandExecutionResult {
    public let success: Bool
    public let output: String
}

public class TerminalSession: ObservableObject {
    @Published public var terminalOutput = ""
    
    private var shellManager = ShellProcessManager()
    private var hasPendingCommand = false
    private var pendingCommandResult = ""
    // Add command completion handler
    private var onCommandCompleted: ((CommandExecutionResult) -> Void)?

    init() {
        // Set up the shell process manager to handle shell output
        shellManager.onOutputReceived = { [weak self] output in
            self?.handleShellOutput(output)
        }
    }

    public func executeCommand(currentDirectory: String, command: String, completion: @escaping (CommandExecutionResult) -> Void) {
        onCommandCompleted = completion
        pendingCommandResult = ""

        // Start shell in the requested directory
        self.shellManager.startShell(inDirectory: currentDirectory.isEmpty ? NSHomeDirectory() : currentDirectory)

        // Wait for shell prompt to appear before sending command
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.terminalOutput += "\(command)\n"
            self?.shellManager.sendCommand(command + "\n")
            self?.hasPendingCommand = true
        }
    }

    /**
     * Handles input from the terminal view
     * @param input Input received from terminal
     */
    public func handleTerminalInput(_ input: String) {
        DispatchQueue.main.async { [weak self] in
            if input.contains("\u{03}") { // CTRL+C
                let newInput = input.replacingOccurrences(of: "\u{03}", with: "\n")
                self?.terminalOutput += newInput
                self?.shellManager.stopCommand()
                self?.shellManager.sendCommand("\n")
                return
            }

            // Echo the input to the terminal
            self?.terminalOutput += input
            self?.shellManager.sendCommand(input)
        }
    }

    public func getCommandOutput() -> String {
        return self.pendingCommandResult
    }

    /**
     * Handles output from the shell process
     * @param output Output from shell process
     */
    private func handleShellOutput(_ output: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.terminalOutput += output
            // Look for shell integration escape sequences
            if output.contains("\u{1B}]133;D;0\u{07}") && self.hasPendingCommand {
                // Command succeeded
                self.onCommandCompleted?(CommandExecutionResult(success: true, output: self.pendingCommandResult))
                self.hasPendingCommand = false
            } else if output.contains("\u{1B}]133;D;") && self.hasPendingCommand {
                // Command failed
                self.onCommandCompleted?(CommandExecutionResult(success: false, output: self.pendingCommandResult))
                self.hasPendingCommand = false
            } else if output.contains("\u{1B}]133;C\u{07}") {
                // Command start
            } else if self.hasPendingCommand {
                self.pendingCommandResult += output
            }
        }
    }

    public func cleanup() {
        shellManager.terminateShell()
    }
}

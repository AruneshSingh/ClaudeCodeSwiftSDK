// Process lifecycle management for Claude Code CLI subprocess

import Foundation
import Darwin

/// Manages the lifecycle of a Claude Code CLI subprocess
actor ProcessManager {
    
    // MARK: - State Management
    
    /// Current state of the process
    private var state: ProcessState = .idle
    
    /// The CLI executable path
    private let cliPath: URL
    
    /// Currently running process
    private var process: Process?
    
    /// Standard I/O pipes
    private var outputPipe: Pipe?
    private var inputPipe: Pipe?
    private var stderrFile: FileHandle?
    private var stderrTempPath: URL?
    
    /// Background task management
    private var backgroundTasks: Set<Task<Void, Never>> = []
    
    // MARK: - Types
    
    enum ProcessState {
        case idle
        case starting
        case running
        case terminating
        case terminated
    }
    
    /// Process configuration for starting
    struct ProcessConfig {
        let arguments: [String]
        let workingDirectory: URL?
        let environment: [String: String]
        let isStreaming: Bool
        
        init(arguments: [String], workingDirectory: URL? = nil, environment: [String: String] = [:], isStreaming: Bool = false) {
            self.arguments = arguments
            self.workingDirectory = workingDirectory
            self.environment = environment
            self.isStreaming = isStreaming
        }
    }
    
    /// Process I/O handles for communication
    struct ProcessIO {
        let outputPipe: Pipe
        let inputPipe: Pipe
        let stderrFile: FileHandle
        let stderrTempPath: URL
    }
    
    // MARK: - Initialization
    
    init(cliPath: URL) {
        self.cliPath = cliPath
    }
    
    deinit {
        // Note: Can't call async cleanup from deinit
        // Swift's actor deinitialization handles cleanup automatically
    }
    
    // MARK: - Process Lifecycle
    
    /// Start a new process with the given configuration
    /// - Parameter config: Process configuration
    /// - Returns: Process I/O handles for communication
    /// - Throws: ClaudeSDKError if process cannot be started
    func startProcess(config: ProcessConfig) async throws -> ProcessIO {
        // Ensure any previous process is terminated
        await cleanup()
        
        // Check if we can start a new process
        guard state == .terminated || state == .idle else {
            throw ClaudeSDKError.invalidConfiguration(reason: "Process is in invalid state for starting: \(state)")
        }
        
        state = .starting
        
        // Create new process
        let process = Process()
        process.executableURL = cliPath
        process.arguments = config.arguments
        
        // Set up pipes
        let outputPipe = Pipe()
        let inputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardInput = inputPipe
        
        // Create temp file for stderr
        let stderrPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("claude_stderr_\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: stderrPath.path, contents: nil)
        
        let stderrFile: FileHandle
        do {
            stderrFile = try FileHandle(forWritingTo: stderrPath)
        } catch {
            // Clean up temp file if FileHandle creation fails
            try? FileManager.default.removeItem(at: stderrPath)
            throw ClaudeSDKError.cliConnectionError(underlying: error)
        }
        process.standardError = stderrFile
        
        // Store references
        self.process = process
        self.outputPipe = outputPipe
        self.inputPipe = inputPipe
        self.stderrFile = stderrFile
        self.stderrTempPath = stderrPath
        
        // Set environment variables
        var env = config.environment
        if env["CLAUDE_CODE_ENTRYPOINT"] == nil {
            env["CLAUDE_CODE_ENTRYPOINT"] = "sdk-swift"
        }
        process.environment = env
        
        // Set working directory if specified
        if let cwd = config.workingDirectory {
            process.currentDirectoryURL = cwd
        }
        
        // Start the process
        do {
            try process.run()
            state = .running
        } catch {
            state = .idle
            await cleanup()
            throw ClaudeSDKError.cliConnectionError(underlying: error)
        }
        
        return ProcessIO(
            outputPipe: outputPipe,
            inputPipe: inputPipe,
            stderrFile: stderrFile,
            stderrTempPath: stderrPath
        )
    }
    
    /// Get the process ID if running
    /// - Returns: Process ID or nil if not running
    func getProcessId() async -> Int32? {
        return process?.processIdentifier
    }
    
    /// Get current process state
    /// - Returns: Current state
    func getState() async -> ProcessState {
        return state
    }
    
    /// Check if process is currently running
    /// - Returns: True if process is running
    func isRunning() async -> Bool {
        guard let process = process else { return false }
        return process.isRunning && state == .running
    }
    
    /// Write data to stdin
    /// - Parameter data: Data to write
    /// - Throws: ClaudeSDKError if writing fails
    func writeToStdin(_ data: Data) async throws {
        guard let inputPipe = inputPipe else {
            throw ClaudeSDKError.invalidConfiguration(reason: "stdin not available")
        }
        
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
    }
    
    /// Close stdin
    /// - Throws: ClaudeSDKError if closing fails
    func closeStdin() async throws {
        guard let inputPipe = inputPipe else { return }
        try inputPipe.fileHandleForWriting.close()
        self.inputPipe = nil
    }
    
    /// Wait for process completion and get exit status
    /// - Returns: Exit code of the process
    func waitForCompletion() async -> Int32 {
        guard let process = process else { return -1 }
        
        return await withCheckedContinuation { continuation in
            Task {
                await Task.detached {
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus)
                }.value
            }
        }
    }
    
    /// Get stderr content if process failed
    /// - Returns: stderr content as string, or empty string if none
    func getStderrContent() async -> String {
        guard let stderrPath = stderrTempPath,
              let stderrData = try? Data(contentsOf: stderrPath),
              let stderr = String(data: stderrData, encoding: .utf8) else {
            return ""
        }
        return stderr
    }
    
    /// Interrupt the process (SIGINT)
    func interrupt() async {
        guard let process = process, process.isRunning else { return }
        process.interrupt()
    }
    
    /// Terminate the process gracefully, then forcefully if needed
    func terminate() async {
        await cleanup()
    }
    
    // MARK: - Private Methods
    
    /// Clean up process and resources with timeout
    private func cleanup() async {
        // Prevent multiple cleanup calls
        guard state != .terminating && state != .terminated else {
            return
        }
        
        // Cancel all background tasks first
        for task in backgroundTasks {
            task.cancel()
        }
        backgroundTasks.removeAll()
        
        // Update state to prevent new operations
        state = .terminating
        
        // Close all file handles first to prevent resource leaks
        if let outputHandle = outputPipe?.fileHandleForReading {
            try? outputHandle.close()
        }
        if let inputHandle = inputPipe?.fileHandleForWriting {
            try? inputHandle.close()
        }
        if let stderr = stderrFile {
            try? stderr.close()
        }
        
        // Terminate process gracefully with timeout
        if let process = process, state != .terminated {
            process.terminate()
            
            // Wait for process to terminate with timeout
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    // Add timeout task
                    group.addTask {
                        try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                        throw TimeoutError.timeout
                    }
                    
                    // Add process wait task
                    group.addTask {
                        await withCheckedContinuation { continuation in
                            Task.detached {
                                process.waitUntilExit()
                                continuation.resume()
                            }
                        }
                    }
                    
                    // Wait for first task to complete
                    try await group.next()
                    group.cancelAll()
                }
            } catch {
                // Timeout occurred, force kill
                if process.isRunning {
                    process.interrupt()
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    if process.isRunning {
                        kill(process.processIdentifier, SIGKILL)
                    }
                }
            }
        }
        
        // Clean up stderr temp file
        if let stderrPath = stderrTempPath {
            try? FileManager.default.removeItem(at: stderrPath)
        }
        
        // Clear all references
        self.process = nil
        self.outputPipe = nil
        self.inputPipe = nil
        self.stderrFile = nil
        self.stderrTempPath = nil
        
        // Update final state
        state = .terminated
    }
    
    /// Add a background task for tracking
    func addBackgroundTask(_ task: Task<Void, Never>) async {
        backgroundTasks.insert(task)
    }
    
    /// Remove a completed background task
    func removeBackgroundTask(_ task: Task<Void, Never>) async {
        backgroundTasks.remove(task)
    }
}

// MARK: - Supporting Types

private enum TimeoutError: Error {
    case timeout
}
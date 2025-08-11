import Foundation
import Darwin

/// Actor that manages subprocess communication with the Claude Code CLI
/// Refactored to use focused components for better maintainability
actor SubprocessCLITransport {
    
    // MARK: - Components
    
    /// Process management
    private let processManager: ProcessManager
    
    /// Message stream handling
    private let messageHandler: MessageStreamHandler
    
    
    // MARK: - State
    
    /// Current session tracking
    private var currentSessionId: String = "default"
    
    /// Control request counter for unique IDs
    private var requestCounter = 0
    
    /// Debug logging
    private let debugLogger: (any DebugLogger)?
    
    // MARK: - Initialization
    
    /// Initialize the transport with an optional custom CLI path
    /// - Parameter cliPath: Custom path to the CLI executable, or nil to auto-discover
    init(cliPath: URL? = nil) throws {
        let resolvedCLIPath: URL
        if let customPath = cliPath {
            resolvedCLIPath = customPath
        } else {
            resolvedCLIPath = try CLIDiscovery.discoverCLI()
        }
        
        self.debugLogger = ClaudeSDK.shared.debugLogger
        self.processManager = ProcessManager(cliPath: resolvedCLIPath)
        self.messageHandler = MessageStreamHandler(
            shouldCloseOnResult: true, // Default for one-shot mode
            debugLogger: self.debugLogger
        )
        
        // Log CLI discovery
        debugLogger?.info("CLI discovered at: \(resolvedCLIPath.path)", file: #file, function: #function, line: #line)
    }
    
    // MARK: - Execution Methods
    
    /// Execute a query with the given prompt and options (one-shot mode)
    /// - Parameters:
    ///   - prompt: The user prompt to send to Claude
    ///   - options: Configuration options for the query
    /// - Returns: An async stream of messages from the CLI
    func execute(prompt: String, options: ClaudeCodeOptions?) async throws -> AsyncThrowingStream<Message, any Error> {
        // Extract session ID for logging
        currentSessionId = "default" // For one-shot mode
        
        debugLogger?.debug("Starting one-shot execution for session: \(self.currentSessionId)", file: #file, function: #function, line: #line)
        debugLogger?.debug("Prompt: \(DebugUtils.truncate(prompt, maxLength: 200))", file: #file, function: #function, line: #line)
        
        // Build process configuration
        let arguments = ArgumentBuilder.buildArguments(isStreaming: false, options: options)
        let environment = ProcessInfo.processInfo.environment
        
        let config = ProcessManager.ProcessConfig(
            arguments: arguments,
            workingDirectory: options?.cwd,
            environment: environment,
            isStreaming: false
        )
        
        debugLogger?.debug("Process arguments: \(DebugUtils.sanitizeArguments(arguments))", file: #file, function: #function, line: #line)
        
        // Start the process
        let processIO = try await processManager.startProcess(config: config)
        let processId = await processManager.getProcessId()
        debugLogger?.info("Process started with PID: \(processId ?? -1), mode: one-shot, session: \(self.currentSessionId)", file: #file, function: #function, line: #line)
        
        // Write prompt to stdin and close it immediately for one-shot mode
        if let promptData = prompt.data(using: .utf8) {
            try await processManager.writeToStdin(promptData)
        }
        try await processManager.closeStdin()
        
        // Configure message handler for one-shot mode
        await messageHandler.setShouldCloseOnResult(true)
        
        // Process messages through the handler (no tool processing)
        return AsyncThrowingStream<Message, any Error> { continuation in
            Task {
                await self.messageHandler.processMessageStream(
                    from: processIO.outputPipe,
                    continuation: continuation
                )
            }
        }
    }
    
    /// Execute with an async sequence of prompts (streaming mode)
    /// - Parameters:
    ///   - prompts: The async sequence of prompts
    ///   - options: Configuration options
    ///   - closeStdinAfterPrompt: Whether to close stdin after sending all prompts
    /// - Returns: An async stream of messages
    func executeStream<S: AsyncSequence & Sendable>(
        prompts: S,
        options: ClaudeCodeOptions?,
        closeStdinAfterPrompt: Bool
    ) async throws -> AsyncThrowingStream<Message, any Error> where S.Element == [String: Any] {
        
        // Build process configuration
        let arguments = ArgumentBuilder.buildArguments(isStreaming: true, options: options)
        let environment = ProcessInfo.processInfo.environment
        
        let config = ProcessManager.ProcessConfig(
            arguments: arguments,
            workingDirectory: options?.cwd,
            environment: environment,
            isStreaming: true
        )
        
        // Start the process
        let processIO = try await processManager.startProcess(config: config)
        
        // Start streaming prompts to stdin
        let stdinTask = Task { [processManager] in
            do {
                for try await message in prompts {
                    try Task.checkCancellation()
                    
                    let jsonData = try JSONSerialization.data(withJSONObject: message)
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        let dataToWrite = (jsonString + "\n").data(using: .utf8)!
                        try await processManager.writeToStdin(dataToWrite)
                    }
                }
                
                if closeStdinAfterPrompt {
                    try await processManager.closeStdin()
                }
            } catch {
                try? await processManager.closeStdin()
            }
        }
        
        // Track the background task
        await processManager.addBackgroundTask(stdinTask)
        
        // Configure message handler for streaming mode
        await messageHandler.setShouldCloseOnResult(false)
        
        // Process messages through the handler (no tool processing)
        return AsyncThrowingStream<Message, any Error> { continuation in
            Task {
                await self.messageHandler.processMessageStream(
                    from: processIO.outputPipe,
                    continuation: continuation
                )
            }
        }
    }
    
    /// Connect for streaming mode (bidirectional communication)
    /// - Parameter options: Configuration options for the session
    /// - Returns: An async stream of messages from the CLI
    func connect(options: ClaudeCodeOptions?) async throws -> AsyncThrowingStream<Message, any Error> {
        
        // Build process configuration
        let arguments = ArgumentBuilder.buildArguments(isStreaming: true, options: options)
        let environment = ProcessInfo.processInfo.environment
        
        let config = ProcessManager.ProcessConfig(
            arguments: arguments,
            workingDirectory: options?.cwd,
            environment: environment,
            isStreaming: true
        )
        
        // Start the process
        let processIO = try await processManager.startProcess(config: config)
        
        // Configure message handler for interactive mode
        await messageHandler.setShouldCloseOnResult(false)
        
        // Process messages through the handler (no tool processing)
        return AsyncThrowingStream<Message, any Error> { continuation in
            Task {
                await self.messageHandler.processMessageStream(
                    from: processIO.outputPipe,
                    continuation: continuation
                )
            }
        }
    }
    
    // MARK: - Communication Methods
    
    /// Send a message in streaming mode
    /// - Parameter message: The message dictionary to send
    func sendMessage(_ message: [String: Any]) async throws {
        guard await processManager.isRunning() else {
            throw ClaudeSDKError.invalidConfiguration(reason: "Not in streaming mode or process not running")
        }
        
        let sessionId = DebugUtils.extractSessionId(from: message)
        let messageType = message["type"] as? String ?? "unknown"
        
        debugLogger?.debug("→ [\(sessionId)] Sending \(messageType) message: \(DebugUtils.formatJSON(message, maxLength: 200))", file: #file, function: #function, line: #line)
        
        let jsonData = try JSONSerialization.data(withJSONObject: message)
        var jsonString = String(data: jsonData, encoding: .utf8) ?? ""
        jsonString += "\n"
        
        guard let data = jsonString.data(using: .utf8) else {
            throw ClaudeSDKError.invalidConfiguration(reason: "Failed to encode message")
        }
        
        try await processManager.writeToStdin(data)
    }
    
    /// Send multiple messages in streaming mode (matches Python's send_request)
    /// - Parameters:
    ///   - messages: Array of message dictionaries to send
    ///   - options: Additional options (e.g., session_id)
    func sendRequest(_ messages: [[String: Any]], options: [String: Any]) async throws {
        guard await processManager.isRunning() else {
            throw ClaudeSDKError.invalidConfiguration(reason: "sendRequest only works when process is running")
        }
        
        // Send each message
        for var message in messages {
            // Ensure message has required structure
            if message["type"] == nil {
                message = [
                    "type": "user",
                    "message": ["role": "user", "content": String(describing: message)],
                    "parent_tool_use_id": NSNull(),
                    "session_id": options["session_id"] ?? "default"
                ]
            }
            
            try await sendMessage(message)
        }
    }
    
    /// Send interrupt control request
    func interrupt() async throws {
        guard await processManager.isRunning() else {
            throw ClaudeSDKError.invalidConfiguration(reason: "Interrupt requires running process")
        }
        
        _ = try await sendControlRequest(["subtype": "interrupt"])
    }
    
    /// Send a control request and wait for response
    private func sendControlRequest(_ request: [String: Any]) async throws -> [String: any Sendable] {
        guard await processManager.isRunning() else {
            throw ClaudeSDKError.invalidConfiguration(reason: "Process not running")
        }
        
        // Generate unique request ID
        requestCounter += 1
        let requestId = "req_\(requestCounter)_\(UUID().uuidString)"
        
        // Build control request
        let controlRequest: [String: Any] = [
            "type": "control_request",
            "request_id": requestId,
            "request": request
        ]
        
        // Send request
        try await sendMessage(controlRequest)
        
        // Wait for response with timeout
        return try await messageHandler.waitForControlResponse(requestId: requestId)
    }
    
    // MARK: - Lifecycle Management
    
    /// Terminate the CLI process if running
    func terminate() async {
        await processManager.terminate()
    }
    
    deinit {
        // Note: Can't call async methods from deinit
        // Swift actor deinitialization handles cleanup automatically
    }
}
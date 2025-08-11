import Foundation

// MARK: - Connection and Query APIs

extension ClaudeCodeSDKClient {
    
    // MARK: - Connection Management
    
    /// Connect to Claude Code CLI with a prompt or message stream
    /// - Parameter prompt: String prompt, async sequence of messages, or nil for empty connection
    public func connect<S: AsyncSequence & Sendable>(
        prompt: S? = nil
    ) async throws where S.Element == [String: Any] {
        let transport = try SubprocessCLITransport()
        let options = await optionsManager.getOptions()
        
        if let prompt = prompt {
            // Use provided prompt
            let stream = try await transport.executeStream(
                prompts: prompt,
                options: options,
                closeStdinAfterPrompt: false  // Keep stdin open for bidirectional communication
            )
            
            await connectionManager.setConnection(transport: transport, messageStream: stream)
        } else {
            // Create empty stream for interactive use
            let stream = try await transport.connect(options: options)
            
            await connectionManager.setConnection(transport: transport, messageStream: stream)
        }
    }
    
    /// Connect to Claude Code CLI with a string prompt
    public func connect(prompt: String) async throws {
        let transport = try SubprocessCLITransport()
        let options = await optionsManager.getOptions()
        
        // For string prompts, use execute (one-shot mode)
        let stream = try await transport.execute(prompt: prompt, options: options)
        
        await connectionManager.setConnection(transport: transport, messageStream: stream)
    }
    
    /// Connect to Claude Code CLI in streaming mode (no initial prompts)
    public func connect() async throws {
        let transport = try SubprocessCLITransport()
        let options = await optionsManager.getOptions()
        
        let stream = try await transport.connect(options: options)
        
        await connectionManager.setConnection(transport: transport, messageStream: stream)
    }
    
    /// Reconnect to continue the last conversation or resume a specific session
    /// - Parameter sessionId: Session ID to resume. If nil, continues the last conversation.
    /// 
    /// This method works by:
    /// - If sessionId is provided: uses --resume flag to reconnect to specific session
    /// - If sessionId is nil: uses --continue flag to continue the most recent conversation
    /// - Preserves all existing client options while adding session continuation
    public func reconnect(sessionId: String? = nil) async throws {
        // Disconnect any existing connection first
        await disconnect()
        
        // Create new options with session continuation
        let reconnectOptions: ClaudeCodeOptions
        
        // Always use existing options as base (these are the options passed to the client constructor)
        let baseOptions = await optionsManager.getOptions() ?? ClaudeCodeOptions()
        
        if let sessionId = sessionId {
            // Resume specific session - preserve all options but set resume flag
            reconnectOptions = ClaudeCodeOptionsBuilder(from: baseOptions)
                .resume(sessionId)            // Use resume with specific session ID
                .build()
        } else {
            // Continue last conversation - preserve all options but set continue flag
            reconnectOptions = ClaudeCodeOptionsBuilder(from: baseOptions)
                .continueConversation(true)   // Use continue flag
                .build()
        }
        
        // Create new transport and connect with session continuation
        let transport = try SubprocessCLITransport()
        let stream = try await transport.connect(options: reconnectOptions)
        await connectionManager.setConnection(transport: transport, messageStream: stream)
    }
    
    /// Disconnect from Claude Code CLI
    public func disconnect() async {
        if let transport = await connectionManager.getTransport() {
            await transport.terminate()
        }
        await connectionManager.clearConnection()
    }
    
    // MARK: - Message Streaming
    
    /// Receive all messages from Claude
    /// - Returns: An async sequence of messages
    public func receiveMessages() -> AsyncThrowingStream<Message, any Error> {
        return AsyncThrowingStream { continuation in
            Task {
                let stream = await connectionManager.getMessageStream()
                guard let stream = stream else {
                    continuation.finish(throwing: ClaudeSDKError.invalidConfiguration(
                        reason: "Not connected. Call connect() first."
                    ))
                    return
                }
                
                do {
                    for try await message in stream {
                        continuation.yield(message)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Receive messages until and including a ResultMessage
    ///
    /// This async iterator yields all messages in sequence and automatically terminates
    /// after yielding a ResultMessage (which indicates the response is complete).
    /// It's a convenience method over receiveMessages() for single-response workflows.
    ///
    /// **Stopping Behavior:**
    /// - Yields each message as it's received
    /// - Terminates immediately after yielding a ResultMessage
    /// - The ResultMessage IS included in the yielded messages
    /// - If no ResultMessage is received, the iterator continues indefinitely
    ///
    /// - Returns: An async sequence that terminates after ResultMessage
    ///
    /// ## Example:
    /// ```swift
    /// let client = ClaudeCodeSDKClient()
    /// try await client.connect()
    ///
    /// try await client.queryStream("What's the capital of France?")
    ///
    /// for try await msg in client.receiveResponse() {
    ///     if let assistant = msg as? AssistantMessage {
    ///         for block in assistant.content {
    ///             if case .text(let text) = block {
    ///                 print("Claude: \(text)")
    ///             }
    ///         }
    ///     } else if let result = msg as? ResultMessage {
    ///         print("Cost: $\(result.totalCostUsd ?? 0)")
    ///         // Iterator will terminate after this message
    ///     }
    /// }
    /// ```
    ///
    /// Note: To collect all messages: `let messages = try await Array(client.receiveResponse())`
    /// The final message in the array will always be a ResultMessage.
    public func receiveResponse() -> AsyncThrowingStream<Message, any Error> {
        let messages = self.receiveMessages()
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await message in messages {
                        continuation.yield(message)
                        if case .result = message {
                            continuation.finish()
                            return
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    
    // MARK: - Query Stream Methods
    
    /// Send a new request in streaming mode (string prompt)
    /// - Parameters:
    ///   - prompt: The user prompt to send
    ///   - sessionId: Session identifier for the conversation
    public func queryStream(_ prompt: String, sessionId: String = "default") async throws {
        guard let transport = await connectionManager.getTransport() else {
            throw ClaudeSDKError.invalidConfiguration(reason: "Not connected. Call connect() first.")
        }
        
        let message: [String: Any] = [
            "type": "user",
            "message": [
                "role": "user",
                "content": prompt
            ],
            "parent_tool_use_id": NSNull(),
            "session_id": sessionId
        ]
        
        // Use sendRequest to match Python SDK behavior
        try await transport.sendRequest([message], options: ["session_id": sessionId])
    }
    
    /// Send a new request in streaming mode (async sequence of messages)
    /// - Parameters:
    ///   - prompt: An async sequence of message dictionaries
    ///   - sessionId: Session identifier for the conversation
    public func queryStream<S: AsyncSequence & Sendable>(
        prompt: S,
        sessionId: String = "default"
    ) async throws where S.Element == [String: Any] {
        guard let transport = await connectionManager.getTransport() else {
            throw ClaudeSDKError.invalidConfiguration(reason: "Not connected. Call connect() first.")
        }
        
        // Collect all messages first (like Python SDK)
        var messages: [[String: Any]] = []
        for try await var msg in prompt {
            // Ensure session_id is set on each message
            if msg["session_id"] == nil {
                msg["session_id"] = sessionId
            }
            messages.append(msg)
        }
        
        if !messages.isEmpty {
            try await transport.sendRequest(messages, options: ["session_id": sessionId])
        }
    }
    
    /// Send interrupt signal
    public func interrupt() async throws {
        guard let transport = await connectionManager.getTransport() else {
            throw ClaudeSDKError.invalidConfiguration(reason: "Not connected. Call connect() first.")
        }
        try await transport.interrupt()
    }
}

// MARK: - Async Context Manager Support

extension ClaudeCodeSDKClient {
    /// Use the client as an async context manager
    /// ## Example:
    /// ```swift
    /// async let client = ClaudeCodeSDKClient.withConnection { client in
    ///     try await client.queryStream("Hello!")
    ///     // Use client here
    /// }
    /// // Automatically disconnects
    /// ```
    public static func withConnection<T>(
        options: ClaudeCodeOptions? = nil,
        _ block: (ClaudeCodeSDKClient) async throws -> T
    ) async throws -> T {
        let client = ClaudeCodeSDKClient(options: options)
        try await client.connect()
        do {
            let result = try await block(client)
            await client.disconnect()
            return result
        } catch {
            await client.disconnect()
            throw error
        }
    }
    
    /// Use the client as an async context manager with session continuation
    ///
    /// Automatically reconnects to continue the last conversation or resume a specific session.
    /// The connection is automatically terminated when the block completes.
    ///
    /// ## Example:
    /// ```swift
    /// // Continue last conversation
    /// async let result = ClaudeCodeSDKClient.withReconnection { client in
    ///     try await client.queryStream("Continue where we left off...")
    ///     // Process responses...
    /// }
    ///
    /// // Resume specific session
    /// async let result = ClaudeCodeSDKClient.withReconnection(sessionId: "session-123") { client in
    ///     try await client.queryStream("Let's pick up from session 123")
    ///     // Process responses...
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - sessionId: Session ID to resume. If nil, continues the last conversation.
    ///   - options: Base configuration options (session settings will be overridden)
    ///   - block: The async block to execute with the reconnected client
    /// - Returns: The result from the block
    public static func withReconnection<T>(
        sessionId: String? = nil,
        options: ClaudeCodeOptions? = nil,
        _ block: (ClaudeCodeSDKClient) async throws -> T
    ) async throws -> T {
        let client = ClaudeCodeSDKClient(options: options)
        try await client.reconnect(sessionId: sessionId)
        do {
            let result = try await block(client)
            await client.disconnect()
            return result
        } catch {
            await client.disconnect()
            throw error
        }
    }
}
import Foundation

/// Query Claude Code for one-shot or unidirectional streaming interactions.
///
/// This function is ideal for simple, stateless queries where you don't need
/// bidirectional communication or conversation management. For interactive,
/// stateful conversations, use ClaudeCodeSDKClient instead.
///
/// Key differences from ClaudeCodeSDKClient:
/// - **Unidirectional**: Send all messages upfront, receive all responses
/// - **Stateless**: Each query is independent, no conversation state
/// - **Simple**: Fire-and-forget style, no connection management
/// - **No interrupts**: Cannot interrupt or send follow-up messages
///
/// When to use query():
/// - Simple one-off questions ("What is 2+2?")
/// - Batch processing of independent prompts
/// - Code generation or analysis tasks
/// - Automated scripts and CI/CD pipelines
/// - When you know all inputs upfront
///
/// When to use ClaudeCodeSDKClient:
/// - Interactive conversations with follow-ups
/// - Chat applications or REPL-like interfaces
/// - When you need to send messages based on responses
/// - When you need interrupt capabilities
/// - Long-running sessions with state
///
/// - Parameters:
///   - prompt: The prompt to send to Claude. Can be a string for single-shot queries
///            or an AsyncSequence for streaming mode with continuous interaction.
///   - options: Optional configuration (defaults to ClaudeCodeOptions() if nil).
/// - Returns: An async throwing stream of messages from the conversation
///
/// Example - Simple query:
/// ```swift
/// // One-off question
/// for try await message in query(prompt: "What is the capital of France?") {
///     print(message)
/// }
/// ```
///
/// Example - With options:
/// ```swift
/// // Code generation with specific settings
/// for try await message in query(
///     prompt: "Create a Python web server",
///     options: ClaudeCodeOptions(
///         systemPrompt: "You are an expert Python developer",
///         cwd: URL(fileURLWithPath: "/home/user/project")
///     )
/// ) {
///     print(message)
/// }
/// ```
public func query(
    prompt: String,
    options: ClaudeCodeOptions? = nil
) async throws -> AsyncThrowingStream<Message, any Error> {
    let finalOptions = options ?? ClaudeCodeOptions()
    
    // Set environment variable
    setenv("CLAUDE_CODE_ENTRYPOINT", "sdk-swift", 1)
    
    let transport = try SubprocessCLITransport()
    return try await transport.execute(prompt: prompt, options: finalOptions)
}

/// Query Claude Code with an async sequence of prompts (still unidirectional).
///
/// All prompts are sent, then all responses received. This is different from
/// ClaudeCodeSDKClient which allows bidirectional communication.
///
/// - Parameters:
///   - prompts: An async sequence of message dictionaries
///   - options: Optional configuration
/// - Returns: An async throwing stream of messages
///
/// Example - Streaming mode:
/// ```swift
/// func prompts() -> AsyncStream<[String: Any]> {
///     AsyncStream { continuation in
///         continuation.yield([
///             "type": "user",
///             "message": ["role": "user", "content": "Hello"],
///             "parent_tool_use_id": NSNull(),
///             "session_id": "default"
///         ])
///         continuation.yield([
///             "type": "user",
///             "message": ["role": "user", "content": "How are you?"],
///             "parent_tool_use_id": NSNull(),
///             "session_id": "default"
///         ])
///         continuation.finish()
///     }
/// }
///
/// // All prompts are sent, then all responses received
/// for try await message in query(prompts: prompts()) {
///     print(message)
/// }
/// ```
public func query<S: AsyncSequence & Sendable>(
    prompts: S,
    options: ClaudeCodeOptions? = nil
) async throws -> AsyncThrowingStream<Message, any Error> where S.Element == [String: Any] {
    let finalOptions = options ?? ClaudeCodeOptions()
    
    // Set environment variable
    setenv("CLAUDE_CODE_ENTRYPOINT", "sdk-swift", 1)
    
    let transport = try SubprocessCLITransport()
    return try await transport.executeStream(prompts: prompts, options: finalOptions, closeStdinAfterPrompt: true)
}

// MARK: - Session Continuation Convenience Functions

/// Continue the last conversation with a new prompt.
///
/// This is a convenience function that automatically sets the continue flag
/// to resume from the last conversation state. Equivalent to calling query()
/// with ClaudeCodeOptions(continueConversation: true).
///
/// - Parameters:
///   - prompt: The prompt to send to Claude
///   - options: Base configuration options (continueConversation will be set to true)
/// - Returns: An async throwing stream of messages from the conversation
///
/// Example:
/// ```swift
/// // Start initial conversation
/// for try await message in query(prompt: "Let's start a coding project") {
///     // Process initial response
/// }
///
/// // Continue from where we left off
/// for try await message in continueQuery(prompt: "Add error handling to that code") {
///     // Process continuation response
/// }
/// ```
public func continueQuery(
    prompt: String,
    options: ClaudeCodeOptions? = nil
) async throws -> AsyncThrowingStream<Message, any Error> {
    let baseOptions = options ?? ClaudeCodeOptions()
    
    // Create new options with continue flag enabled
    let continueOptions = ClaudeCodeOptions(
        systemPrompt: baseOptions.systemPrompt,
        appendSystemPrompt: baseOptions.appendSystemPrompt,
        maxTurns: baseOptions.maxTurns,
        cwd: baseOptions.cwd,
        addDirs: baseOptions.addDirs,
        allowedTools: baseOptions.allowedTools,
        disallowedTools: baseOptions.disallowedTools,
        permissionMode: baseOptions.permissionMode,
        permissionPromptToolName: baseOptions.permissionPromptToolName,
        continueConversation: true,  // Enable continue
        resume: nil,                 // Don't use resume
        mcpServers: baseOptions.mcpServers,
        model: baseOptions.model,
        settings: baseOptions.settings,
        extraArgs: baseOptions.extraArgs
    )
    
    return try await query(prompt: prompt, options: continueOptions)
}

/// Resume a specific session with a new prompt.
///
/// This is a convenience function that automatically sets the resume flag
/// with the specified session ID. Equivalent to calling query()
/// with ClaudeCodeOptions(resume: sessionId).
///
/// - Parameters:
///   - prompt: The prompt to send to Claude
///   - sessionId: The session ID to resume
///   - options: Base configuration options (resume will be set to sessionId)
/// - Returns: An async throwing stream of messages from the conversation
///
/// Example:
/// ```swift
/// // Resume a specific session
/// for try await message in resumeQuery(
///     prompt: "Continue working on the authentication system",
///     sessionId: "session-abc123"
/// ) {
///     // Process resumed session response
/// }
/// ```
public func resumeQuery(
    prompt: String,
    sessionId: String,
    options: ClaudeCodeOptions? = nil
) async throws -> AsyncThrowingStream<Message, any Error> {
    let baseOptions = options ?? ClaudeCodeOptions()
    
    // Create new options with resume flag enabled
    let resumeOptions = ClaudeCodeOptions(
        systemPrompt: baseOptions.systemPrompt,
        appendSystemPrompt: baseOptions.appendSystemPrompt,
        maxTurns: baseOptions.maxTurns,
        cwd: baseOptions.cwd,
        addDirs: baseOptions.addDirs,
        allowedTools: baseOptions.allowedTools,
        disallowedTools: baseOptions.disallowedTools,
        permissionMode: baseOptions.permissionMode,
        permissionPromptToolName: baseOptions.permissionPromptToolName,
        continueConversation: false, // Don't use continue
        resume: sessionId,           // Use resume with session ID
        mcpServers: baseOptions.mcpServers,
        model: baseOptions.model,
        settings: baseOptions.settings,
        extraArgs: baseOptions.extraArgs
    )
    
    return try await query(prompt: prompt, options: resumeOptions)
}
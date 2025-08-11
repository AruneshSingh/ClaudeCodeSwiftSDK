import Foundation

/// Client for bidirectional, interactive conversations with Claude Code.
///
/// This client provides full control over the conversation flow with support
/// for streaming, interrupts, and dynamic message sending. For simple one-shot
/// queries, consider using the `query()` function instead.
///
/// Key features:
/// - **Bidirectional**: Send and receive messages at any time
/// - **Stateful**: Maintains conversation context across messages
/// - **Interactive**: Send follow-ups based on responses
/// - **Control flow**: Support for interrupts and session management
/// - **Tool Integration**: Unified tool lifecycle management with intelligent pairing
/// - **Settings Management**: Dynamic configuration updates with session preservation
///
/// When to use ClaudeCodeSDKClient:
/// - Building chat interfaces or conversational UIs
/// - Interactive debugging or exploration sessions
/// - Multi-turn conversations with context
/// - When you need to react to Claude's responses
/// - Real-time applications with user input
/// - When you need interrupt capabilities
/// - Tool execution monitoring and analytics
///
/// When to use query() instead:
/// - Simple one-off questions
/// - Batch processing of prompts
/// - Fire-and-forget automation scripts
/// - When all inputs are known upfront
/// - Stateless operations
///
/// ## API Organization
/// The ClaudeCodeSDKClient is organized into three main areas:
///
/// ### Connection & Query APIs (ConnectionAPI.swift)
/// - Connection management: `connect()`, `disconnect()`, `reconnect()`
/// - Message streaming: `receiveMessages()`, `receiveResponse()`
/// - Query execution: `queryStream()`, `interrupt()`
/// - Context managers: `withConnection()`, `withReconnection()`
///
/// ### Settings Management (SettingsAPI.swift)
/// - Individual settings: `updateModel()`, `updateSystemPrompt()`, etc.
/// - Batch updates: `updateSettings()`
/// - Settings inspection: `getCurrentModel()`, `getCurrentOptions()`, etc.
/// - Presets: `enablePlanMode()`, `enableExecutionMode()`, etc.
///
/// ### Tools API (ToolsAPI.swift)
/// - Tool streams: `toolMessages()`, `pendingTools()`, `completedTools()`, `failedTools()`
/// - Tool filtering: `toolsWithName()`, `slowTools()`
/// - Tool management: `manuallyCompleteTool()`, `manuallyFailTool()`
/// - Analytics: `getToolStatistics()`, `waitForAllToolsToComplete()`
///
/// ## Example - Interactive conversation:
/// ```swift
/// let client = ClaudeCodeSDKClient()
/// try await client.connect()
///
/// // Send initial message
/// try await client.queryStream("Let's solve a math problem step by step")
///
/// // Monitor tool execution
/// Task {
///     for try await tool in client.toolMessages() {
///         print("🔧 \(tool.name): \(tool.status)")
///     }
/// }
///
/// // Receive and process response
/// for try await message in client.receiveResponse() {
///     if let assistant = message as? AssistantMessage {
///         // Process response and decide on follow-up
///         break
///     }
/// }
///
/// // Send follow-up based on response
/// try await client.queryStream("What's 15% of 80?")
///
/// // Continue conversation...
/// await client.disconnect()
/// ```
///
/// ## Example - With settings management:
/// ```swift
/// let client = ClaudeCodeSDKClient()
/// try await client.connect()
///
/// // Enable development mode with batch settings update
/// try await client.updateSettings { builder in
///     builder.permissionMode(.acceptEdits)
///     builder.allowedTools(["Read", "Write", "Edit", "Bash"])
///     builder.systemPrompt("You are a senior developer assistant")
/// }
///
/// // Start coding session
/// try await client.queryStream("Help me implement a REST API")
/// 
/// // Monitor tools and get analytics
/// let stats = try await client.getToolStatistics()
/// print("Active tools: \(stats["pendingToolsCount"] ?? 0)")
///
/// await client.disconnect()
/// ```
public final class ClaudeCodeSDKClient: Sendable {
    internal let connectionManager: ConnectionManager
    
    /// Thread-safe options management using actor
    internal actor OptionsManager {
        private var _options: ClaudeCodeOptions?
        
        init(options: ClaudeCodeOptions?) {
            self._options = options
        }
        
        func getOptions() -> ClaudeCodeOptions? {
            return _options
        }
        
        func updateOptions(_ newOptions: ClaudeCodeOptions) {
            self._options = newOptions
        }
    }
    
    internal let optionsManager: OptionsManager
    
    /// Internal actor to manage connection state safely
    internal actor ConnectionManager {
        private var transport: SubprocessCLITransport?
        private var messageStream: AsyncThrowingStream<Message, any Error>?
        
        func setConnection(
            transport: SubprocessCLITransport,
            messageStream: AsyncThrowingStream<Message, any Error>
        ) {
            self.transport = transport
            self.messageStream = messageStream
        }
        
        func getTransport() -> SubprocessCLITransport? {
            return transport
        }
        
        func getMessageStream() -> AsyncThrowingStream<Message, any Error>? {
            return messageStream
        }
        
        func clearConnection() {
            transport = nil
            messageStream = nil
        }
    }
    
    /// Initialize Claude SDK client.
    /// - Parameter options: Configuration options for the session
    public init(options: ClaudeCodeOptions? = nil) {
        self.optionsManager = OptionsManager(options: options)
        self.connectionManager = ConnectionManager()
    }
    
    deinit {
        Task { [connectionManager] in
            if let transport = await connectionManager.getTransport() {
                await transport.terminate()
            }
        }
    }
}
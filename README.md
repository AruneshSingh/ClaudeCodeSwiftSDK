# Claude Code Swift SDK

A Swift SDK for [Claude Code](https://claude.ai/code), providing programmatic access to Claude's powerful code generation and assistance capabilities through a type-safe, async/await API.

## ✨ Key Features

The Claude Code Swift SDK provides a comprehensive, type-safe interface to Claude Code CLI with modern Swift concurrency support.

### 📁 Modular API Structure
The ClaudeCodeSDKClient is organized into three focused modules:

```swift
// 🔗 Connection & Query APIs (ConnectionAPI.swift)
try await client.connect()
try await client.queryStream("Hello Claude!")

// ⚙️ Settings Management (SettingsAPI.swift)  
try await client.updatePermissionMode(.plan)

// 🔧 Tools API (ToolsAPI.swift)
for try await tool in client.toolMessages() {
    print("🔧 \(tool.name): \(tool.status) (\(tool.duration ?? 0)s)")
}
```

### 🔧 Advanced Tool Management
Intelligent `ToolMessage` type that automatically pairs tool calls with their results:

```swift
// Unified tool lifecycle tracking
for try await tool in client.toolMessages() {
    switch tool.status {
    case .pending: print("🔄 \(tool.name) executing...")
    case .completed: print("✅ \(tool.name) done in \(tool.duration!)s")  
    case .failed: print("❌ \(tool.name) failed: \(tool.error!.message)")
    }
}
```

**Core Features:**
- ✅ **Unified Tool Lifecycle**: Automatic call/result pairing by ID
- ✅ **Real-time Tool Updates**: Stream pending → completed/failed states
- ✅ **Rich Tool Analytics**: Execution timing, performance metrics, error details
- ✅ **Tool Filtering**: `pendingTools()`, `completedTools()`, `failedTools()`, `toolsWithName()`
- ✅ **Modular API Structure**: Three focused modules (Connection, Settings, Tools)
- ✅ **Dynamic Settings**: Individual setting updates (`updatePermissionMode`, `updateSystemPrompt`, etc.)
- ✅ **Batch Updates**: Efficient multi-setting updates (`updateSettings { builder in ... }`)
- ✅ **Session Management**: Automatic session preservation with `--continue` flag
- ✅ **Thread-safe**: Options management using actors


## 🚀 Features

- **🎯 Type-Safe**: Comprehensive Swift types for all messages and content blocks
- **⚡ Async/Await**: Native Swift concurrency with `AsyncSequence` streaming
- **🔄 Bidirectional Communication**: Real-time interactive conversations with interrupt support
- **🛠 Tool Integration**: Full support for Claude's tool system (Read, Write, Bash, etc.)
- **⚙️ Highly Configurable**: Extensive configuration options for fine-tuned control
- **🔥 Dynamic Settings**: Update settings mid-conversation with automatic session preservation
- **⚡ Batch Updates**: Efficient multi-setting updates with single reconnection
- **🔗 MCP Support**: Model Context Protocol server integration
- **📦 Zero Dependencies**: Pure Swift implementation with no external dependencies
- **🎛 Permission Control**: Granular tool permissions and safety modes
- **💰 Usage Tracking**: Built-in cost and usage monitoring
- **🔧 Swift 6 Ready**: Strict concurrency and modern Swift features

## 📋 Requirements

- Swift 6.0+
- macOS 15.0+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed

## 📦 Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/AruneshSingh/ClaudeCodeSwiftSDK.git", from: "0.1.0")
]
```

Or add via Xcode: File → Add Package Dependencies → Enter repository URL

### Claude Code CLI Setup

Install the Claude Code CLI:

```bash
npm install -g @anthropic-ai/claude-code
```

## 🐛 Debug Logging

For development and troubleshooting, you can enable comprehensive debug logging:

```swift
import ClaudeCodeSwiftSDK

// Enable debug logging at startup (development only)
configureClaudeCodeSwiftSDK(debug: true)

// Now all SDK operations will log detailed information
for try await message in query(prompt: "Hello Claude!") {
    // Debug logs will show:
    // - CLI discovery and process startup
    // - Command line arguments (sanitized)
    // - Message flow with session IDs
    // - Cost and usage information
    // - Process lifecycle events
    print(message)
}
```

### Custom Debug Logger

You can provide your own debug logger:

```swift
class FileLogger: DebugLogger {
    // Implement debug logging to file, network, etc.
    func debug(_ message: @autoclosure @escaping () -> String, file: String, function: String, line: Int) {
        // Your custom debug implementation
    }
    // ... implement other methods
}

configureClaudeCodeSwiftSDK(debug: true, debugLogger: FileLogger())
```

### What Gets Logged

With debug logging enabled, you'll see:

- **🔍 CLI Discovery**: Path resolution and version detection
- **⚙️ Process Lifecycle**: Startup, arguments, PID, termination  
- **💬 Message Flow**: All messages sent/received with session context
- **💰 Cost Information**: Detailed cost and usage metrics from results
- **🔄 Session Management**: Session IDs, continuation, and resumption
- **❌ Error Details**: Comprehensive error information and stack traces

## 🏃‍♂️ Quick Start

### Simple Query

For one-off questions or code generation:

```swift
import ClaudeCodeSwiftSDK

// Simple question
for try await message in query(prompt: "What is 2 + 2?") {
    switch message {
    case .assistant(let assistant):
        for block in assistant.content {
            if let textBlock = block as? TextBlock {
                print("Claude:", textBlock.text)
            }
        }
    case .result(let result):
        print("Cost: $\(result.totalCostUsd ?? 0)")
    default:
        break
    }
}
```

### Interactive Conversation

For dynamic, multi-turn conversations:

```swift
import ClaudeCodeSwiftSDK

let client = ClaudeCodeSDKClient()
try await client.connect()

// Send initial message
try await client.queryStream("Let's build a web server in Python")

// Process responses
for try await message in client.receiveResponse() {
    switch message {
    case .assistant(let assistant):
        for block in assistant.content {
            switch block {
            case let textBlock as TextBlock:
                print("Claude:", textBlock.text)
            case let toolUse as ToolUseBlock:
                print("Using tool:", toolUse.name)
            default:
                break
            }
        }
    case .result(let result):
        print("Completed in \(result.durationMs)ms")
        break // Response complete
    default:
        break
    }
}

// Send follow-up
try await client.queryStream("Add error handling to the server")
// ... process more responses

await client.disconnect()
```

### Dynamic Settings Management

Update client settings during active conversations with automatic session preservation:

```swift
import ClaudeCodeSwiftSDK

let client = ClaudeCodeSDKClient()
try await client.connect()

// Start conversation
try await client.queryStream("Let's build a web API")

// Mid-conversation: Switch to planning mode
try await client.updatePermissionMode(.plan)

// Settings changed and session preserved automatically
try await client.queryStream("Create a detailed project plan")
// → Receives response in planning mode with conversation context intact
```

#### Individual Settings Updates

Each method automatically preserves session context:

```swift
// Change permission mode with session preservation
try await client.updatePermissionMode(.acceptEdits)

// Update system prompt while maintaining conversation
try await client.updateSystemPrompt("You are a senior Swift architect")

// Modify allowed tools dynamically
try await client.updateAllowedTools(["Read", "Write", "Bash"])

// Change model mid-conversation
try await client.updateModel("claude-3-sonnet-20241022")

// Update working directory
try await client.updateWorkingDirectory(URL(fileURLWithPath: "/new/project"))
```

#### Batch Settings Update (Recommended)

Most efficient for multiple changes - single reconnection:

```swift
try await client.updateSettings { builder in
    builder.permissionMode(.plan)
    builder.systemPrompt("Focus on architecture and scalability")
    builder.allowedTools(["Read", "Grep", "Glob"])  // Read-only for planning
    builder.maxTurns(10)
    builder.cwd(URL(fileURLWithPath: "/enterprise/project"))
}
// → Single reconnection preserves session, applies all changes
```

#### Error Handling for Settings

```swift
do {
    try await client.updateSettings { builder in
        builder.permissionMode(.plan)
        builder.systemPrompt("Planning mode enabled")
    }
    print("✅ Settings updated, session preserved")
} catch {
    print("❌ Settings update failed: \(error)")
    // Client remains connected with previous settings
}
```

#### ⚠️ Important: Message Stream Handling

**When using dynamic settings updates, the client internally reconnects to apply changes.** If you're running background tasks that receive messages, you must restart them after settings updates:

```swift
let client = ClaudeCodeSDKClient()
try await client.connect()

// Start message receiving task
var receiveTask = Task {
    for try await message in client.receiveMessages() {
        // Process messages
    }
}

// When updating settings, restart the receive task
try await client.updatePermissionMode(.plan)

// ⚠️ IMPORTANT: Restart message receiving after settings update
receiveTask.cancel()  // Cancel old task
receiveTask = Task {  // Start new task with updated connection
    for try await message in client.receiveMessages() {
        // Process messages with new settings
    }
}
```

**Why this is needed:**
- Settings updates call `reconnect()` internally to apply changes
- This creates a new connection with updated settings
- Old message receiving tasks are still listening to the previous connection
- You must cancel old tasks and create new ones to receive messages properly

**Alternative approach using `receiveResponse()`:**
```swift
// This approach doesn't require task management
try await client.updatePermissionMode(.plan)
try await client.queryStream("Test message after settings change")

for try await message in client.receiveResponse() {
    // Processes messages until ResultMessage, then stops automatically
    // No need to manage tasks manually
}
```

#### Performance Comparison

**❌ Old Approach (Manual)**
```swift
// Multiple reconnections = slow + complex
client.disconnect()
let newOptions = ClaudeCodeOptions(permissionMode: .plan)  
let newClient = ClaudeCodeSDKClient(options: newOptions)
try await newClient.connect() // Reconnect 1

// Another setting change...
client.disconnect() 
let options2 = ClaudeCodeOptions(systemPrompt: "New prompt")
let client2 = ClaudeCodeSDKClient(options: options2) 
try await client2.connect() // Reconnect 2

// → 2 reconnections, manual session management, complex code
```

**✅ New Approach (Dynamic Settings)**
```swift
// Single reconnection = fast + simple + session preserved
try await client.updateSettings { builder in
    builder.permissionMode(.plan)
    builder.systemPrompt("New prompt") 
}
// → 1 reconnection, automatic session preservation, simple code
```

## 🔧 Configuration

### Basic Options

```swift
let options = ClaudeCodeOptions(
    systemPrompt: "You are an expert Swift developer",
    maxTurns: 5,
    cwd: URL(fileURLWithPath: "/path/to/project"),
    allowedTools: ["Read", "Write", "Bash"],
    permissionMode: .acceptEdits
)

let client = ClaudeCodeSDKClient(options: options)
```

### Fluent Builder API

```swift
let options = ClaudeCodeOptionsBuilder()
    .systemPrompt("You are a helpful coding assistant")
    .maxTurns(10)
    .cwd(URL(fileURLWithPath: "/Users/developer/project"))
    .allowedTools(["Read", "Write", "Bash", "Grep"])
    .permissionMode(.acceptEdits)
    .model("claude-3-sonnet-20241022")
    .build()
```

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `systemPrompt` | Initial system prompt | `nil` |
| `appendSystemPrompt` | Additional system context | `nil` |
| `maxTurns` | Maximum conversation turns | `nil` (unlimited) |
| `cwd` | Working directory | `nil` (current) |
| `addDirs` | Additional context directories | `[]` |
| `allowedTools` | Permitted tools | `[]` (all allowed) |
| `disallowedTools` | Forbidden tools | `[]` |
| `permissionMode` | Permission handling | `nil` (default) |
| `continueConversation` | Conversation continuation | `false` |
| `resume` | Resume session ID | `nil` |
| `model` | Claude model to use | `nil` (default) |
| `settings` | Settings file path | `nil` |
| `mcpServers` | MCP server configurations | `.dictionary([:])` |

### Permission Modes

- **`default`**: Standard permission prompts
- **`acceptEdits`**: Auto-accept file modifications
- **`bypassPermissions`**: Skip all permission checks
- **`plan`**: Planning mode with restricted actions

## 📡 API Reference

The ClaudeCodeSDKClient API is organized into three focused modules:

### 🔗 Connection & Query APIs (ConnectionAPI.swift)

Core functionality for connecting, querying, and managing message streams.

#### Query Functions

##### Simple Query
```swift
func query(
    prompt: String,
    options: ClaudeCodeOptions? = nil
) async throws -> AsyncThrowingStream<Message, Error>
```

##### Streaming Query
```swift
func query<S: AsyncSequence & Sendable>(
    prompts: S,
    options: ClaudeCodeOptions? = nil
) async throws -> AsyncThrowingStream<Message, Error> 
where S.Element == [String: Any]
```

##### Session Continuation Queries
```swift
// Continue the last conversation
func continueQuery(
    prompt: String,
    options: ClaudeCodeOptions? = nil
) async throws -> AsyncThrowingStream<Message, Error>

// Resume a specific session
func resumeQuery(
    prompt: String,
    sessionId: String,
    options: ClaudeCodeOptions? = nil
) async throws -> AsyncThrowingStream<Message, Error>
```

#### Connection Management
```swift
// Connect for interactive use
func connect() async throws

// Connect with initial prompt
func connect(prompt: String) async throws

// Connect with message stream
func connect<S: AsyncSequence & Sendable>(prompt: S?) async throws

// Reconnects session with --continue or if sessionId available, --resume 
func reconnect(sessionId: String? = nil) async throws

// Disconnect
func disconnect() async
```

#### Message Handling
```swift
// Send query
func query(_ prompt: String, sessionId: String = "default") async throws

// Receive all messages
func receiveMessages() -> AsyncThrowingStream<Message, Error>

// Receive until completion
func receiveResponse() -> AsyncThrowingStream<Message, Error>

// Filter out tool messages
func nonToolMessages() -> AsyncThrowingStream<Message, Error>

// Send interrupt
func interrupt() async throws
```

#### Context Managers
```swift
// Standard connection
static func withConnection<T>(
    options: ClaudeCodeOptions? = nil,
    _ block: (ClaudeCodeSDKClient) async throws -> T
) async throws -> T

// Session continuation connection
static func withReconnection<T>(
    sessionId: String? = nil,
    options: ClaudeCodeOptions? = nil,
    _ block: (ClaudeCodeSDKClient) async throws -> T
) async throws -> T
```

### ⚙️ Settings Management (SettingsAPI.swift)

Dynamic configuration management with automatic session preservation.

#### Individual Setting Updates
```swift
// Individual setting updates with automatic session preservation
func updatePermissionMode(_ mode: PermissionMode) async throws
func updateSystemPrompt(_ prompt: String) async throws
func updateAllowedTools(_ tools: [String]) async throws
func updateModel(_ model: String) async throws  
func updateWorkingDirectory(_ cwd: URL) async throws
func updateMaxTurns(_ maxTurns: Int) async throws
func updateDisallowedTools(_ tools: [String]) async throws
func updateAppendSystemPrompt(_ prompt: String) async throws
```

#### Batch Settings Update
```swift
// Batch settings update (most efficient - single reconnection)
func updateSettings(_ configure: (ClaudeCodeOptionsBuilder) -> Void) async throws
```

#### Settings Inspection
```swift
// Get current configuration
func getCurrentOptions() async -> ClaudeCodeOptions?
func getCurrentPermissionMode() async -> ClaudeCodeOptions.PermissionMode?
func getCurrentSystemPrompt() async -> String?
func getCurrentModel() async -> String?
func getCurrentWorkingDirectory() async -> URL?
func getCurrentAllowedTools() async -> [String]?
func getCurrentDisallowedTools() async -> [String]?
func getCurrentMaxTurns() async -> Int?
```

#### Settings Presets
```swift
// Pre-configured modes for common workflows
func enablePlanMode() async throws          // Planning with limited tools
func enableExecutionMode() async throws     // Full tool access
func enableReadOnlyMode() async throws      // Non-destructive tools only
func enableDevelopmentMode() async throws   // Balanced development tools
func resetToDefaults() async throws         // Clear all custom settings
```

**⚠️ Important:** These methods internally call `reconnect()` to apply settings changes. If you have active message receiving tasks (`receiveMessages()`), you must cancel and restart them after settings updates. See [Message Stream Handling](#️-important-message-stream-handling) section for details.

### 🔧 Tools API (ToolsAPI.swift)

Unified tool lifecycle management with intelligent call/result pairing.

#### Tool Message Streams
```swift
// Complete tool lifecycle (pending → completed/failed)
func toolMessages() -> AsyncThrowingStream<ToolMessage, Error>

// Filter by tool status
func pendingTools() -> AsyncThrowingStream<ToolMessage, Error>
func completedTools() -> AsyncThrowingStream<ToolMessage, Error>
func failedTools() -> AsyncThrowingStream<ToolMessage, Error>

// Filter by tool characteristics
func toolsWithName(_ name: String) -> AsyncThrowingStream<ToolMessage, Error>
func slowTools(threshold: TimeInterval) -> AsyncThrowingStream<ToolMessage, Error>
```

#### Tool Information & Analytics
```swift
// Current tool state
func getPendingToolCount() async throws -> Int
func getPendingToolInfo() async throws -> [ToolMessage]

// Tool performance analytics
func getToolStatistics() async throws -> [String: Any]
func waitForAllToolsToComplete(timeout: TimeInterval) async throws -> Bool
```

#### Tool Management & Recovery
```swift
// Manual tool completion (error recovery)
func manuallyCompleteTool(toolId: String, result: ToolMessage.ToolResult) async throws -> ToolMessage?
func manuallyFailTool(toolId: String, error: ToolMessage.ToolError) async throws -> ToolMessage?
```

#### Tool Message Structure
```swift
public struct ToolMessage: ContentBlock {
    public let id: String
    public let name: String
    public let input: [String: AnyCodable]
    public let result: ToolResult?
    public let status: ToolStatus          // .pending, .completed, .failed
    public let startTime: Date
    public let endTime: Date?
    public let error: ToolError?
    
    // Computed duration
    public var duration: TimeInterval? { ... }
    
    public enum ToolStatus: String, Codable, Sendable {
        case pending = "pending"
        case completed = "completed"  
        case failed = "failed"
    }
    
    public enum ToolResult: Codable, Sendable {
        case text(String)
        case structured([String: AnyCodable])
    }
    
    public struct ToolError: Codable, Sendable {
        public let message: String
        public let details: [String: AnyCodable]?
    }
}
```

#### Tool API Benefits
- ✅ **Zero manual correlation**: Tools automatically paired by ID
- ✅ **Real-time updates**: See tool progress as it happens
- ✅ **Rich debugging info**: Full execution context, timing, and error details
- ✅ **Type safety**: Strongly typed inputs and outputs throughout
- ✅ **Analytics ready**: Built-in performance metrics and duration tracking

## 📝 Message Types

### Message Types

All messages are unified under a single `Message` enum:

```swift
enum Message: Codable, Sendable {
    case user(UserMessage)           // User text/thinking only
    case assistant(AssistantMessage) // Assistant text/thinking only  
    case tool(ToolMessage)           // Unified tool lifecycle
    case system(SystemMessage)       // System metadata
    case result(ResultMessage)       // Session results
}
```

The SDK provides both raw message access and processed tool lifecycle management through the `ToolMessage` type.

### UserMessage
```swift
struct UserMessage: Codable, Sendable {
    let content: UserContent
    
    enum UserContent {
        case text(String)
        case blocks([any ContentBlock])
    }
}
```

### AssistantMessage
```swift
struct AssistantMessage: Codable, Sendable {
    let content: [any ContentBlock]
}
```

### Content Blocks

#### TextBlock
```swift
struct TextBlock: ContentBlock {
    let text: String
}
```

#### ToolMessage

The ToolMessage type provides complete tool lifecycle management by automatically pairing tool calls with their results:

```swift
struct ToolMessage: ContentBlock {
    let id: String
    let name: String
    let input: [String: AnyCodable]
    let result: ToolResult?
    let status: ToolStatus          // .pending, .completed, .failed
    let startTime: Date
    let endTime: Date?
    let error: ToolError?
    
    // Computed duration
    var duration: TimeInterval? { ... }
    
    enum ToolStatus: String, Codable, Sendable {
        case pending = "pending"
        case completed = "completed"  
        case failed = "failed"
    }
    
    enum ToolResult: Codable, Sendable {
        case text(String)
        case structured([String: AnyCodable])
    }
    
    struct ToolError: Codable, Sendable {
        let message: String
        let details: [String: AnyCodable]?
    }
}
```

**Benefits over separate blocks:**
- ✅ **Automatic pairing**: No manual correlation of tool calls to results
- ✅ **Real-time status**: See tools transition from pending → completed/failed
- ✅ **Rich timing data**: Built-in execution duration tracking
- ✅ **Error context**: Structured error information with details

### SystemMessage

Now with optimized direct field access for init messages:

```swift
struct SystemMessage: Codable, Sendable {
    let subtype: String
    
    // Init-specific fields (populated for "init" subtype)
    let cwd: String?                    // Working directory
    let sessionId: String?              // Session identifier  
    let tools: [String]?                // Available tools
    let mcpServers: [String]?           // MCP server list
    let model: String?                  // Claude model
    let permissionMode: String?         // Permission settings
    let slashCommands: [String]?        // Available slash commands
    let apiKeySource: String?           // API key source
    
    // Generic data for other system message types
    let genericData: [String: AnyCodable]?
}
```

**Usage Examples:**

```swift
// Direct field access - much more efficient!
if case .system(let systemMessage) = message {
    if systemMessage.subtype == "init" {
        print("Session: \(systemMessage.sessionId ?? "unknown")")
        print("Model: \(systemMessage.model ?? "default")")
        print("Tools: \(systemMessage.tools ?? [])")
        print("Working dir: \(systemMessage.cwd ?? "current")")
    }
}
```

### ResultMessage
```swift
struct ResultMessage: Codable, Sendable {
    let subtype: String
    let durationMs: Int
    let durationApiMs: Int
    let isError: Bool
    let numTurns: Int
    let sessionId: String
    let totalCostUsd: Double?
    let usage: [String: AnyCodable]?
    let result: String?
}
```

## 🔌 MCP Server Integration

Model Context Protocol (MCP) servers extend Claude's capabilities with custom tools and resources. The Swift SDK supports three ways to configure MCP servers:

### Dictionary Configuration (Programmatic)

Define servers directly in your code using type-safe configuration objects:

```swift
let mcpServers: [String: any MCPServerConfig] = [
    "filesystem": McpStdioServerConfig(
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/files"],
        env: ["NODE_ENV": "production"]
    ),
    "database": McpHttpServerConfig(
        url: "http://localhost:3000/mcp",
        headers: ["Authorization": "Bearer token"]
    ),
    "events": McpSSEServerConfig(
        url: "http://localhost:3001/events"
    )
]

let options = ClaudeCodeOptions(mcpServers: .dictionary(mcpServers))
```

### JSON String Configuration

Pass MCP server configuration as a JSON string:

```swift
let jsonConfig = """
{
    "mcpServers": {
        "filesystem": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp/sandbox"],
            "env": {"NODE_ENV": "production"}
        },
        "database": {
            "type": "http",
            "url": "http://localhost:3000/mcp",
            "headers": {"Authorization": "Bearer token123"}
        }
    }
}
"""

let options = ClaudeCodeOptions(mcpServers: .string(jsonConfig))
```

### File Path Configuration

Load MCP server configuration from a JSON file:

```swift
let configPath = URL(fileURLWithPath: "/path/to/mcp-config.json")
let options = ClaudeCodeOptions(mcpServers: .path(configPath))
```

### Builder Pattern Configuration

Use the fluent builder API for convenient configuration:

```swift
// Dictionary configuration
let options1 = ClaudeCodeOptionsBuilder()
    .systemPrompt("You are a helpful assistant")
    .mcpServers([
        "git-server": McpStdioServerConfig(
            command: "node", 
            args: ["git-mcp-server.js"]
        )
    ])
    .build()

// JSON string configuration
let options2 = ClaudeCodeOptionsBuilder()
    .mcpServersFromString(jsonConfig)
    .build()

// File path configuration
let options3 = ClaudeCodeOptionsBuilder()
    .mcpServersFromPath(URL(fileURLWithPath: "/config/mcp.json"))
    .build()
```

### MCP Server Types

The SDK supports three types of MCP server connections:

#### Stdio Servers
Run local processes and communicate via stdin/stdout:

```swift
McpStdioServerConfig(
    command: "python",           // Command to run
    args: ["-m", "my_server"],   // Command arguments
    env: ["PATH": "/usr/bin"]    // Environment variables (optional)
)
```

#### HTTP Servers
Connect to REST API endpoints:

```swift
McpHttpServerConfig(
    url: "http://localhost:3000/mcp",
    headers: ["Authorization": "Bearer token"]  // Optional headers
)
```

#### SSE Servers
Connect via Server-Sent Events for real-time streaming:

```swift
McpSSEServerConfig(
    url: "http://localhost:3001/events",
    headers: ["Authorization": "Bearer token"]  // Optional headers
)
```

### Popular MCP Servers

Here are some commonly used MCP servers you can integrate:

```swift
let popularServers: [String: any MCPServerConfig] = [
    // File system access
    "filesystem": McpStdioServerConfig(
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-filesystem", "/path/to/workspace"]
    ),
    
    // Git operations
    "git": McpStdioServerConfig(
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-git", "/path/to/repo"]
    ),
    
    // Database access (PostgreSQL example)
    "postgres": McpStdioServerConfig(
        command: "npx", 
        args: ["-y", "@modelcontextprotocol/server-postgres"],
        env: ["DATABASE_URL": "postgresql://user:pass@localhost/db"]
    ),
    
    // Web browsing
    "brave-search": McpStdioServerConfig(
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-brave-search"],
        env: ["BRAVE_API_KEY": "your-api-key"]
    ),
    
    // Custom HTTP API
    "company-api": McpHttpServerConfig(
        url: "https://api.company.com/mcp",
        headers: [
            "Authorization": "Bearer your-token",
            "X-API-Version": "2024-01"
        ]
    )
]

let options = ClaudeCodeOptions(mcpServers: .dictionary(popularServers))
```

### Configuration Files

For complex setups, consider using external configuration files:

**mcp-config.json:**
```json
{
    "mcpServers": {
        "development": {
            "type": "stdio",
            "command": "node",
            "args": ["dev-server.js"],
            "env": {"NODE_ENV": "development"}
        },
        "production-api": {
            "type": "http", 
            "url": "https://prod-api.company.com/mcp",
            "headers": {"Authorization": "Bearer prod-token"}
        }
    }
}
```

**Swift code:**
```swift
let configPath = URL(fileURLWithPath: "./config/mcp-config.json")
let options = ClaudeCodeOptions(mcpServers: .path(configPath))
```

This approach keeps sensitive configuration data separate from your code and allows different configurations for development, staging, and production environments.

## ⚠️ Error Handling

All operations throw `ClaudeSDKError` with detailed context:

```swift
do {
    for try await message in query(prompt: "Hello") {
        // Process messages
    }
} catch let error as ClaudeSDKError {
    switch error {
    case .cliNotFound(let paths):
        print("CLI not found. Searched: \(paths)")
    case .processError(let message, let exitCode):
        print("Process failed (\(exitCode)): \(message)")
    case .jsonDecodeError(let line, let error):
        print("JSON decode failed: \(error)")
    default:
        print("Error: \(error.localizedDescription)")
    }
    
    // Recovery suggestions
    if let suggestion = error.recoverySuggestion {
        print("Suggestion: \(suggestion)")
    }
}
```

## 🎯 Usage Patterns

### When to Use `query()` vs `ClaudeCodeSDKClient` vs **Settings Updates**

#### Use `query()` for:
- ✅ Simple one-off questions
- ✅ Code generation tasks
- ✅ Batch processing
- ✅ CI/CD automation
- ✅ Fire-and-forget operations

```swift
// Perfect for simple tasks
for try await message in query(prompt: "Generate a Swift struct for User") {
    // Handle response
}
```

#### Use `ClaudeCodeSDKClient` for:
- ✅ Interactive conversations
- ✅ Chat applications
- ✅ Multi-turn debugging
- ✅ Real-time collaboration
- ✅ Interrupt capabilities

```swift
// Perfect for interactive sessions
let client = ClaudeCodeSDKClient()
try await client.connect()

try await client.queryStream("Start debugging this function")
// ... analyze response, ask follow-ups
try await client.queryStream("What about this edge case?")

await client.disconnect()
```

#### Use **Dynamic Settings Updates** for:
- ✅ Mid-conversation requirement changes
- ✅ Adaptive permission modes
- ✅ Context-aware tool restrictions
- ✅ Progressive conversation refinement
- ✅ Interactive development workflows

```swift
// Perfect for adaptive conversations
let client = ClaudeCodeSDKClient()
try await client.connect()

try await client.queryStream("Let's build a secure API")

// Requirements change: Enable planning mode
try await client.updatePermissionMode(.plan)
try await client.queryStream("Actually, let's plan this first")

// Further refinement: Add security constraints
try await client.updateSettings { builder in
    builder.systemPrompt("Focus on security best practices")
    builder.disallowedTools(["Bash"])  // Restrict execution
}

try await client.queryStream("Now create the security-focused plan")
// → All context preserved, new constraints applied
```

### Tool Usage Examples

#### File Operations
```swift
let options = ClaudeCodeOptions(
    allowedTools: ["Read", "Write", "Glob", "Grep"],
    cwd: URL(fileURLWithPath: "/path/to/project")
)

for try await message in query(
    prompt: "Refactor the authentication module",
    options: options
) {
    // Claude can read, modify, and search files
}
```

#### Safe Execution
```swift
let options = ClaudeCodeOptions(
    allowedTools: ["Read", "Grep"],  // Read-only
    disallowedTools: ["Bash", "Write"],  // Prevent execution/modification
    permissionMode: .plan  // Planning only
)
```

### Session Management & Continuation

Claude Code SDK provides first-class support for continuing conversations and resuming specific sessions. You can either continue from the last conversation state or resume a specific session by ID.

#### Using ClaudeCodeSDKClient.reconnect()

The recommended approach for session continuation with interactive clients:

```swift
let client = ClaudeCodeSDKClient()

// Start initial conversation
try await client.connect()
try await client.queryStream("Let's build a web server")
// ... process responses
await client.disconnect()

// Later: Continue the last conversation
try await client.reconnect()  // Uses --continue flag
try await client.queryStream("Add authentication to the server")
// ... process continuation

// Or: Resume a specific session
try await client.reconnect(sessionId: "session-abc123")  // Uses --resume flag
try await client.queryStream("Continue working on session 123")
```

#### Using Convenience Query Functions

For simple one-shot continuation queries:

```swift
// Start initial conversation
for try await message in query(prompt: "Create a Python script") {
    // Process initial response
}

// Continue from last conversation
for try await message in continueQuery(prompt: "Add error handling") {
    // Process continuation - automatically uses --continue
}

// Resume specific session
for try await message in resumeQuery(
    prompt: "Update the authentication module", 
    sessionId: "session-abc123"
) {
    // Process resumed session - automatically uses --resume
}
```

#### Context Managers with Session Continuation

```swift
// Continue last conversation with context manager
let result = try await ClaudeCodeSDKClient.withReconnection { client in
    try await client.queryStream("Continue our discussion")
    return "completed"
}

// Resume specific session with context manager
let result = try await ClaudeCodeSDKClient.withReconnection(sessionId: "session-123") { client in
    try await client.queryStream("Pick up where we left off")
    return "completed"
}
```

#### Manual Configuration (Advanced)

For fine-grained control, you can still configure session options manually:

```swift
// Continue last conversation
let continueOptions = ClaudeCodeOptions(continueConversation: true)

// Resume specific session
let resumeOptions = ClaudeCodeOptions(resume: "session-abc123")

let client = ClaudeCodeSDKClient(options: resumeOptions)
try await client.connect()
// Conversation resumes from specified session
```

#### Continue vs Resume: When to Use Each

**Use `continue` (no session ID) when:**
- ✅ You want to pick up from the most recent conversation
- ✅ You're working on a single ongoing project  
- ✅ You don't need to manage multiple concurrent sessions
- ✅ Simple continuation workflow

**Use `resume` (with session ID) when:**
- ✅ You have multiple parallel conversations/projects
- ✅ You need to switch between different contexts
- ✅ You want explicit session management
- ✅ Building applications with multiple users or workspaces

```swift
// Example: Single project workflow
for try await _ in query(prompt: "Start a web API project") { }
for try await _ in continueQuery(prompt: "Add database models") { }
for try await _ in continueQuery(prompt: "Add authentication") { }

// Example: Multi-project workflow  
for try await message in query(prompt: "Start project A") {
    if case .result(let result) = message {
        let sessionA = result.sessionId
        // Later: resume project A
        for try await _ in resumeQuery(prompt: "Continue A", sessionId: sessionA) { }
    }
}

for try await message in query(prompt: "Start project B") {
    if case .result(let result) = message {
        let sessionB = result.sessionId  
        // Later: resume project B
        for try await _ in resumeQuery(prompt: "Continue B", sessionId: sessionB) { }
    }
}
```

#### Session Isolation
```swift
// Each client gets isolated session
let client1 = ClaudeCodeSDKClient()
let client2 = ClaudeCodeSDKClient()

try await client1.connect()
try await client2.connect()

// Separate conversation contexts
try await client1.queryStream("Remember: I prefer verbose code")
try await client2.queryStream("Remember: I prefer concise code")
```

### Interrupts and Control Flow

```swift
let client = ClaudeCodeSDKClient()
try await client.connect()

// Start long-running task
try await client.queryStream("Analyze this entire codebase and suggest improvements")

// Interrupt after 30 seconds if needed
Task {
    try await Task.sleep(nanoseconds: 30_000_000_000)
    try await client.interrupt()
}

for try await message in client.receiveMessages() {
    // Process messages until interrupted
}
```

## 🔍 Examples

### Code Generation
```swift
let options = ClaudeCodeOptions(
    systemPrompt: "Generate clean, well-documented Swift code",
    allowedTools: ["Write"],
    cwd: URL(fileURLWithPath: "./Sources")
)

for try await message in query(
    prompt: "Create a REST API client for a todo app",
    options: options
) {
    if case .result(let result) = message {
        print("Generated \(result.numTurns) files")
    }
}
```

### Code Review
```swift
let options = ClaudeCodeOptions(
    allowedTools: ["Read", "Grep", "Glob"],
    systemPrompt: "You are a senior code reviewer focused on Swift best practices"
)

for try await message in query(
    prompt: "Review the authentication implementation for security issues",
    options: options
) {
    // Claude reads and analyzes code files
}
```

### Interactive Debugging
```swift
let client = ClaudeCodeSDKClient(options: ClaudeCodeOptions(
    allowedTools: ["Read", "Bash", "Write"],
    permissionMode: .acceptEdits
))

try await client.connect()

try await client.queryStream("This function is crashing with a nil pointer. Help me debug it.")

for try await message in client.receiveResponse() {
    if case .assistant(let assistant) = message {
        // Claude reads code, runs tests, suggests fixes
    }
}

// Follow up based on findings
try await client.queryStream("Can you add unit tests for the fix?")
```

### Dynamic Settings Workflow (New!)
```swift
// Adaptive development with changing requirements
let client = ClaudeCodeSDKClient()
try await client.connect()

// Start: Exploratory development
try await client.queryStream("Help me explore building a payment system")

// Phase 1: Switch to planning mode when requirements clarify
try await client.updatePermissionMode(.plan)
try await client.queryStream("Let's create a detailed architecture plan")

// Phase 2: Move to implementation with appropriate tools
try await client.updateSettings { builder in
    builder.permissionMode(.acceptEdits)
    builder.systemPrompt("You are a payment systems expert focused on security")
    builder.allowedTools(["Read", "Write", "Grep"]) // No Bash for security
}
try await client.queryStream("Implement the core payment processing")

// Phase 3: Testing phase - enable bash for running tests
try await client.updateAllowedTools(["Read", "Write", "Bash", "Grep"])
try await client.queryStream("Create and run comprehensive tests")

// Phase 4: Documentation phase - read-only mode
try await client.updateSettings { builder in  
    builder.systemPrompt("Create comprehensive documentation")
    builder.allowedTools(["Read", "Grep"])  // Read-only
}
try await client.queryStream("Generate API documentation and deployment guide")

await client.disconnect()
```

### Session Continuation Workflow  
```swift
// Start a multi-step development project
var currentSessionId: String?

// Step 1: Initial setup
for try await message in query(prompt: "Create a Swift package for a todo app with Package.swift") {
    if case .result(let result) = message {
        currentSessionId = result.sessionId
        print("✅ Package setup complete. Session: \(result.sessionId)")
    }
}

// Step 2: Continue with models (using continue)
for try await message in continueQuery(prompt: "Add data models for Todo items") {
    if case .result(let result) = message {
        print("✅ Models added. Total cost so far: $\(result.totalCostUsd ?? 0)")
    }
}

// Step 3: Add API endpoints (using resume with specific session)
if let sessionId = currentSessionId {
    for try await message in resumeQuery(
        prompt: "Add REST API endpoints for CRUD operations",
        sessionId: sessionId
    ) {
        if case .result(let result) = message {
            print("✅ API endpoints complete")
        }
    }
}

// Alternative: Using interactive client with reconnection
let client = ClaudeCodeSDKClient()
try await client.connect()
try await client.queryStream("Start building a web scraper")

// Later, in a different part of your app...
try await client.reconnect()  // Continue last conversation
try await client.queryStream("Add error handling and retry logic")

await client.disconnect()
```

### Batch Processing
```swift
let tasks = [
    "Add documentation to UserService.swift",
    "Optimize the database queries in OrderRepository.swift", 
    "Add error handling to PaymentProcessor.swift"
]

for task in tasks {
    for try await message in query(prompt: task) {
        if case .result(let result) = message {
            print("✅ Completed: \(task) (Cost: $\(result.totalCostUsd ?? 0))")
        }
    }
}
```

## 🧪 Testing

Run the test suite:

```bash
swift test
```

Run with coverage:

```bash
swift test --enable-code-coverage
```

### Running the Interactive CLI Example

```bash
cd Examples/InteractiveCLI
swift run
```

The interactive CLI provides a real-time testing environment with commands like:
- Basic: `/help`, `/exit`, `/status`, `/clear`
- Messages: Type any message to send to Claude
- Interrupts: `/interrupt` to stop current operation
- **Enhanced Settings**: All settings use dynamic updates with session preservation:
  - `/system <prompt>` - Updates system prompt, preserves conversation
  - `/permission-mode <mode>` - Updates permission mode seamlessly
  - `/model <name>` - Changes model while maintaining context  
  - `/tools <list>` - Updates allowed tools dynamically
  - `/cwd <path>` - Changes working directory with session preservation
- Directory: `/add-dirs <paths>`
- Resume: `/resume <session-id>` to continue previous conversations

**🎯 Try the `/permission-mode plan` command to experience dynamic settings updates!**

**Implementation Note**: The Interactive CLI automatically handles message stream reconnection after settings updates. If you're building your own CLI using the SDK, see the [Message Stream Handling](#️-important-message-stream-handling) section for proper implementation.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes with tests
4. Run tests: `swift test`
5. Run the build: `swift build`
6. Commit changes: `git commit -m 'Add amazing feature'`
7. Push to branch: `git push origin feature/amazing-feature`
8. Open a Pull Request

### Development Guidelines

- Follow Swift API Design Guidelines
- Add comprehensive tests for new features
- Update documentation for API changes
- Ensure Swift 6 strict concurrency compliance
- Use meaningful commit messages


## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) - The underlying CLI tool
- [Claude API](https://docs.anthropic.com/en/api) - Direct API access
- [MCP Specification](https://modelcontextprotocol.io/) - Model Context Protocol standard

## 📞 Support

- 📖 [Documentation](https://docs.anthropic.com/en/docs/claude-code)
- 🐛 [Issues](https://github.com/your-username/ClaudeCodeSwiftSDK/issues)
- 💬 [Discussions](https://github.com/your-username/ClaudeCodeSwiftSDK/discussions)
- 📧 Email: support@example.com

## 🚀 Roadmap

- [ ] Xcode integration and source editor extensions
- [ ] SwiftUI components for chat interfaces
- [ ] Swift Package Plugin support
- [ ] Vapor middleware for web applications
- [ ] iOS/iPadOS support
- [ ] Enhanced error recovery mechanisms
- [ ] Custom tool development framework

---

Built with ❤️ for the Swift community
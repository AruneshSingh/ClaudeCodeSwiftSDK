# Claude Code Swift SDK

A Swift SDK for [Claude Code](https://claude.ai/code), providing programmatic access to Claude's powerful code generation and assistance capabilities through a type-safe, async/await API.

## ✨ Features

- **🎯 Type-Safe**: Comprehensive Swift types for all messages and content blocks
- **⚡ Async/Await**: Native Swift concurrency with `AsyncSequence` streaming
- **🔄 Bidirectional Communication**: Real-time interactive conversations with interrupt support
- **🛠 Tool Integration**: Full support for Claude's tool system (Read, Write, Bash, etc.)
- **⚙️ Highly Configurable**: Extensive configuration options for fine-tuned control
- **🔥 Dynamic Settings**: Update settings mid-conversation with automatic session preservation
- **🔗 MCP Support**: Model Context Protocol server integration
- **📦 Zero Dependencies**: Pure Swift implementation with no external dependencies
- **🎛 Permission Control**: Granular tool permissions and safety modes
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

## 🔍 Debug Logging

For development and troubleshooting, enable comprehensive debug logging:

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

```swift
class FileLogger: DebugLogger {
    func debug(_ message: @autoclosure @escaping () -> String, file: String, function: String, line: Int) {
        // Your custom debug implementation
    }
    // ... implement other methods
}

configureClaudeCodeSwiftSDK(debug: true, debugLogger: FileLogger())
```

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

#### ⚠️ Important: Message Stream Handling

When using dynamic settings updates, the client internally reconnects to apply changes. If you're running background tasks that receive messages, you must restart them after settings updates:

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

### Connection & Query APIs

#### Query Functions

```swift
// Simple query
func query(
    prompt: String,
    options: ClaudeCodeOptions? = nil
) async throws -> AsyncThrowingStream<Message, Error>

// Session continuation queries
func continueQuery(
    prompt: String,
    options: ClaudeCodeOptions? = nil
) async throws -> AsyncThrowingStream<Message, Error>

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
func connect(prompt: String) async throws

// Reconnects session with --continue or if sessionId available, --resume 
func reconnect(sessionId: String? = nil) async throws

// Disconnect
func disconnect() async
```

#### Message Handling

```swift
// Send query
func queryStream(_ prompt: String) async throws

// Receive all messages
func receiveMessages() -> AsyncThrowingStream<Message, Error>

// Receive until completion
func receiveResponse() -> AsyncThrowingStream<Message, Error>

// Send interrupt
func interrupt() async throws
```

### Settings Management

Dynamic configuration management with automatic session preservation:

```swift
// Individual setting updates with automatic session preservation
func updatePermissionMode(_ mode: PermissionMode) async throws
func updateSystemPrompt(_ prompt: String) async throws
func updateAllowedTools(_ tools: [String]) async throws
func updateModel(_ model: String) async throws  
func updateWorkingDirectory(_ cwd: URL) async throws
func updateMaxTurns(_ maxTurns: Int) async throws

// Batch settings update (most efficient - single reconnection)
func updateSettings(_ configure: (ClaudeCodeOptionsBuilder) -> Void) async throws

// Settings inspection
func getCurrentOptions() async -> ClaudeCodeOptions?
func getCurrentPermissionMode() async -> ClaudeCodeOptions.PermissionMode?
func getCurrentSystemPrompt() async -> String?
```


## 📝 Message Types

All messages are unified under a single `Message` enum:

```swift
enum Message: Codable, Sendable {
    case user(UserMessage)           // User text/tool results
    case assistant(AssistantMessage) // Assistant text/tool calls  
    case system(SystemMessage)       // System metadata
    case result(ResultMessage)       // Session results
}
```

### UserMessage
```swift
struct UserMessage: Codable, Sendable {
    let role: String
    let content: UserContent
    let parentToolUseId: String?
    let sessionId: String
    
    enum UserContent: Codable, Sendable {
        case text(String)
        case blocks([any ContentBlock])
    }
}
```

### AssistantMessage
```swift
struct AssistantMessage: Codable, Sendable {
    let id: String
    let role: String
    let content: [any ContentBlock]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: UsageInfo?
    let parentToolUseId: String?
    let sessionId: String
}
```

### Content Blocks

#### TextBlock
```swift
struct TextBlock: ContentBlock {
    let text: String
}
```

#### ToolUseBlock
```swift
struct ToolUseBlock: ContentBlock {
    let id: String
    let name: String
    let input: [String: AnyCodable]
}
```

#### ThinkingBlock
```swift
struct ThinkingBlock: ContentBlock {
    let thinking: String
    let signature: String
}
```

#### ToolResultBlock
```swift
struct ToolResultBlock: ContentBlock {
    let toolUseId: String
    let content: ContentResult?
    let isError: Bool?
    
    enum ContentResult: Codable {
        case text(String)
        case structured([String: AnyCodable])
    }
}
```

### SystemMessage

```swift
struct SystemMessage: Codable, Sendable {
    let subtype: String
    
    // Init-specific fields (populated for "init" subtype)
    let cwd: String?                    // Working directory
    let sessionId: String?              // Session identifier  
    let tools: [String]?                // Available tools
    let mcpServers: [MCPServerInfo]?    // MCP server list
    let model: String?                  // Claude model
    let permissionMode: String?         // Permission settings
    let slashCommands: [String]?        // Available slash commands
    let apiKeySource: String?           // API key source
    
    // Generic data field for other system message types
    let genericData: [String: AnyCodable]?
}

struct MCPServerInfo: Codable, Sendable {
    let name: String
    let status: String
}
```

### UsageInfo
```swift
struct UsageInfo: Codable, Sendable {
    let inputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
    let outputTokens: Int
    let serviceTier: String?
    let serverToolUse: [String: AnyCodable]?
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
    let usage: UsageInfo?
    let result: String?
}
```

## 🔌 MCP Server Integration

Model Context Protocol (MCP) servers extend Claude's capabilities with custom tools and resources. The Swift SDK supports three ways to configure MCP servers:

> **⚠️ Important: MCP Tool Permissions**
> 
> When using MCP servers, the tools they provide are **not automatically allowed**. You must explicitly include MCP tool names in your `allowedTools` configuration, unless you're using:
> - `permissionMode: .bypassPermissions` 
> - Claude CLI's `--dangerously-skip-permissions` flag
>
> **Example:**
> ```swift
> let options = ClaudeCodeOptions(
>     allowedTools: ["filesystem_read", "filesystem_write", "git_status"], // MCP tool names
>     permissionMode: .acceptEdits, // Or .default - but not .bypassPermissions
>     mcpServers: .dictionary(mcpServers)
> )
> ```

### Dictionary Configuration (Programmatic)

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
    )
]

let options = ClaudeCodeOptions(mcpServers: .dictionary(mcpServers))
```

### JSON String Configuration

```swift
let jsonConfig = """
{
    "mcpServers": {
        "filesystem": {
            "type": "stdio",
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-filesystem", "/tmp/sandbox"]
        }
    }
}
"""

let options = ClaudeCodeOptions(mcpServers: .string(jsonConfig))
```

### File Path Configuration

```swift
let configPath = URL(fileURLWithPath: "/path/to/mcp-config.json")
let options = ClaudeCodeOptions(mcpServers: .path(configPath))
```

## ⚠️ Error Handling

All operations throw `ClaudeSDKError` with detailed context, recovery suggestions, and failure reasons:

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
    case .invalidConfiguration(let reason):
        print("Invalid config: \(reason)")
    case .processTerminated:
        print("Process terminated unexpectedly")
    case .timeout(let duration):
        print("Timeout after \(duration) seconds")
    case .invalidMessageType(let description):
        print("Invalid message: \(description)")
    case .unexpectedStreamEnd:
        print("Stream ended unexpectedly")
    case .messageParseError(let message, let data):
        print("Parse error: \(message)")
    case .cliConnectionError(let underlying):
        print("Connection error: \(underlying)")
    }
    
    // Recovery suggestions and failure reasons
    if let suggestion = error.recoverySuggestion {
        print("Suggestion: \(suggestion)")
    }
    if let reason = error.failureReason {
        print("Reason: \(reason)")
    }
}
```

## 🎯 Usage Patterns

### When to Use `query()` vs `ClaudeCodeSDKClient`

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

### Session Management & Continuation

```swift
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

### Dynamic Settings Workflow
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

await client.disconnect()
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
- Settings: `/system <prompt>`, `/permission-mode <mode>`, `/model <name>`, `/tools <list>`, `/cwd <path>`
- Directory: `/add-dirs <paths>`
- Resume: `/resume <session-id>` to continue previous conversations

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

## 📞 Support

- 🙋‍♂️ [Email Arunesh](hey@arune.sh)
- 📖 [Documentation](https://docs.anthropic.com/en/docs/claude-code)
- 🐛 [Issues](https://github.com/your-username/ClaudeCodeSwiftSDK/issues)
- 💬 [Discussions](https://github.com/your-username/ClaudeCodeSwiftSDK/discussions)


---

Built with ❤️ for the Swift community
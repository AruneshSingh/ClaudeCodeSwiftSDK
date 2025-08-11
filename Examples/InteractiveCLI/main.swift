// Interactive CLI for testing ClaudeCodeSwiftSDK streaming functionality

import Foundation
import ClaudeCodeSwiftSDK

// MARK: - Console Helpers

func print(_ message: String, terminator: String = "\n") {
    Swift.print(message, terminator: terminator)
    fflush(stdout)
}

func printError(_ message: String) {
    fputs("❌ \(message)\n", stderr)
    fflush(stderr)
}

func printSuccess(_ message: String) {
    print("✅ \(message)")
}

func printInfo(_ message: String) {
    print("ℹ️  \(message)")
}

func printPrompt() {
    print("\n> ", terminator: "")
}

func readLine() -> String? {
    return Swift.readLine()
}

// MARK: - Message Formatting

func formatUsageInfo(_ usage: UsageInfo) -> String {
    var parts: [String] = []
    parts.append("📊 in: \(usage.inputTokens)")
    parts.append("out: \(usage.outputTokens)")
    
    if let cacheCreation = usage.cacheCreationInputTokens, cacheCreation > 0 {
        parts.append("cache_create: \(cacheCreation)")
    }
    if let cacheRead = usage.cacheReadInputTokens, cacheRead > 0 {
        parts.append("cache_read: \(cacheRead)")
    }
    if let tier = usage.serviceTier {
        parts.append("tier: \(tier)")
    }
    
    return parts.joined(separator: ", ")
}

func formatMessage(_ message: Message) -> String {
    switch message {
    case .user(let userMessage):
        let parentIndicator = userMessage.parentToolUseId != nil ? " 🤖" : ""
        switch userMessage.content {
        case .text(let text):
            if text.isEmpty {
                return "👤 User\(parentIndicator): [empty message]"
            }
            return "👤 User\(parentIndicator): \(text)"
        case .blocks(let blocks):
            if blocks.isEmpty {
                return "👤 User\(parentIndicator): [empty message]"
            }
            var result = "👤 User\(parentIndicator):"
            for block in blocks {
                if let textBlock = block as? TextBlock {
                    result += "\n   \(textBlock.text)"
                } else if let thinkingBlock = block as? ThinkingBlock {
                    result += "\n   🤔 Thinking: \(thinkingBlock.thinking.prefix(200))..."
                    result += "\n   📝 Signature: \(thinkingBlock.signature)"
                } else if let toolResultBlock = block as? ToolResultBlock {
                    result += "\n   📊 Tool Result (id: \(toolResultBlock.toolUseId))"
                    if let content = toolResultBlock.content {
                        switch content {
                        case .text(let text):
                            if !text.isEmpty {
                                result += "\n   Result: \(text.prefix(200))..." // Truncate long results
                            }
                        case .structured(let data):
                            result += "\n   Structured result: \(data.count) fields"
                        }
                    }
                    if toolResultBlock.isError == true {
                        result += "\n   ⚠️ Tool execution error"
                    }
                } else {
                    result += "\n   [Content block]"
                }
            }
            return result
        }
        
    case .assistant(let assistantMessage):
        let parentIndicator = assistantMessage.parentToolUseId != nil ? " 🤖" : ""
        var result = "🤖 Assistant\(parentIndicator) (\(assistantMessage.model)):"
        for block in assistantMessage.content {
            switch block {
            case let textBlock as TextBlock:
                result += "\n   \(textBlock.text)"
            case let thinkingBlock as ThinkingBlock:
                result += "\n   🤔 Thinking: \(thinkingBlock.thinking.prefix(200))..."
                result += "\n   📝 Signature: \(thinkingBlock.signature)"
            case let toolUseBlock as ToolUseBlock:
                result += "\n   🔧 Tool: \(toolUseBlock.name) (id: \(toolUseBlock.id))"
                // Show input parameters (first few only to avoid clutter)
                if !toolUseBlock.input.isEmpty {
                    let inputCount = toolUseBlock.input.count
                    let preview = toolUseBlock.input.prefix(3).map { "\($0.key): \($0.value.value)" }
                    result += "\n   📥 Input: \(preview.joined(separator: ", "))"
                    if inputCount > 3 {
                        result += " (+ \(inputCount - 3) more)"
                    }
                }
            default:
                result += "\n   [Unknown content block]"
            }
        }
        
        // Add usage information if available
        if let usage = assistantMessage.usage {
            result += "\n   " + formatUsageInfo(usage)
        }
        
        return result
        
        
    case .system(let systemMessage):
        var result = "🔧 System: \(systemMessage.subtype)"
        
        // Show structured init data if available
        if systemMessage.subtype == "init" {
            if let sessionId = systemMessage.sessionId {
                result += "\n   📋 Session: \(sessionId)"
            }
            if let model = systemMessage.model {
                result += "\n   🤖 Model: \(model)"
            }
            if let cwd = systemMessage.cwd {
                result += "\n   📁 Working Dir: \(cwd)"
            }
            if let tools = systemMessage.tools, !tools.isEmpty {
                result += "\n   🛠️  Tools: \(tools.prefix(5).joined(separator: ", "))"
                if tools.count > 5 {
                    result += " (+ \(tools.count - 5) more)"
                }
            }
            if let permissionMode = systemMessage.permissionMode {
                result += "\n   🔒 Permission: \(permissionMode)"
            }
            if let mcpServers = systemMessage.mcpServers, !mcpServers.isEmpty {
                let serverStatuses = mcpServers.map { server in
                    let status = server.status == "connected" ? "✅" : "❌"
                    return "\(server.name) \(status)"
                }
                result += "\n   🔌 MCP Servers: \(serverStatuses.joined(separator: ", "))"
            }
            if let slashCommands = systemMessage.slashCommands, !slashCommands.isEmpty {
                result += "\n   ⌨️  Commands: \(slashCommands.prefix(3).joined(separator: ", "))"
                if slashCommands.count > 3 {
                    result += " (+ \(slashCommands.count - 3) more)"
                }
            }
        } else {
            // Show generic data for other system message types
            if let genericData = systemMessage.genericData, !genericData.isEmpty {
                result += " - \(genericData)"
            }
        }
        
        return result
        
    case .result(let resultMessage):
        var result = "📊 Result:"
        result += "\n   Session ID: \(resultMessage.sessionId)"
        result += "\n   Duration: \(resultMessage.durationMs)ms"
        result += "\n   API Duration: \(resultMessage.durationApiMs)ms"
        result += "\n   Turns: \(resultMessage.numTurns)"
        if let cost = resultMessage.totalCostUsd {
            result += "\n   Cost: $\(String(format: "%.6f", cost))"
        }
        
        // Add usage information if available
        if let usage = resultMessage.usage {
            result += "\n   " + formatUsageInfo(usage)
        }
        
        if resultMessage.isError {
            result += "\n   ⚠️ Error occurred"
        }
        return result
    }
}

// MARK: - Command Processing

enum Command {
    case message(String)
    case interrupt
    case exit
    case help
    case status
    case clear
    case system(String)
    case appendSystem(String)
    case model(String)
    case tools(String)
    case disallowedTools(String)
    case workingDir(String)
    case addDirs(String)
    case maxTurns(String)
    case permissionMode(String)
    case permissionPromptToolName(String)
    case resume(String)
    case settings(String)
}

func parseCommand(_ input: String) -> Command? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if trimmed.isEmpty {
        return nil
    }
    
    if trimmed.hasPrefix("/") {
        let parts = trimmed.dropFirst().split(separator: " ", maxSplits: 1)
        let command = String(parts.first ?? "")
        let argument = parts.count > 1 ? String(parts[1]) : ""
        
        switch command {
        case "exit", "quit", "q":
            return .exit
        case "help", "h", "?":
            return .help
        case "interrupt", "int", "i":
            return .interrupt
        case "status", "s":
            return .status
        case "clear", "c":
            return .clear
        case "system":
            return .system(argument)
        case "append-system":
            return .appendSystem(argument)
        case "model":
            return .model(argument)
        case "tools", "allowed-tools":
            return .tools(argument)
        case "disallowed-tools":
            return .disallowedTools(argument)
        case "cwd", "dir":
            return .workingDir(argument)
        case "add-dirs":
            return .addDirs(argument)
        case "max-turns":
            return .maxTurns(argument)
        case "permission-mode":
            return .permissionMode(argument)
        case "permission-prompt-tool":
            return .permissionPromptToolName(argument)
        case "resume":
            return .resume(argument)
        case "settings":
            return .settings(argument)
        default:
            printError("Unknown command: /\(command)")
            return nil
        }
    } else {
        return .message(trimmed)
    }
}

func printHelp() {
    print("""
    
    🤖 Claude Code Interactive CLI
    
    Basic Commands:
      /help, /h, /?                     Show this help message
      /exit, /quit, /q                  Exit the program
      /interrupt, /int, /i              Interrupt current operation
      /status, /s                       Show connection status
      /clear, /c                        Clear the screen
    
    Conversation Settings:
      /system <prompt>                  Set system prompt
      /append-system <prompt>           Append to system prompt
      /model <name>                     Set model (e.g., claude-3-sonnet-20241022)
      /max-turns <number>               Set maximum conversation turns
      /resume <session-id>              Resume from previous session (auto-reconnects)
    
    Tool Configuration:
      /tools <list>                     Set allowed tools (comma-separated)
      /allowed-tools <list>             Alias for /tools
      /disallowed-tools <list>          Set disallowed tools (comma-separated)
      /permission-mode <mode>           Set permission mode (default/acceptEdits/bypassPermissions/plan)
      /permission-prompt-tool <name>    Set permission prompt tool name
    
    Working Directory:
      /cwd <path>                       Set working directory
      /dir <path>                       Alias for /cwd
      /add-dirs <paths>                 Add additional directories (comma-separated)
    
    Configuration:
      /settings <path>                  Set settings file path
    
    Just type your message and press Enter to send it to Claude.
    
    Note: Most settings update dynamically with automatic session preservation! 
    Settings like system prompt, tools, permission mode, etc. preserve your 
    conversation context when changed.
    
    You can interrupt Claude at any time by typing /interrupt.
    Claude will gracefully stop after completing its current tool operations.
    The CLI supports concurrent input handling for real-time interrupts!
    """)
}

// MARK: - Main Application

@main
struct InteractiveCLI {
    @MainActor static var client: ClaudeCodeSDKClient?
    @MainActor static var isConnected = false
    @MainActor static var sessionId = "default"
    @MainActor static var options: ClaudeCodeOptions = {
        // Load MCP servers from the git-mcp-server.json file
        let mcpConfigPath = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("git-mcp-server.json")
        
        return ClaudeCodeOptions(
            allowedTools: ["mcp__git"],
            permissionMode: .acceptEdits,
            mcpServers: .path(mcpConfigPath),
            model: "claude-opus-4-20250514"
        )
    }()
    @MainActor static var isWaitingForResponse = false
    @MainActor static var inputTask: Task<Void, Never>?
    @MainActor static var receiveTask: Task<Void, Never>?
    @MainActor static var shouldExit = false
    
    @MainActor
    static func main() async {
        // Enable debug logging for development
        configureClaudeCodeSwiftSDK(debug: true)
        
        print("""
        ╔═════════════════════════════════════════════════════════╗
        ║   Claude Code Interactive CLI by Arunesh & Claude v0    ║
        ║   Type /help for commands                               ║
        ╚═════════════════════════════════════════════════════════╝
        """)
        
        // Print configuration details
        printInfo("Configuration Options:")
        printInfo("  Model: \(options.model ?? "default")")
        printInfo("  Allowed Tools: \(options.allowedTools.isEmpty ? "all" : options.allowedTools.joined(separator: ", "))")
        printInfo("  Disallowed Tools: \(options.disallowedTools.isEmpty ? "none" : options.disallowedTools.joined(separator: ", "))")
        
        // Print MCP servers info
        switch options.mcpServers {
        case .dictionary(let servers):
            if servers.isEmpty {
                printInfo("  MCP Servers: none")
            } else {
                printInfo("  MCP Servers: \(servers.keys.joined(separator: ", "))")
            }
        case .string(_):
            printInfo("  MCP Servers: configured via JSON string")
        case .path(let url):
            printInfo("  MCP Servers: configured via file at \(url.path)")
        }
        
        do {
            // Initialize client
            client = ClaudeCodeSDKClient(options: options)
            
            // Connect with empty stream for interactive use
            printInfo("Connecting to Claude Code CLI...")
            try await client!.connect()
            isConnected = true
            printSuccess("Connected! Ready for interactive conversation.")
            
            // Start receiving messages in background
            receiveTask = Task {
                await receiveMessages()
            }
            
            // Start input handling in background
            inputTask = Task {
                await handleInputConcurrently()
            }
            
            // Wait for exit signal
            while !shouldExit {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            // Cleanup
            inputTask?.cancel()
            receiveTask?.cancel()
            
        } catch {
            printError("Failed to start: \(error)")
        }
        
        // Cleanup
        if let client = client {
            await client.disconnect()
        }
    }
    
    @MainActor
    static func handleInputConcurrently() async {
        while !shouldExit {
            // Use async version of readLine
            if let input = await readLineAsync() {
                guard let command = parseCommand(input) else {
                    printPrompt()
                    continue
                }
                
                switch command {
                case .message(let text):
                    await sendMessage(text)
                    
                case .interrupt:
                    await interruptOperation()
                    
                case .exit:
                    shouldExit = true
                    print("👋 Goodbye!")
                    return
                    
                case .help:
                    printHelp()
                    
                case .status:
                    printStatus()
                    
                case .clear:
                    print("\u{001B}[2J\u{001B}[H", terminator: "") // ANSI clear screen
                    
                    
                case .system(let prompt):
                    if !prompt.isEmpty {
                        do {
                            // Cancel old receive task before settings update
                            receiveTask?.cancel()
                            
                            try await client?.updateSystemPrompt(prompt)
                            printSuccess("System prompt updated and session preserved")
                            
                            // Restart receive task with new connection
                            receiveTask = Task {
                                await receiveMessages()
                            }
                        } catch {
                            printError("Failed to update system prompt: \(error)")
                        }
                    } else {
                        printInfo("Current system prompt: \(options.systemPrompt ?? "none")")
                    }
                    
                case .model(let model):
                    if !model.isEmpty {
                        do {
                            // Cancel old receive task before settings update
                            receiveTask?.cancel()
                            
                            try await client?.updateModel(model)
                            printSuccess("Model set to \(model) and session preserved")
                            
                            // Restart receive task with new connection
                            receiveTask = Task {
                                await receiveMessages()
                            }
                        } catch {
                            printError("Failed to update model: \(error)")
                        }
                    } else {
                        printInfo("Current model: \(options.model ?? "default")")
                    }
                    
                case .tools(let tools):
                    if !tools.isEmpty {
                        let toolList = tools.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        do {
                            // Cancel old receive task before settings update
                            receiveTask?.cancel()
                            
                            try await client?.updateAllowedTools(toolList)
                            printSuccess("Allowed tools updated: \(toolList.joined(separator: ", ")) and session preserved")
                            
                            // Restart receive task with new connection
                            receiveTask = Task {
                                await receiveMessages()
                            }
                        } catch {
                            printError("Failed to update allowed tools: \(error)")
                        }
                    } else {
                        printInfo("Current allowed tools: \(options.allowedTools.joined(separator: ", "))")
                    }
                    
                case .workingDir(let path):
                    if !path.isEmpty {
                        do {
                            // Cancel old receive task before settings update
                            receiveTask?.cancel()
                            
                            try await client?.updateWorkingDirectory(URL(fileURLWithPath: path))
                            printSuccess("Working directory set to \(path) and session preserved")
                            
                            // Restart receive task with new connection
                            receiveTask = Task {
                                await receiveMessages()
                            }
                        } catch {
                            printError("Failed to update working directory: \(error)")
                        }
                    } else {
                        printInfo("Current working directory: \(options.cwd?.path ?? "none")")
                    }
                    
                case .appendSystem(let prompt):
                    if !prompt.isEmpty {
                        do {
                            // Cancel old receive task before settings update
                            receiveTask?.cancel()
                            
                            let promptValue = prompt
                            try await client?.updateSettings { @Sendable builder in
                                builder.appendSystemPrompt(promptValue)
                            }
                            printSuccess("Append system prompt updated and session preserved")
                            
                            // Restart receive task with new connection
                            receiveTask = Task {
                                await receiveMessages()
                            }
                        } catch {
                            printError("Failed to update append system prompt: \(error)")
                        }
                    } else {
                        printInfo("Current append system prompt: \(options.appendSystemPrompt ?? "none")")
                    }
                    
                case .disallowedTools(let tools):
                    if !tools.isEmpty {
                        let toolList = tools.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        do {
                            // Cancel old receive task before settings update
                            receiveTask?.cancel()
                            
                            try await client?.updateDisallowedTools(toolList)
                            printSuccess("Disallowed tools updated: \(toolList.joined(separator: ", ")) and session preserved")
                            
                            // Restart receive task with new connection
                            receiveTask = Task {
                                await receiveMessages()
                            }
                        } catch {
                            printError("Failed to update disallowed tools: \(error)")
                        }
                    } else {
                        printInfo("Current disallowed tools: \(options.disallowedTools.joined(separator: ", "))")
                    }
                    
                case .addDirs(let paths):
                    if !paths.isEmpty {
                        let pathList = paths.split(separator: ",").map { URL(fileURLWithPath: $0.trimmingCharacters(in: .whitespaces)) }
                        do {
                            // Cancel old receive task before settings update
                            receiveTask?.cancel()
                            
                            let dirs = pathList
                            try await client?.updateSettings { @Sendable builder in
                                builder.addDirs(dirs)
                            }
                            printSuccess("Additional directories updated: \(pathList.map(\.path).joined(separator: ", ")) and session preserved")
                            
                            // Restart receive task with new connection
                            receiveTask = Task {
                                await receiveMessages()
                            }
                        } catch {
                            printError("Failed to update additional directories: \(error)")
                        }
                    } else {
                        printInfo("Current additional directories: \(options.addDirs.map(\.path).joined(separator: ", "))")
                    }
                    
                case .maxTurns(let turns):
                    if !turns.isEmpty {
                        if let maxTurns = Int(turns) {
                            do {
                                // Cancel old receive task before settings update
                                receiveTask?.cancel()
                                
                                try await client?.updateMaxTurns(maxTurns)
                                printSuccess("Max turns set to \(maxTurns) and session preserved")
                                
                                // Restart receive task with new connection
                                receiveTask = Task {
                                    await receiveMessages()
                                }
                            } catch {
                                printError("Failed to update max turns: \(error)")
                            }
                        } else {
                            printError("Invalid number for max turns: \(turns)")
                        }
                    } else {
                        printInfo("Current max turns: \(options.maxTurns?.description ?? "unlimited")")
                    }
                    
                case .permissionMode(let mode):
                    if !mode.isEmpty {
                        if let permissionMode = ClaudeCodeOptions.PermissionMode(rawValue: mode) {
                            do {
                                // Cancel old receive task before settings update
                                receiveTask?.cancel()
                                
                                try await client?.updatePermissionMode(permissionMode)
                                printSuccess("Permission mode set to \(mode) and session preserved")
                                
                                // Restart receive task with new connection
                                receiveTask = Task {
                                    await receiveMessages()
                                }
                            } catch {
                                printError("Failed to update permission mode: \(error)")
                            }
                        } else {
                            printError("Invalid permission mode: \(mode). Valid options: default, acceptEdits, bypassPermissions, plan")
                        }
                    } else {
                        printInfo("Current permission mode: \(options.permissionMode?.rawValue ?? "none")")
                    }
                    
                case .permissionPromptToolName(let name):
                    if !name.isEmpty {
                        do {
                            // Cancel old receive task before settings update
                            receiveTask?.cancel()
                            
                            let toolName = name
                            try await client?.updateSettings { @Sendable builder in
                                builder.permissionPromptToolName(toolName)
                            }
                            printSuccess("Permission prompt tool name set to: \(name) and session preserved")
                            
                            // Restart receive task with new connection
                            receiveTask = Task {
                                await receiveMessages()
                            }
                        } catch {
                            printError("Failed to update permission prompt tool name: \(error)")
                        }
                    } else {
                        printInfo("Current permission prompt tool name: \(options.permissionPromptToolName ?? "none")")
                    }
                    

                    
                case .resume(let sessionId):
                    if !sessionId.isEmpty {
                        await resumeSession(sessionId: sessionId)
                    } else {
                        printInfo("Current resume session ID: \(options.resume ?? "none")")
                    }
                    
                case .settings(let path):
                    if !path.isEmpty {
                        do {
                            // Cancel old receive task before settings update
                            receiveTask?.cancel()
                            
                            let settingsPath = path
                            try await client?.updateSettings { @Sendable builder in
                                builder.settings(settingsPath)
                            }
                            printSuccess("Settings path set to: \(path) and session preserved")
                            
                            // Restart receive task with new connection
                            receiveTask = Task {
                                await receiveMessages()
                            }
                        } catch {
                            printError("Failed to update settings path: \(error)")
                        }
                    } else {
                        printInfo("Current settings path: \(options.settings ?? "none")")
                    }
                }
                
                printPrompt()
            } else {
                // No input available, wait a bit
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }
        }
    }
    
    @MainActor
    static func readLineAsync() async -> String? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let input = readLine()
                continuation.resume(returning: input)
            }
        }
    }
    
    @MainActor
    static func sendMessage(_ text: String) async {
        guard isConnected, let client = client else {
            printError("Not connected. Please restart the application.")
            return
        }
        
        do {
            isWaitingForResponse = true
            try await client.queryStream(text, sessionId: sessionId)
            // Don't print "waiting for response" since we're concurrent now
        } catch {
            printError("Failed to send message: \(error)")
            isWaitingForResponse = false
        }
    }
    
    @MainActor
    static func resumeSession(sessionId: String) async {
        guard let currentClient = client else {
            printError("No client to reconnect")
            return
        }
        
        do {
            printInfo("Resuming session: \(sessionId)...")
            
            // Cancel the old receive task
            receiveTask?.cancel()
            
            // Use the built-in reconnect API with session ID
            try await currentClient.reconnect(sessionId: sessionId)
            
            // Restart the receive task
            receiveTask = Task {
                await receiveMessages()
            }
            
            printSuccess("Successfully resumed session: \(sessionId)")
            
        } catch {
            printError("Failed to resume session: \(error)")
            isConnected = false
        }
    }
    
    
    @MainActor
    static func interruptOperation() async {
        guard isConnected, let client = client else {
            printError("Not connected.")
            return
        }
        
        do {
            printInfo("Sending interrupt signal...")
            try await client.interrupt()
            printSuccess("Interrupt signal sent")
            printInfo("Claude will stop after completing current tool operations.")
            printInfo("This may take a few seconds depending on the current task.")
        } catch {
            printError("Failed to interrupt: \(error)")
        }
    }
    
    @MainActor
    static func printStatus() {
        print("""
        
        📊 Status:
           Connected: \(isConnected ? "Yes ✅" : "No ❌")
           Current Session ID: \(sessionId)
           Waiting for Response: \(isWaitingForResponse ? "Yes ⏳" : "No")
        
        Conversation Settings:
           System Prompt: \(options.systemPrompt ?? "none")
           Append System Prompt: \(options.appendSystemPrompt ?? "none")
           Model: \(options.model ?? "default")
           Max Turns: \(options.maxTurns?.description ?? "unlimited")
           Continue Conversation: \(options.continueConversation)
           Resume Session ID: \(options.resume ?? "none")
        
        Tool Configuration:
           Allowed Tools: \(options.allowedTools.isEmpty ? "all" : options.allowedTools.joined(separator: ", "))
           Disallowed Tools: \(options.disallowedTools.isEmpty ? "none" : options.disallowedTools.joined(separator: ", "))
           Permission Mode: \(options.permissionMode?.rawValue ?? "default")
           Permission Prompt Tool: \(options.permissionPromptToolName ?? "none")
        
        Working Directory:
           Current Directory: \(options.cwd?.path ?? "none")
           Additional Directories: \(options.addDirs.isEmpty ? "none" : options.addDirs.map(\.path).joined(separator: ", "))
        
        Configuration:
           Settings Path: \(options.settings ?? "none")
        """)
    }
    
    @MainActor
    static func receiveMessages() async {
        guard let client = client else { return }
        
        // Print initial prompt
        printPrompt()
        
        do {
            for try await message in client.receiveMessages() {
                // Skip empty user messages (they're just tool result placeholders)
                if case .user(let userMessage) = message {
                    switch userMessage.content {
                    case .text(let text):
                        if text.isEmpty {
                            continue
                        }
                    case .blocks(let blocks):
                        if blocks.isEmpty {
                            continue
                        }
                    }
                }
                
                // Save cursor position and clear line if needed
                if case .system = message {
                    // Don't clear line for system messages
                } else {
                    print("\r\u{001B}[K", terminator: "") // Clear current line
                }
                
                print(formatMessage(message))
                fflush(stdout) // Force flush output
                
                // Always print prompt after any message
                if case .result = message {
                    isWaitingForResponse = false
                }
                printPrompt()
            }
        } catch {
            printError("Error receiving messages: \(error)")
            isConnected = false
            shouldExit = true
        }
    }
}

// CLI argument building for Claude Code CLI subprocess

import Foundation

/// Builds command-line arguments for Claude Code CLI invocation
struct ArgumentBuilder {
    
    /// Build command line arguments based on mode and options
    /// - Parameters:
    ///   - isStreaming: Whether this is for streaming mode
    ///   - options: Configuration options
    /// - Returns: Array of command line arguments
    static func buildArguments(isStreaming: Bool, options: ClaudeCodeOptions?) -> [String] {
        var args: [String] = []
        
        // Always start with output format and verbose
        args.append("--output-format")
        args.append("stream-json")
        args.append("--verbose")
        
        // Add input format for streaming mode
        if isStreaming {
            args.append("--input-format")
            args.append("stream-json")
        }
        
        // Add options if provided
        if let options = options {
            addSystemPromptArgs(&args, options: options)
            addTurnLimitArgs(&args, options: options)
            addToolArgs(&args, options: options)
            addModelArgs(&args, options: options)
            addPermissionArgs(&args, options: options)
            addSessionArgs(&args, options: options)
            addSettingsArgs(&args, options: options)
            addDirectoryArgs(&args, options: options)
            addMCPArgs(&args, options: options)
            addExtraArgs(&args, options: options)
        }
        
        // Add --print flag for non-streaming mode
        if !isStreaming {
            args.append("--print")
        }
        
        return args
    }
    
    // MARK: - Private Argument Building Methods
    
    /// Add system prompt related arguments
    private static func addSystemPromptArgs(_ args: inout [String], options: ClaudeCodeOptions) {
        // System prompt
        if let systemPrompt = options.systemPrompt {
            args.append("--system-prompt")
            args.append(systemPrompt)
        }
        
        // Append system prompt
        if let appendSystemPrompt = options.appendSystemPrompt {
            args.append("--append-system-prompt")
            args.append(appendSystemPrompt)
        }
    }
    
    /// Add turn limit arguments
    private static func addTurnLimitArgs(_ args: inout [String], options: ClaudeCodeOptions) {
        // Max turns (exists but not documented in --help)
        if let maxTurns = options.maxTurns {
            args.append("--max-turns")
            args.append(String(maxTurns))
        }
    }
    
    /// Add tool-related arguments
    private static func addToolArgs(_ args: inout [String], options: ClaudeCodeOptions) {
        // Allowed tools
        if !options.allowedTools.isEmpty {
            args.append("--allowedTools")
            args.append(options.allowedTools.joined(separator: ","))
        }
        
        // Disallowed tools
        if !options.disallowedTools.isEmpty {
            args.append("--disallowedTools")
            args.append(options.disallowedTools.joined(separator: ","))
        }
    }
    
    /// Add model selection arguments
    private static func addModelArgs(_ args: inout [String], options: ClaudeCodeOptions) {
        // Model
        if let model = options.model {
            args.append("--model")
            args.append(model)
        }
    }
    
    /// Add permission-related arguments
    private static func addPermissionArgs(_ args: inout [String], options: ClaudeCodeOptions) {
        // Permission mode
        if let permissionMode = options.permissionMode {
            args.append("--permission-mode")
            args.append(permissionMode.rawValue)
        }
        
        // Permission prompt tool name (undocumented but used by Python SDK)
        if let toolName = options.permissionPromptToolName {
            args.append("--permission-prompt-tool")
            args.append(toolName)
        }
    }
    
    /// Add session management arguments
    private static func addSessionArgs(_ args: inout [String], options: ClaudeCodeOptions) {
        // Continue conversation
        if options.continueConversation {
            args.append("--continue")
        }
        
        // Resume session ID
        if let sessionId = options.resume {
            args.append("--resume")
            args.append(sessionId)
        }
    }
    
    /// Add settings file arguments
    private static func addSettingsArgs(_ args: inout [String], options: ClaudeCodeOptions) {
        // Settings
        if let settings = options.settings {
            args.append("--settings")
            args.append(settings)
        }
    }
    
    /// Add directory-related arguments
    private static func addDirectoryArgs(_ args: inout [String], options: ClaudeCodeOptions) {
        // Add directories
        for dir in options.addDirs {
            args.append("--add-dir")
            args.append(dir.path)
        }
    }
    
    /// Add MCP (Model Context Protocol) arguments
    private static func addMCPArgs(_ args: inout [String], options: ClaudeCodeOptions) {
        // MCP servers
        switch options.mcpServers {
        case .dictionary(let servers):
            if !servers.isEmpty {
                // Dict format: serialize to JSON
                let mcpConfig = ["mcpServers": servers]
                if let jsonData = try? JSONSerialization.data(withJSONObject: mcpConfig),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    args.append("--mcp-config")
                    args.append(jsonString)
                }
            }
        case .string(let jsonString):
            // String format: pass directly as JSON string
            args.append("--mcp-config")
            args.append(jsonString)
        case .path(let filePath):
            // Path format: pass directly as file path
            args.append("--mcp-config")
            args.append(filePath.path)
        }
    }
    
    /// Add extra/future arguments
    private static func addExtraArgs(_ args: inout [String], options: ClaudeCodeOptions) {
        // Add extra args for future CLI flags
        for (flag, value) in options.extraArgs {
            if let value = value {
                // Flag with value
                args.append("--\(flag)")
                args.append(value)
            } else {
                // Boolean flag without value
                args.append("--\(flag)")
            }
        }
    }
}

// MARK: - Argument Validation

extension ArgumentBuilder {
    
    /// Validate that arguments are properly formed
    /// - Parameter args: Arguments to validate
    /// - Returns: True if valid, false otherwise
    static func validateArguments(_ args: [String]) -> Bool {
        // Check for basic required arguments
        guard args.contains("--output-format") && args.contains("stream-json") else {
            return false
        }
        
        // Check for balanced flag-value pairs
        var i = 0
        while i < args.count {
            let arg = args[i]
            if arg.starts(with: "--") && !isBooleanFlag(arg) {
                // This flag should have a value
                if i + 1 >= args.count || args[i + 1].starts(with: "--") {
                    return false // Missing value for flag
                }
                i += 2 // Skip flag and value
            } else {
                i += 1
            }
        }
        
        return true
    }
    
    /// Check if a flag is a boolean flag (doesn't require a value)
    /// - Parameter flag: Flag to check
    /// - Returns: True if it's a boolean flag
    private static func isBooleanFlag(_ flag: String) -> Bool {
        let booleanFlags = [
            "--verbose",
            "--print",
            "--continue"
        ]
        return booleanFlags.contains(flag)
    }
}


import Foundation

// MARK: - Settings Management API

extension ClaudeCodeSDKClient {
    
    // MARK: - Individual Setting Updates
    
    /// Update permission mode and automatically reconnect with session preservation
    /// - Parameter mode: The new permission mode to use
    public func updatePermissionMode(_ mode: ClaudeCodeOptions.PermissionMode) async throws {
        try await updateSettings { builder in
            builder.permissionMode(mode)
        }
    }
    
    /// Update system prompt and automatically reconnect with session preservation
    /// - Parameter prompt: The new system prompt to use
    public func updateSystemPrompt(_ prompt: String) async throws {
        try await updateSettings { builder in
            builder.systemPrompt(prompt)
        }
    }
    
    /// Update allowed tools and automatically reconnect with session preservation
    /// - Parameter tools: The list of allowed tools
    public func updateAllowedTools(_ tools: [String]) async throws {
        try await updateSettings { builder in
            builder.allowedTools(tools)
        }
    }
    
    /// Update model and automatically reconnect with session preservation
    /// - Parameter model: The model identifier to use
    public func updateModel(_ model: String) async throws {
        try await updateSettings { builder in
            builder.model(model)
        }
    }
    
    /// Update working directory and automatically reconnect with session preservation
    /// - Parameter cwd: The new working directory
    public func updateWorkingDirectory(_ cwd: URL) async throws {
        try await updateSettings { builder in
            builder.cwd(cwd)
        }
    }
    
    /// Update max turns and automatically reconnect with session preservation
    /// - Parameter maxTurns: The maximum number of conversation turns
    public func updateMaxTurns(_ maxTurns: Int) async throws {
        try await updateSettings { builder in
            builder.maxTurns(maxTurns)
        }
    }
    
    /// Update disallowed tools and automatically reconnect with session preservation
    /// - Parameter tools: The list of disallowed tools
    public func updateDisallowedTools(_ tools: [String]) async throws {
        try await updateSettings { builder in
            builder.disallowedTools(tools)
        }
    }
    
    /// Update append system prompt and automatically reconnect with session preservation
    /// - Parameter prompt: The system prompt to append to existing one
    public func updateAppendSystemPrompt(_ prompt: String) async throws {
        try await updateSettings { builder in
            builder.appendSystemPrompt(prompt)
        }
    }
    
    // MARK: - Batch Settings Update
    
    /// Batch update multiple settings with a single reconnection
    /// - Parameter configure: A closure to configure the settings builder
    /// 
    /// This is the most efficient way to update multiple settings as it only
    /// requires one reconnection instead of multiple reconnections.
    ///
    /// ## Example:
    /// ```swift
    /// try await client.updateSettings { builder in
    ///     builder.permissionMode(.plan)
    ///     builder.systemPrompt("You are in planning mode")
    ///     builder.allowedTools(["Read", "Grep"])
    ///     builder.maxTurns(5)
    ///     builder.model("claude-3-5-sonnet-20241022")
    /// }
    /// ```
    public func updateSettings(_ configure: (ClaudeCodeOptionsBuilder) -> Void) async throws {
        let currentOptions = await optionsManager.getOptions() ?? ClaudeCodeOptions()
        let builder = ClaudeCodeOptionsBuilder(from: currentOptions)
        configure(builder)
        let newOptions = builder.build()
        
        // Update stored options
        await optionsManager.updateOptions(newOptions)
        
        // Automatically reconnect with session preservation (continue flag)
        try await reconnect()
    }
    
    // MARK: - Settings Inspection
    
    /// Get current options configuration
    /// - Returns: The current options being used by the client
    public func getCurrentOptions() async -> ClaudeCodeOptions? {
        return await optionsManager.getOptions()
    }
    
    /// Get current permission mode
    /// - Returns: The current permission mode, or nil if not set
    public func getCurrentPermissionMode() async -> ClaudeCodeOptions.PermissionMode? {
        let options = await optionsManager.getOptions()
        return options?.permissionMode
    }
    
    /// Get current system prompt
    /// - Returns: The current system prompt, or nil if not set
    public func getCurrentSystemPrompt() async -> String? {
        let options = await optionsManager.getOptions()
        return options?.systemPrompt
    }
    
    /// Get current model
    /// - Returns: The current model identifier, or nil if not set
    public func getCurrentModel() async -> String? {
        let options = await optionsManager.getOptions()
        return options?.model
    }
    
    /// Get current working directory
    /// - Returns: The current working directory, or nil if not set
    public func getCurrentWorkingDirectory() async -> URL? {
        let options = await optionsManager.getOptions()
        return options?.cwd
    }
    
    /// Get current allowed tools
    /// - Returns: The list of allowed tools, or nil if not set
    public func getCurrentAllowedTools() async -> [String]? {
        let options = await optionsManager.getOptions()
        return options?.allowedTools
    }
    
    /// Get current disallowed tools
    /// - Returns: The list of disallowed tools, or nil if not set
    public func getCurrentDisallowedTools() async -> [String]? {
        let options = await optionsManager.getOptions()
        return options?.disallowedTools
    }
    
    /// Get current max turns
    /// - Returns: The maximum number of turns, or nil if not set
    public func getCurrentMaxTurns() async -> Int? {
        let options = await optionsManager.getOptions()
        return options?.maxTurns
    }
}
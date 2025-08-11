import Foundation

/// ClaudeCodeSwiftSDK - A Swift SDK for interacting with Claude Code CLI
/// by Arunesh Singh and Claude

public struct ClaudeCodeSDK {
    /// The current version of the SDK
    public static let version = "0.1.0"
    
    private init() {}
}

// Re-export public types for convenient access
public typealias ClaudeCode = ClaudeCodeSDKClient
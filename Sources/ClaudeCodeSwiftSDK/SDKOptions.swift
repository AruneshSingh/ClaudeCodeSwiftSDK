import Foundation

// MARK: - SDK Options

/// Global SDK configuration options for development and debugging
/// These options are set once at startup and affect all SDK operations
public struct SDKOptions: Sendable {
    /// Enable debug logging globally
    public let debug: Bool
    
    /// Custom debug logger (uses default PrintDebugLogger if nil and debug is true)
    public let debugLogger: (any DebugLogger)?
    
    public init(debug: Bool = false, debugLogger: (any DebugLogger)? = nil) {
        self.debug = debug
        self.debugLogger = debugLogger ?? (debug ? PrintDebugLogger() : nil)
    }
}

// MARK: - Global SDK Configuration

/// Global SDK configuration manager
public final class ClaudeSDK: @unchecked Sendable {
    /// Shared SDK instance
    public static let shared = ClaudeSDK()
    
    private var _options: SDKOptions = SDKOptions()
    private let queue = DispatchQueue(label: "com.anthropic.claude-sdk.config", attributes: .concurrent)
    
    private init() {}
    
    /// Configure the SDK with global options
    /// This should be called once at the start of your application
    /// - Parameter options: SDK configuration options
    public func configure(with options: SDKOptions) {
        queue.async(flags: .barrier) {
            self._options = options
        }
    }
    
    /// Get current SDK options
    internal var options: SDKOptions {
        return queue.sync {
            return _options
        }
    }
    
    /// Get the current debug logger if debugging is enabled
    internal var debugLogger: (any DebugLogger)? {
        let opts = options
        return opts.debug ? opts.debugLogger : nil
    }
}

// MARK: - Convenience Configuration Functions

/// Configure the Claude Code Swift SDK with debug logging enabled
/// - Parameters:
///   - debug: Enable debug logging (default: true)
///   - debugLogger: Custom debug logger (uses default if nil)
public func configureClaudeCodeSwiftSDK(debug: Bool = true, debugLogger: (any DebugLogger)? = nil) {
    ClaudeSDK.shared.configure(with: SDKOptions(debug: debug, debugLogger: debugLogger))
}
import Foundation
import os

// MARK: - Debug Logger Protocol

/// Protocol for debug logging in the Claude SDK
public protocol DebugLogger: Sendable {
    /// Log a debug message
    func debug(_ message: @autoclosure @escaping () -> String, file: String, function: String, line: Int)
    
    /// Log an info message
    func info(_ message: @autoclosure @escaping () -> String, file: String, function: String, line: Int)
    
    /// Log a warning message
    func warn(_ message: @autoclosure @escaping () -> String, file: String, function: String, line: Int)
    
    /// Log an error message
    func error(_ message: @autoclosure @escaping () -> String, file: String, function: String, line: Int)
}


// MARK: - Default Console Logger

/// Default console logger implementation using structured logging
public final class ConsoleDebugLogger: DebugLogger, @unchecked Sendable {
    private let logger = Logger(subsystem: "com.anthropic.claude-code-sdk", category: "debug")
    private let shouldLog: Bool
    
    public init(enabled: Bool = true) {
        self.shouldLog = enabled
    }
    
    public func debug(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog else { return }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        logger.debug("👀 \(message()) [\(fileName):\(line) \(function)]")
    }
    
    public func info(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog else { return }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        logger.info("ℹ️ \(message()) [\(fileName):\(line) \(function)]")
    }
    
    public func warn(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog else { return }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        logger.warning("⚠️ \(message()) [\(fileName):\(line) \(function)]")
    }
    
    public func error(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog else { return }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        logger.error("❌ \(message()) [\(fileName):\(line) \(function)]")
    }
}

// MARK: - Simple Print Logger

/// Simple print-based logger for platforms without os.Logger
public final class PrintDebugLogger: DebugLogger, @unchecked Sendable {
    private let shouldLog: Bool
    private let dateFormatter: DateFormatter
    
    public init(enabled: Bool = true) {
        self.shouldLog = enabled
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "HH:mm:ss.SSS"
    }
    
    public func debug(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog else { return }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] 👀 DEBUG: \(message()) [\(fileName):\(line) \(function)]")
    }
    
    public func info(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog else { return }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] ℹ️ INFO: \(message()) [\(fileName):\(line) \(function)]")
    }
    
    public func warn(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog else { return }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] ⚠️ WARN: \(message()) [\(fileName):\(line) \(function)]")
    }
    
    public func error(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {
        guard shouldLog else { return }
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        print("[\(timestamp)] ❌ ERROR: \(message()) [\(fileName):\(line) \(function)]")
    }
}

// MARK: - Null Logger

/// No-op logger for when debugging is disabled
public struct NullDebugLogger: DebugLogger {
    public init() {}
    
    public func debug(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {}
    public func info(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {}
    public func warn(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {}
    public func error(_ message: @autoclosure @escaping () -> String, file: String = #file, function: String = #function, line: Int = #line) {}
}

// MARK: - Debug Utilities

/// Utilities for debug logging
public enum DebugUtils {
    /// Truncate a string to a maximum length for logging
    public static func truncate(_ string: String, maxLength: Int = 200) -> String {
        guard string.count > maxLength else { return string }
        let truncated = String(string.prefix(maxLength))
        return "\(truncated)... (\(string.count - maxLength) more chars)"
    }
    
    /// Sanitize CLI arguments by masking sensitive information
    public static func sanitizeArguments(_ args: [String]) -> [String] {
        var sanitized = args
        var i = 0
        while i < sanitized.count - 1 {
            let arg = sanitized[i]
            if arg.contains("key") || arg.contains("secret") || arg.contains("token") || arg.contains("password") {
                sanitized[i + 1] = "***REDACTED***"
                i += 2
            } else {
                i += 1
            }
        }
        return sanitized
    }
    
    /// Format a JSON object for logging with size limits
    public static func formatJSON(_ object: Any, maxLength: Int = 500) -> String {
        do {
            // Convert the object to a JSON-serializable format first
            let serializable = makeJSONSerializable(object)
            let data = try JSONSerialization.data(withJSONObject: serializable, options: [])
            let jsonString = String(data: data, encoding: .utf8) ?? "Unable to encode JSON"
            return truncate(jsonString, maxLength: maxLength)
        } catch {
            // If JSON serialization fails, fall back to string representation
            return "Object: \(String(describing: object).prefix(maxLength))"
        }
    }
    
    /// Convert an object to a JSON-serializable format
    private static func makeJSONSerializable(_ object: Any) -> Any {
        switch object {
        case let dict as [String: Any]:
            var serializable: [String: Any] = [:]
            for (key, value) in dict {
                serializable[key] = makeJSONSerializable(value)
            }
            return serializable
        case let array as [Any]:
            return array.map { makeJSONSerializable($0) }
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case let bool as Bool:
            return bool
        case is NSNull:
            return NSNull()
        case let usageInfo as UsageInfo:
            // Convert UsageInfo to a JSON-serializable dictionary
            var dict: [String: Any] = [
                "input_tokens": usageInfo.inputTokens,
                "output_tokens": usageInfo.outputTokens
            ]
            if let cacheCreation = usageInfo.cacheCreationInputTokens {
                dict["cache_creation_input_tokens"] = cacheCreation
            }
            if let cacheRead = usageInfo.cacheReadInputTokens {
                dict["cache_read_input_tokens"] = cacheRead
            }
            if let serviceTier = usageInfo.serviceTier {
                dict["service_tier"] = serviceTier
            }
            if let serverToolUse = usageInfo.serverToolUse {
                dict["server_tool_use"] = makeJSONSerializable(serverToolUse)
            }
            return dict
        case let anyCodable as AnyCodable:
            // Handle AnyCodable by extracting its value and recursing
            return makeJSONSerializable(anyCodable.value)
        default:
            // For any other type, convert to string representation
            return String(describing: object)
        }
    }
    
    /// Extract session ID from a message dictionary
    public static func extractSessionId(from message: [String: Any]) -> String {
        return message["session_id"] as? String ?? "unknown"
    }
}
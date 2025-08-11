// Message stream handling and JSON parsing for Claude Code CLI

import Foundation

/// Handles streaming JSON message parsing from Claude Code CLI output
actor MessageStreamHandler {
    
    // MARK: - Properties
    
    /// JSON buffer for partial message accumulation
    private var jsonBuffer: String = ""
    
    /// Maximum buffer size to prevent memory issues
    private let maxBufferSize: Int
    
    /// Pending control responses (for interactive mode)
    private var pendingControlResponses: [String: [String: any Sendable]] = [:]
    
    /// Debug logger for tracing messages
    private let debugLogger: (any DebugLogger)?
    
    /// Whether to close connection after ResultMessage
    private var shouldCloseOnResult: Bool
    
    // MARK: - Initialization
    
    init(
        maxBufferSize: Int = 1024 * 1024, // 1MB default
        shouldCloseOnResult: Bool = true,
        debugLogger: (any DebugLogger)? = nil
    ) {
        self.maxBufferSize = maxBufferSize
        self.shouldCloseOnResult = shouldCloseOnResult
        self.debugLogger = debugLogger
    }
    
    // MARK: - Stream Processing
    
    /// Process messages from output pipe and emit parsed messages
    /// - Parameters:
    ///   - outputPipe: Pipe to read from
    ///   - continuation: Continuation to emit messages to
    func processMessageStream(
        from outputPipe: Pipe,
        continuation: AsyncThrowingStream<Message, any Error>.Continuation
    ) async {
        let outputHandle = outputPipe.fileHandleForReading
        
        do {
            for try await line in outputHandle.bytes.lines {
                // Skip empty lines
                guard !line.isEmpty else { continue }
                
                // Split line by newlines in case multiple JSON objects are on one line
                let jsonLines = line.split(separator: "\n", omittingEmptySubsequences: true)
                
                for jsonLine in jsonLines {
                    let lineStr = String(jsonLine).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !lineStr.isEmpty else { continue }
                    
                    // Check buffer size before concatenation
                    if jsonBuffer.count + lineStr.count > maxBufferSize {
                        jsonBuffer = ""
                        continuation.finish(throwing: ClaudeSDKError.jsonDecodeError(
                            line: "Buffer would exceed maximum size",
                            error: NSError(domain: "ClaudeSDK", code: -1)
                        ))
                        return
                    }
                    
                    // Accumulate JSON buffer
                    jsonBuffer += lineStr
                    
                    // Try to parse JSON
                    if let data = jsonBuffer.data(using: .utf8) {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                            jsonBuffer = ""  // Clear buffer on successful parse
                            
                            if let json = json {
                                // Process the JSON message
                                let shouldContinue = await processJsonMessage(json, continuation: continuation)
                                if !shouldContinue {
                                    return
                                }
                            }
                        } catch {
                            // JSON parsing failed - continue accumulating
                            // (we might have a partial JSON object)
                            continue
                        }
                    }
                }
            }
            
            // Stream ended - finish normally
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }
    
    // MARK: - Control Message Handling
    
    /// Set a control response for the given request ID
    /// - Parameters:
    ///   - requestId: Request identifier
    ///   - response: Response data
    func setControlResponse(requestId: String, response: [String: any Sendable]) async {
        pendingControlResponses[requestId] = response
    }
    
    /// Wait for a control response with timeout
    /// - Parameters:
    ///   - requestId: Request identifier to wait for
    ///   - timeout: Maximum time to wait
    /// - Returns: Response data
    /// - Throws: ClaudeSDKError.timeout if response doesn't arrive in time
    func waitForControlResponse(requestId: String, timeout: TimeInterval = 30.0) async throws -> [String: any Sendable] {
        let startTime = Date()
        
        while pendingControlResponses[requestId] == nil {
            if Date().timeIntervalSince(startTime) > timeout {
                throw ClaudeSDKError.timeout(duration: timeout)
            }
            try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
        }
        
        let response = pendingControlResponses.removeValue(forKey: requestId)!
        
        if response["subtype"] as? String == "error" {
            throw ClaudeSDKError.cliConnectionError(
                underlying: NSError(
                    domain: "ClaudeSDK",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: response["error"] ?? "Control request failed"]
                )
            )
        }
        
        return response
    }
    
    /// Update whether to close connection after result message
    /// - Parameter shouldClose: Whether to close after result
    func setShouldCloseOnResult(_ shouldClose: Bool) async {
        shouldCloseOnResult = shouldClose
    }
    
    // MARK: - Private Methods
    
    /// Process a parsed JSON message
    /// - Parameters:
    ///   - json: Parsed JSON object
    ///   - continuation: Continuation to emit messages to
    /// - Returns: True if processing should continue, false to stop
    private func processJsonMessage(
        _ json: [String: Any],
        continuation: AsyncThrowingStream<Message, any Error>.Continuation
    ) async -> Bool {
        // Handle control responses separately
        if json["type"] as? String == "control_response",
           let response = json["response"] as? [String: Any],
           let requestId = response["request_id"] as? String {
            debugLogger?.debug("← Control response received for request: \(requestId)", file: #file, function: #function, line: #line)
            // Convert [String: Any] to [String: any Sendable] by mapping values to sendable types
            let sendableResponse: [String: any Sendable] = response.mapValues { value -> any Sendable in
                switch value {
                case let string as String:
                    return string
                case let number as NSNumber:
                    return number
                case let bool as Bool:
                    return bool
                case let array as [Any]:
                    return array.map { String(describing: $0) } // Convert arrays to string arrays
                case let dict as [String: Any]:
                    return dict.mapValues { String(describing: $0) } // Convert nested dicts to string dicts
                default:
                    return String(describing: value) // Fallback to string representation
                }
            }
            pendingControlResponses[requestId] = sendableResponse
            return true
        }
        
        // Decode regular message with type-specific optimization
        let messageType = json["type"] as? String
        let sessionId = DebugUtils.extractSessionId(from: json)
        
        do {
            // Fast path for ResultMessage to avoid type erasure overhead
            if messageType == "result" {
                let messageData = try JSONSerialization.data(withJSONObject: json)
                let resultMessage = try JSONDecoder().decode(ResultMessage.self, from: messageData)
                
                // Log cost and session information  
                logResultMessage(resultMessage, sessionId: sessionId)
                
                continuation.yield(.result(resultMessage))
                
                if shouldCloseOnResult {
                    // One-shot mode: close connection
                    debugLogger?.debug("Closing connection after result (one-shot mode)", file: #file, function: #function, line: #line)
                    continuation.finish()
                    return false
                } else {
                    // Streaming mode: keep connection open
                    debugLogger?.debug("Keeping connection open after result (streaming mode)", file: #file, function: #function, line: #line)
                    return true
                }
            } else {
                // For other message types, use the general decoder
                let messageData = try JSONSerialization.data(withJSONObject: json)
                let message = try await MessageDecoder.decodeFromData(messageData)
                
                debugLogger?.debug("← [\(sessionId)] Received \(messageType ?? "unknown") message: \(DebugUtils.formatJSON(json, maxLength: 200))", file: #file, function: #function, line: #line)
                
                continuation.yield(message)
                return true
            }
        } catch {
            continuation.finish(throwing: ClaudeSDKError.jsonDecodeError(
                line: DebugUtils.formatJSON(json, maxLength: 500),
                error: error
            ))
            return false
        }
    }
    
    /// Log detailed result message information
    /// - Parameters:
    ///   - resultMessage: The result message to log
    ///   - sessionId: Session identifier
    private func logResultMessage(_ resultMessage: ResultMessage, sessionId: String) {
        let costInfo = "Cost=\(resultMessage.totalCostUsd.map { "$\($0)" } ?? "N/A")"
        let durationInfo = "Duration=\(Double(resultMessage.durationMs) / 1000.0)s"
        let apiDurationInfo = "API=\(Double(resultMessage.durationApiMs) / 1000.0)s"
        let turnsInfo = "Turns=\(resultMessage.numTurns)"
        let usageInfo = resultMessage.usage.map { "Usage=\(DebugUtils.formatJSON($0, maxLength: 100))" } ?? "Usage=N/A"
        
        debugLogger?.info("💰 Result [session:\(sessionId)]: \(costInfo), \(durationInfo), \(apiDurationInfo), \(turnsInfo), \(usageInfo)", file: #file, function: #function, line: #line)
    }
}


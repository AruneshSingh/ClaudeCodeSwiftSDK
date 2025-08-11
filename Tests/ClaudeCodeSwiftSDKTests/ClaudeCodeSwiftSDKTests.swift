import Testing
import Foundation
@testable import ClaudeCodeSwiftSDK

@Suite("Basic SDK Tests")
struct ClaudeCodeSwiftSDKTests {
    
    @Test("SDK module imports successfully")
    func testSDKImport() throws {
        // Test that we can create basic types from the SDK
        let options = ClaudeCodeOptions()
        #expect(options != nil)
        
        let textBlock = TextBlock(text: "Test")
        #expect(textBlock.text == "Test")
        
        let client = ClaudeCodeSDKClient()
        #expect(client != nil)
    }
    
    @Test("Error types are available")
    func testErrorTypes() {
        let error = ClaudeSDKError.invalidConfiguration(reason: "Test error")
        
        if case .invalidConfiguration(let reason) = error {
            #expect(reason == "Test error")
        } else {
            Issue.record("Expected invalidConfiguration error")
        }
        
        let description = error.errorDescription
        #expect(description?.contains("Invalid configuration") == true)
    }
}
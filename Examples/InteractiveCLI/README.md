# Interactive CLI for ClaudeCodeSwiftSDK

An interactive command-line interface for testing the ClaudeCodeSwiftSDK's streaming functionality.

## Features

- ✅ Real-time streaming responses from Claude
- ✅ Session management with persistent session IDs
- ✅ Multi-turn conversations
- ✅ Interrupt support (`/interrupt` command)
- ✅ Configuration options (system prompt, model, tools, working directory)
- ✅ Beautiful message formatting with emojis

## Building

```bash
swift build
```

## Running

```bash
swift run
```

Or after building:

```bash
.build/debug/InteractiveCLI
```

## Commands

- `/help`, `/h`, `/?` - Show help message
- `/exit`, `/quit`, `/q` - Exit the program
- `/interrupt`, `/int`, `/i` - Interrupt current operation
- `/status`, `/s` - Show connection status and current session
- `/clear`, `/c` - Clear the screen
- `/session <id>` - Set session ID (default: "default")
- `/system <prompt>` - Set system prompt
- `/model <name>` - Set model (e.g., claude-3-opus-20240229)
- `/tools <list>` - Set allowed tools (comma-separated)
- `/cwd <path>` - Set working directory

## Usage Example

```
╔══════════════════════════════════════╗
║   Claude Code Interactive CLI        ║
║   Type /help for commands            ║
╚══════════════════════════════════════╝
ℹ️  Connecting to Claude Code CLI...
✅ Connected! Ready for interactive conversation.

> Hello Claude!
ℹ️  Message sent, waiting for response...

🔧 System: init - [:]
🤖 Assistant:
   Hello! I'm Claude, an AI assistant. How can I help you today?
📊 Result:
   Session ID: abc-123-def-456
   Duration: 1234ms
   API Duration: 1000ms
   Turns: 1
   Cost: $0.000123

> What's 2 + 2?
ℹ️  Message sent, waiting for response...

🤖 Assistant:
   2 + 2 = 4
📊 Result:
   Session ID: abc-123-def-456
   Duration: 890ms
   API Duration: 750ms
   Turns: 2
   Cost: $0.000089

> /status

📊 Status:
   Connected: Yes ✅
   Current Session ID: default
   Waiting for Response: No
   System Prompt: none
   Model: default
   Allowed Tools: all
   Working Directory: none

> /exit
👋 Goodbye!
```

## Session Continuity

The CLI maintains session continuity - you can see the same Session ID across multiple messages in a conversation. This allows Claude to maintain context throughout the interaction.

## Limitations

- **Interrupts**: While the `/interrupt` command is available, the current implementation waits for responses to complete before accepting new input. Real-time interrupts during streaming would require concurrent input handling.

## Architecture

The Interactive CLI demonstrates:
- Bidirectional streaming with `ClaudeCodeSDKClient`
- Proper session management
- Message formatting and display
- Error handling
- Configuration options
//
//  ChatCommand.swift
//  Fai
//
//  Created by hal on 2025/06/16.
//

import ArgumentParser
import Foundation
import Logging

struct ChatCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chat",
        abstract: "Starts an interactive chat REPL with Foundation Models"
    )

    @Argument(help: "Initial message to send (optional)")
    var initialMessage: String?

    @Option(name: .shortAndLong, help: "System instructions")
    var instructions: String?

    @Option(
        name: .shortAndLong,
        help: "Tools: [\(ToolsService().listTools().joined(separator: String(", ")))]"
    )
    var tools: [String] = []

    @Flag(name: .shortAndLong, help: "Output in streaming mode")
    var stream: Bool = false

    @Flag(name: .shortAndLong, help: "Display detailed logs")
    var verbose: Bool = false

    @Flag(help: "Check model availability and exit")
    var checkAvailability: Bool = false

    mutating func run() async throws {
        // Set log level
        let logLevel: Logger.Level = verbose ? .debug : .error
        var logger = Logger(label: "ChatCommand")
        logger.logLevel = logLevel

        let service: FoundationModelsService

        if !tools.isEmpty {
            // Initialize with specified tools
            service = FoundationModelsService(logger: logger, withTools: tools)
        } else {
            // Default service without tools
            service = FoundationModelsService(logger: logger)
        }

        // Check model availability
        let availability = service.checkModelAvailability()
        if checkAvailability {
            print(availability.availabilityDescription)
            if !availability.isDefaultModelAvailable {
                logger.warning(
                    "Chat functionality is unavailable because the model is not available.")
                throw ExitCode.failure
            }
            return
        }

        if !availability.isDefaultModelAvailable {
            logger.error("Model not available. Please ensure Apple Intelligence is enabled.")
            throw ExitCode.failure
        }

        // Start REPL
        try await startChatREPL(service: service, availability: availability, logger: logger)
    }

    mutating func startChatREPL(
        service: FoundationModelsService, availability: ModelAvailabilityInfo, logger: Logger
    ) async throws {
        print("🤖 Fai   : \(availability.statusSummary)")
        print("🛠️ Tools : \(service.enableTools())")
        print("💡 Tips  : Type '/help' for a list of commands, '/quit' to exit")

        if let instructions = instructions {
            print("📋 System Instructions: \(instructions)")
        }

        if stream {
            logger.info("Streaming mode enabled")
        }

        if verbose {
            logger.info("Verbose mode enabled - detailed processing logs will be shown")
        }

        print(String(repeating: "─", count: 50))

        // Process initial message if present
        if let initialMessage = initialMessage {
            try await processMessage(initialMessage, service: service, logger: logger)
        }

        // REPL loop
        while true {
            print("\n You: ", terminator: "")
            fflush(stdout)

            guard let input = readLine() else {
                print("\n👋 Exiting chat.")
                break
            }

            let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty input
            if trimmedInput.isEmpty {
                continue
            }

            // Process commands
            if trimmedInput.hasPrefix("/") {
                if await handleCommand(trimmedInput, logger: logger) {
                    break  // For /quit command
                }
                continue
            }

            // Process message
            do {
                try await processMessage(trimmedInput, service: service, logger: logger)
            } catch {
                let errorMessage = service.handleError(error)
                logger.error("\(errorMessage)")
            }
        }
    }

    func processMessage(_ message: String, service: FoundationModelsService, logger: Logger)
        async throws
    {
        // Show verbose logs before processing if enabled
        if verbose {
            logger.debug("Processing message: \(message)")
            if let instructions = instructions {
                logger.debug("Using instructions: \(instructions)")
            }
            logger.debug("Streaming mode: \(stream)")
            logger.debug("Tools enabled: \(service.enableTools())")
            logger.debug("Starting Foundation Models processing...")
        }

        print("\n Fai: Generating...", terminator: "")
        fflush(stdout)

        // Clear loading message before printing actual response
        // Move cursor up one line, clear line, then print Fai:
        let clearLine = "\r\u{1B}[1A\u{1B}[K"
        print(clearLine, terminator: "")
        fflush(stdout)

        if stream {

            var currentOutput = ""

            print("\r\n Fai", terminator: ": ")

            // Always use the main service (verbose logging is now handled internally)
            let _ = try await service.streamResponse(
                prompt: message,
                instructions: instructions
            ) { partial in
                // Output only the new part
                let newContent = String(partial.dropFirst(currentOutput.count))
                print(newContent, terminator: "")
                fflush(stdout)
                currentOutput = partial
            }
            print()  // Add newline
        } else {
            // Always use the main service (verbose logging is now handled internally)
            let response = try await service.generateResponse(
                prompt: message,
                instructions: instructions
            )
            print("\n Fai: " + response)
        }

        // Show completion logs if verbose mode is enabled
        if verbose {
            logger.debug("Message processing completed successfully")
        }
    }

    mutating func handleCommand(_ command: String, logger: Logger) async -> Bool {
        let parts = command.dropFirst().split(separator: " ", maxSplits: 1)
        let commandName = String(parts.first ?? "")
        let argument = parts.count > 1 ? String(parts[1]) : ""

        switch commandName.lowercased() {
        case "help", "h":
            printHelp()

        case "quit", "exit", "q":
            print("👋 Exiting chat.")
            return true

        case "clear", "cls":
            print("\u{1B}[2J\u{1B}[H", terminator: "")  // Clear screen
            print("🤖 Fai Chat - Screen cleared")

        case "stream":
            stream.toggle()
            logger.info("Streaming mode: \(stream ? "Enabled" : "Disabled")")

        case "instructions", "inst":
            if argument.isEmpty {
                if let current = instructions {
                    print("📋 Current instructions: \(current)")
                } else {
                    print("📋 No instructions set.")
                }
            } else {
                instructions = argument
                logger.info("Instructions updated: \(argument)")
            }

        case "status":
            let service = FoundationModelsService(logger: Logger(label: "StatusCheck"))
            let availability = service.checkModelAvailability()
            print("📊 \(availability.availabilityDescription)")

        case "verbose":
            verbose.toggle()
            logger.info("Verbose mode: \(verbose ? "Enabled" : "Disabled")")
            if verbose {
                print(
                    "   Note: Detailed processing logs will be displayed during message processing")
            }

        default:
            print("❓ Unknown command: /\(commandName)")
            print("💡 Type '/help' for a list of commands.")
        }

        return false
    }

    func printHelp() {
        print(
            """

            📚 Fai Chat REPL Command List:

            /help, /h              - Show this help message
            /quit, /exit, /q       - Exit the chat
            /clear, /cls           - Clear the screen
            /stream                - Toggle streaming mode
            /instructions [text]   - Show/Set system instructions
            /status                - Show model status
            /verbose               - Toggle verbose debug logging (shows detailed processing info)

            💡 Tips:
            • Enter regular messages directly
            • You can also exit with Ctrl+C
            • Enjoy real-time output in streaming mode
            • Use verbose mode to see detailed Foundation Models processing logs
            """)
    }
}

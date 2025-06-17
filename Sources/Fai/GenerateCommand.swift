//
//  GenerateCommand.swift
//  Fai
//
//  Created by hal on 2025/06/17.
//

import ArgumentParser
import Foundation
import Logging

struct GenerateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generates responses in structured data or JSON format."
    )

    @Argument(help: "Prompt for generation. If not provided, reads from stdin.")
    var prompt: String?

    @Option(name: .shortAndLong, help: "System instructions.")
    var instructions: String?

    @Flag(name: .shortAndLong, help: "Display detailed logs.")
    var verbose: Bool = false

    @Option(name: .shortAndLong, help: "Output file path.")
    var output: String?

    mutating func run() async throws {
        let logLevel: Logger.Level = verbose ? .debug : .warning
        var logger = Logger(label: "GenerateCommand")
        logger.logLevel = logLevel

        let service = FoundationModelsService(logger: logger)

        // Model availability check
        let availability = service.checkModelAvailability()
        if !availability.isDefaultModelAvailable {
            logger.error("Model not available. Please ensure Apple Intelligence is enabled.")
            throw ExitCode.failure
        }

        // Read from stdin if available
        var stdinInput = ""
        while let line = readLine() {
            stdinInput += line + "\n"
        }
        let stdinData = stdinInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // Combine stdin data and prompt
        let inputPrompt: String
        if let promptArg = prompt {
            if !stdinData.isEmpty {
                // Use stdin as context and prompt as instruction
                inputPrompt = "Context:\(stdinData)\n\nInstruction: \(promptArg)"
            } else {
                // Use prompt only
                inputPrompt = promptArg
            }
        } else if !stdinData.isEmpty {
            // Use stdin only
            inputPrompt = stdinData
        } else {
            logger.error("Error: No prompt provided and no stdin input.")
            throw ExitCode.failure
        }

        do {
            let result: String

            logger.info("Generating...")
            let summaryInstructions =
                (instructions ?? "")
                + "\nPlease create a summary"
            result = try await service.generateResponse(
                prompt: inputPrompt,
                instructions: summaryInstructions
            )

            // Output processing
            if let outputPath = output {
                try result.write(toFile: outputPath, atomically: true, encoding: .utf8)
                logger.info("Results saved to \(outputPath)")
            } else {
                print("\n\(result)")
            }

        } catch {
            let errorMessage = service.handleError(error)
            logger.error("\(errorMessage)")
            throw ExitCode.failure
        }
    }
}

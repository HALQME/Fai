//
//  GitCommand.swift
//  Fai
//
//  Created by hal on 2025/06/17.
//

import ArgumentParser
import Foundation
import Logging

struct GitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "git-commit",
        abstract: "Generates git commit message and description."
    )

    @Flag(name: .shortAndLong, help: "Display detailed logs")
    var verbose: Bool = false

    @Option(name: .shortAndLong, help: "Output file path.")
    var output: String?

    mutating func run() async throws {
        let logLevel: Logger.Level = verbose ? .debug : .warning
        var logger = Logger(label: "GenerateCommand")
        logger.logLevel = logLevel

        let gitservice = GitService()
        let service = FoundationModelsService(logger: logger)

        let availability = service.checkModelAvailability()
        if !availability.isDefaultModelAvailable {
            logger.error("Model not available. Please ensure Apple Intelligence is enabled.")
            throw ExitCode.failure
        }

        do {
            logger.info("Generating...")
            let changes = try await gitservice.getStagedChanges()
            let commit: CommitMessage = try await service.generateStructuredData(
                prompt: "\(changes)",
                type: CommitMessage.self,
                instructions: "Generate commit message from input data."
            )

            let result = "\(commit.commitType):\(commit.message)\n\n\n\(commit.description)"

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

//
//  FoundationModelsService.swift
//  Fai
//
//  Created by Rudrank Riyam on 6/9/25.
//

import Foundation
import FoundationModels
import Logging

/// Service class to manage Foundation Models operations for CLI
final class FoundationModelsService {

    // MARK: - Properties

    private let logger: Logger
    private let toolsService: ToolsService
    private let tools: [any Tool]?
    private var currentSession: LanguageModelSession?

    // MARK: - Initialization

    init(logger: Logger = Logger(label: "FoundationModelsService")) {
        self.logger = logger
        self.toolsService = ToolsService()
        self.tools = nil
    }

    init(logger: Logger = Logger(label: "FoundationModelsService"), withTools: [String]?) {
        self.logger = logger
        let toolsService = ToolsService()
        self.toolsService = toolsService

        if let withTools = withTools {
            self.tools = withTools.compactMap { toolName in
                toolsService.searchTool(named: toolName).first
            }
        } else {
            self.tools = nil
        }
    }

    // MARK: - Session Management

    func createSession(instructions: String? = nil, )
        -> LanguageModelSession
    {
        let session: LanguageModelSession
        if let tools = tools {
            session = LanguageModelSession(tools: tools, instructions: instructions)
            logger.debug(
                "Created session with \(tools.count) tools: \(tools.map { $0.name }.joined(separator: ", "))")
        } else if let currentSession = currentSession {
            session = currentSession
            logger.debug("Reusing existing session")
        } else {
            session = LanguageModelSession(instructions: instructions)
            logger.debug("Created session without tools")
        }
        
        if let instructions = instructions {
            logger.debug("Session instructions set: \(instructions)")
        }

        currentSession = session
        return session
    }

    // MARK: - Basic Operations

    func generateResponse(
        prompt: String,
        instructions: String? = nil
    ) async throws -> String {
        logger.debug("Starting response generation")
        logger.debug("Prompt length: \(prompt.count) characters")
        logger.debug("Prompt preview: \(prompt.prefix(100))...")
        if let instructions = instructions {
            logger.debug("System instructions: \(instructions)")
        }

        let session = createSession(instructions: instructions)
        logger.debug("Session created, sending request to Foundation Models...")

        let response = try await session.respond(to: Prompt(prompt))

        logger.debug("Response received, length: \(response.content.count) characters")
        logger.debug("Response preview: \(response.content.prefix(100))...")
        logger.info("Response generation completed successfully")
        return response.content
    }

    func generateStructuredData<T: Generable>(
        prompt: String,
        type: T.Type,
        instructions: String? = nil
    ) async throws -> T {
        logger.debug("Starting structured data generation: \(T.self)")
        logger.debug("Prompt length: \(prompt.count) characters")

        let session = createSession(instructions: instructions)
        let response = try await session.respond(to: Prompt(prompt), generating: type)

        logger.info("Structured data generation completed successfully")
        return response.content
    }

    // MARK: - Streaming Operations

    func streamResponse(
        prompt: String,
        instructions: String? = nil,
        onPartialUpdate: @escaping (String) -> Void
    ) async throws -> String {
        logger.debug("Starting streaming response")
        logger.debug("Prompt length: \(prompt.count) characters")
        logger.debug("Prompt preview: \(prompt.prefix(100))...")
        if let instructions = instructions {
            logger.debug("System instructions: \(instructions)")
        }

        let session = createSession(instructions: instructions)
        logger.debug(" Session created, starting stream...")
        let stream = session.streamResponse(to: Prompt(prompt))

        var partialCount = 0
        for try await partialResponse in stream {
            partialCount += 1
            logger.debug(
                " Received partial response #\(partialCount) (length: \(partialResponse.count))")
            onPartialUpdate(partialResponse)
        }

        let finalResponse = try await stream.collect()
        logger.debug(" Stream completed with \(partialCount) partial responses")
        logger.debug(" Final response length: \(finalResponse.content.count) characters")
        logger.info(" Streaming response completed successfully")
        return finalResponse.content
    }

    // MARK: - Model Availability

    func checkModelAvailability() -> ModelAvailabilityInfo {
        logger.debug(" Checking model availability...")

        let model = SystemLanguageModel.default
        let contentTaggingModel = SystemLanguageModel(useCase: .contentTagging)

        let info = ModelAvailabilityInfo(
            defaultModel: model,
            contentTaggingModel: contentTaggingModel
        )

        logger.info(
            " Model availability check completed: Default=\(info.isDefaultModelAvailable), Tagging=\(info.isContentTaggingAvailable)"
        )

        return info
    }

    func availableTools() -> [String] {
        toolsService.listTools()
    }

    func enableTools() -> [String] {
        return self.tools?.map { $0.name } ?? []
    }

    // MARK: - Error Handling

    func handleError(_ error: Error) -> String {
        logger.error(" An error occurred: \(error)")

        if error is LanguageModelSession.GenerationError {
            return "Error: An error occurred during generation - \(error.localizedDescription)"
        } else if error is LanguageModelSession.ToolCallError {
            return "Error: An error occurred during tool call - \(error.localizedDescription)"
        } else {
            return "Unexpected error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Types

struct ModelAvailabilityInfo {
    let defaultModel: SystemLanguageModel
    let contentTaggingModel: SystemLanguageModel

    var isDefaultModelAvailable: Bool {
        defaultModel.availability == .available
    }

    var isContentTaggingAvailable: Bool {
        contentTaggingModel.availability == .available
    }

    var availabilityDescription: String {
        var result = "Model Availability Check:\n\n"

        switch defaultModel.availability {
        case .available:
            result += "✅ Default model is available\n"
            result += "Number of supported languages: \(defaultModel.supportedLanguages.count)\n"
            result += "Content tagging model: \(isContentTaggingAvailable ? "✅" : "❌")\n"

        case .unavailable(let reason):
            result += "❌ Default model is not available\n"
            switch reason {
            case .deviceNotEligible:
                result += "Reason: Device is not eligible for Apple Intelligence\n"
            case .appleIntelligenceNotEnabled:
                result += "Reason: Apple Intelligence is not enabled\n"
            case .modelNotReady:
                result += "Reason: Model assets are being prepared (downloading...)\n"
            @unknown default:
                result += "Reason: Unknown\n"
            }
        }

        return result
    }

    /// Concise status string for CLI display
    var statusSummary: String {
        return isDefaultModelAvailable ? "Available" : "Not Available"
    }
}

//
//  StatusCommand.swift
//  Fai
//
//  Created by hal on 2025/06/17.
//

import ArgumentParser
import Foundation
import Logging

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Checks the status and model availability of Foundation Models."
    )

    @Flag(name: .shortAndLong, help: "Display detailed information.")
    var verbose: Bool = false

    @Flag(help: "Output in JSON format.")
    var json: Bool = false

    mutating func run() throws {
        let logLevel: Logger.Level = verbose ? .debug : .warning
        var logger = Logger(label: "StatusCommand")
        logger.logLevel = logLevel

        let service = FoundationModelsService(logger: logger)
        let availability = service.checkModelAvailability()
        let tools = service.availableTools()

        let statusInfo = StatusInfo(
            isDefaultModelAvailable: availability.isDefaultModelAvailable,
            supportedLanguagesCount: availability.defaultModel.supportedLanguages.count,
            isContentTaggingAvailable: availability.isContentTaggingAvailable,
            tools: tools
        )

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(statusInfo)
            print(String(data: jsonData, encoding: .utf8) ?? "")
        } else {
            print("Model Availability Status:")
            print(statusInfo.statusSummary)
            print("Supported Languages Count: \(statusInfo.supportedLanguagesCount)")
            print(
                "Content Tagging Available: \(statusInfo.isContentTaggingAvailable ? "Yes" : "No")")
            print(statusInfo.toolsSummary)
        }
    }
}

struct StatusInfo: Codable {
    let isDefaultModelAvailable: Bool
    let supportedLanguagesCount: Int
    let isContentTaggingAvailable: Bool
    let tools: [String]

    var statusSummary: String {
        if isDefaultModelAvailable {
            return "✅ Default model is available"
        } else {
            return "❌ Default model is not available"
        }
    }

    var toolsSummary: String {
        if tools.isEmpty {
            return "No tools available"
        } else {
            return "Available tools: \(tools.joined(separator: ", "))"
        }
    }
}

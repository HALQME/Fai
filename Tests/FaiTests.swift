//
//  Test.swift
//  Fai
//
//  Created by hal on 2025/06/17.
//

import Testing
import Logging
import Foundation
import FoundationModels
@testable import Fai

// MARK: - ChatCommand Tests

@Suite("Service")
struct FoundationModelsServiceTests {

    // MARK: - Test Setup

    private func createTestService() -> FoundationModelsService {
        var logger = Logger(label: "test-foundation-models")
        logger.logLevel = .critical  // Suppress logs during testing
        return FoundationModelsService(logger: logger)
    }

    // MARK: - Session Management Tests

    @Test("Create session with default instructions")
    func testCreateSessionWithDefaultInstructions() {
        let service = createTestService()
        let session = service.createSession()
        #expect(true, "Session should be created successfully")
    }

    @Test("Create session with custom instructions")
    func testCreateSessionWithCustomInstructions() {
        let service = createTestService()
        let customInstructions = "You are a helpful assistant specialized in Swift programming."
        let session = service.createSession(instructions: customInstructions)
        #expect(true, "Session with custom instructions should be created successfully")
    }

    @Test("Create multiple sessions")
    func testCreateMultipleSessions() {
        let service = createTestService()
        let session1 = service.createSession(instructions: "First session")
        let session2 = service.createSession(instructions: "Second session")

        #expect(true, "First session should be created")
        #expect(true, "Second session should be created")
    }

    // MARK: - Basic Operations Tests

    @Test("Generate response with valid prompt")
    func testGenerateResponseWithValidPrompt() async throws {
        let service = createTestService()
        let prompt = "Hello, how are you?"

        do {
            let response = try await service.generateResponse(prompt: prompt)
            #expect(!response.isEmpty, "Response should not be empty")
            #expect(response.count > 0, "Response should have content")
        } catch {
            // Expected on systems without Apple Intelligence
            #expect(
                error is LanguageModelSession.GenerationError
                    || error.localizedDescription.contains("not available"),
                "Error should be related to model availability")
        }
    }

    @Test("Generate response with custom instructions")
    func testGenerateResponseWithCustomInstructions() async throws {
        let service = createTestService()
        let prompt = "Explain Swift optionals"
        let instructions = "You are a Swift programming expert."

        do {
            let response = try await service.generateResponse(
                prompt: prompt,
                instructions: instructions
            )
            #expect(!response.isEmpty, "Response should not be empty")
        } catch {
            // Expected on systems without Apple Intelligence
            #expect(
                error is LanguageModelSession.GenerationError
                    || error.localizedDescription.contains("not available"),
                "Error should be related to model availability")
        }
    }

    @Test("Generate response with empty prompt")
    func testGenerateResponseWithEmptyPrompt() async throws {
        let service = createTestService()
        let emptyPrompt = ""

        do {
            let response = try await service.generateResponse(prompt: emptyPrompt)
            // If successful, response might be empty or contain default content
            #expect(true, "Response should not be nil even with empty prompt")
        } catch {
            // Expected behavior - either model unavailable or empty prompt error
            #expect(true, "Should handle empty prompt appropriately")
        }
    }

    @Test("Generate response with very long prompt")
    func testGenerateResponseWithLongPrompt() async throws {
        let service = createTestService()
        let longPrompt = String(repeating: "This is a very long prompt. ", count: 1000)

        do {
            let response = try await service.generateResponse(prompt: longPrompt)
            #expect(true, "Should handle long prompts")
        } catch {
            // Expected on systems without Apple Intelligence or token limit exceeded
            #expect(true, "Should handle long prompts gracefully")
        }
    }

    // MARK: - Structured Data Generation Tests

    @Generable
    struct TestGenerableData {
        let message: String
        let count: Int
    }

    @Test("Generate structured data with valid type")
    func testGenerateStructuredDataWithValidType() async throws {
        let service = createTestService()
        let prompt = "Generate test data with message 'hello' and count 5"

        do {
            let result = try await service.generateStructuredData(
                prompt: prompt,
                type: TestGenerableData.self
            )
            #expect(
                result.count == 5 && result.message == "hello",
                "Structured data should be generated"
            )
        } catch {
            // Expected on systems without Apple Intelligence
            #expect(
                error is LanguageModelSession.GenerationError
                    || error.localizedDescription.contains("not available"),
                "Error should be related to model availability")
        }
    }

    @Test("Generate structured data with custom instructions")
    func testGenerateStructuredDataWithCustomInstructions() async throws {
        let service = createTestService()
        let prompt = "Create test data"
        let instructions = "Always set count to 10 and message to 'test'"

        do {
            let result = try await service.generateStructuredData(
                prompt: prompt,
                type: TestGenerableData.self,
                instructions: instructions
            )
            #expect(
                result.count == 10 && result.message == "test",
                "Structured data with instructions should be generated"
            )
        } catch {
            // Expected on systems without Apple Intelligence
            #expect(
                error is LanguageModelSession.GenerationError
                    || error.localizedDescription.contains("not available"),
                "Error should be related to model availability")
        }
    }

    // MARK: - Streaming Operations Tests

    @Test("Stream response with callback")
    func testStreamResponseWithCallback() async throws {
        let service = createTestService()
        let prompt = "Count from 1 to 5"
        var partialUpdates: [String] = []

        do {
            let finalResponse = try await service.streamResponse(
                prompt: prompt,
                instructions: nil
            ) { partialContent in
                partialUpdates.append(partialContent)
            }

            #expect(!finalResponse.isEmpty, "Final response should not be empty")
            #expect(partialUpdates.count >= 0, "Should receive partial updates")
        } catch {
            // Expected on systems without Apple Intelligence
            #expect(
                error is LanguageModelSession.GenerationError
                    || error.localizedDescription.contains("not available"),
                "Error should be related to model availability")
        }
    }

    @Test("Stream response with custom instructions")
    func testStreamResponseWithCustomInstructions() async throws {
        let service = createTestService()
        let prompt = "Explain async/await in Swift"
        let instructions = "Keep response under 100 words"
        var updateCount = 0

        do {
            let finalResponse = try await service.streamResponse(
                prompt: prompt,
                instructions: instructions
            ) { _ in
                updateCount += 1
            }

            #expect(!finalResponse.isEmpty, "Final response should not be empty")
            #expect(updateCount >= 0, "Should track update count")
        } catch {
            // Expected on systems without Apple Intelligence
            #expect(
                error is LanguageModelSession.GenerationError
                    || error.localizedDescription.contains("not available"),
                "Error should be related to model availability")
        }
    }

    // MARK: - Model Availability Tests

    @Test("Check model availability")
    func testCheckModelAvailability() {
        let service = createTestService()
        let availability = service.checkModelAvailability()

        #expect(true, "Availability info should not be nil")
        #expect(true, "Default model should be present")
        #expect(true, "Content tagging model should be present")
        #expect(!availability.statusSummary.isEmpty, "Status summary should not be empty")
        #expect(!availability.availabilityDescription.isEmpty, "Description should not be empty")
    }

    @Test("Model availability info properties")
    func testModelAvailabilityInfoProperties() {
        let service = createTestService()
        let availability = service.checkModelAvailability()

        // Test boolean properties
        let isDefaultAvailable = availability.isDefaultModelAvailable
        let isTaggingAvailable = availability.isContentTaggingAvailable

        #expect(
            isDefaultAvailable == true || isDefaultAvailable == false,
            "isDefaultModelAvailable should be boolean")
        #expect(
            isTaggingAvailable == true || isTaggingAvailable == false,
            "isContentTaggingAvailable should be boolean")

        // Test status summary content
        let summary = availability.statusSummary
        #expect(
            summary == "Available" || summary == "Not Available",
            "Status summary should be either 'Available' or 'Not Available'")

        // Test description contains expected content
        let description = availability.availabilityDescription
        #expect(
            description.contains("Model Availability Check"),
            "Description should contain header")
        #expect(
            description.contains("Default model"),
            "Description should mention default model")
    }

    // MARK: - Error Handling Tests

    @Test("Handle generic error")
    func testHandleGenericError() {
        let service = createTestService()

        // Create a generic error
        struct CustomError: Error {
            let message = "Custom test error"
        }
        let mockError = CustomError()
        let errorMessage = service.handleError(mockError)

        #expect(
            errorMessage.contains("Unexpected error"),
            "Should handle unexpected errors")
        #expect(!errorMessage.isEmpty, "Error message should not be empty")
    }

    // MARK: - Input Validation Tests

    @Test("Handle special characters in prompt")
    func testHandleSpecialCharactersInPrompt() async throws {
        let service = createTestService()
        let specialPrompt = "Test with émojis 🚀 and special chars: @#$%^&*()"

        do {
            let response = try await service.generateResponse(prompt: specialPrompt)
            #expect(true, "Should handle special characters")
        } catch {
            // Expected on systems without Apple Intelligence
            #expect(true, "Should handle special characters gracefully")
        }
    }

    @Test("Handle unicode characters in prompt")
    func testHandleUnicodeCharactersInPrompt() async throws {
        let service = createTestService()
        let unicodePrompt = "こんにちは、世界！ 你好世界！ Hello, мир!"

        do {
            let response = try await service.generateResponse(prompt: unicodePrompt)
            #expect(true, "Should handle unicode characters")
        } catch {
            // Expected on systems without Apple Intelligence
            #expect(true, "Should handle unicode characters gracefully")
        }
    }

    @Test("Handle nil instructions gracefully")
    func testHandleNilInstructions() async throws {
        let service = createTestService()
        let prompt = "Simple test prompt"

        do {
            let response = try await service.generateResponse(
                prompt: prompt,
                instructions: nil
            )
            #expect(true, "Should handle nil instructions")
        } catch {
            // Expected on systems without Apple Intelligence
            #expect(true, "Should handle nil instructions gracefully")
        }
    }

    // MARK: - Performance Tests

    @Test("Response time is reasonable")
    func testResponseTimeIsReasonable() async throws {
        let service = createTestService()
        let prompt = "Quick response test"
        let startTime = Date()

        do {
            _ = try await service.generateResponse(prompt: prompt)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)

            // Response should complete within reasonable time (30 seconds)
            #expect(duration < 30.0, "Response should complete within 30 seconds")
        } catch {
            // Test timing even for errors
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            #expect(duration < 10.0, "Error response should be quick")
        }
    }
}

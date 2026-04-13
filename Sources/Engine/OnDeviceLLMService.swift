import Foundation
import Observation

#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - On-Device LLM Service

/// Wraps Apple's FoundationModels framework for on-device AI inference.
/// Requires iOS 26+ and an Apple Intelligence-capable device (M1+/A17 Pro+).
@available(iOS 26.0, *)
@Observable
final class OnDeviceLLMService: @unchecked Sendable {

    // MARK: - State

    enum ServiceState: Equatable {
        case checking
        case available
        case unavailable(UnavailableDetail)
    }

    enum UnavailableDetail: Equatable {
        case deviceNotEligible
        case appleIntelligenceDisabled
        case modelNotReady
        case unknown
    }

    private(set) var state: ServiceState = .checking
    private var session: LanguageModelSession?

    // MARK: - Lifecycle

    init() {
        checkAvailability()
    }

    // MARK: - Availability

    func checkAvailability() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            state = .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                state = .unavailable(.deviceNotEligible)
            case .appleIntelligenceNotEnabled:
                state = .unavailable(.appleIntelligenceDisabled)
            case .modelNotReady:
                state = .unavailable(.modelNotReady)
            @unknown default:
                state = .unavailable(.unknown)
            }
        @unknown default:
            state = .unavailable(.unknown)
        }
    }

    // MARK: - Session Management

    /// Creates a new session with campaign-aware system instructions.
    func createSession(instructions: String) {
        guard state == .available else { return }
        session = LanguageModelSession(instructions: instructions)
    }

    /// Resets the conversation, keeping the same instructions.
    func resetSession(instructions: String) {
        session = nil
        createSession(instructions: instructions)
    }

    // MARK: - Inference

    /// Sends a prompt and streams the response token by token.
    /// Calls `onToken` on each partial update with the full accumulated text so far.
    /// Returns the complete response.
    @discardableResult
    func streamResponse(
        to prompt: String,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        guard let session else {
            throw LLMError.noSession
        }

        let stream = session.streamResponse(to: prompt)
        var lastContent = ""

        for try await snapshot in stream {
            let content: String = snapshot.content
            if content != lastContent {
                lastContent = content
                onToken(content)
            }
        }

        return lastContent
    }

    /// Sends a prompt and waits for the complete response (no streaming).
    func respond(to prompt: String) async throws -> String {
        guard let session else {
            throw LLMError.noSession
        }

        let response = try await session.respond(to: prompt)
        return response.content
    }

    // MARK: - Errors

    enum LLMError: LocalizedError {
        case noSession
        case modelUnavailable

        var errorDescription: String? {
            switch self {
            case .noSession:
                return "AI session not initialized. Please restart the AI assistant."
            case .modelUnavailable:
                return "On-device AI model is not available on this device."
            }
        }
    }
}

// MARK: - Campaign Context Builder

/// Builds system instructions from campaign data. Usable on any iOS version
/// since it only produces a String — no FoundationModels dependency.
struct CampaignContextBuilder {

    static func buildInstructions(
        campaignName: String,
        partyDescriptions: [String],
        npcDescriptions: [String],
        enemyNames: [String],
        placeNames: [String],
        latestSessionTitle: String?,
        latestSessionRecap: String?,
        gmNotesExcerpt: String?
    ) -> String {
        var parts: [String] = []
        parts.append("You are a D&D 5e Dungeon Master's AI assistant for the campaign '\(campaignName)'.")

        if !partyDescriptions.isEmpty {
            parts.append("Party: \(partyDescriptions.joined(separator: ", "))")
        }

        if !npcDescriptions.isEmpty {
            parts.append("NPCs: \(npcDescriptions.joined(separator: ", "))")
        }

        if !enemyNames.isEmpty {
            parts.append("Known enemies: \(enemyNames.joined(separator: ", "))")
        }

        if !placeNames.isEmpty {
            parts.append("Known locations: \(placeNames.joined(separator: ", "))")
        }

        if let title = latestSessionTitle {
            parts.append("Current session: \(title)")
        }

        if let recap = latestSessionRecap, !recap.isEmpty {
            parts.append("Session recap: \(String(recap.prefix(300)))")
        }

        if let notes = gmNotesExcerpt, !notes.isEmpty {
            parts.append("Campaign notes excerpt: \(String(notes.prefix(500)))")
        }

        parts.append("")
        parts.append("Guidelines:")
        parts.append("- Respond in character when asked for NPC dialogue.")
        parts.append("- Keep descriptions atmospheric and under 200 words unless asked for more.")
        parts.append("- Use D&D 5e rules when discussing mechanics.")
        parts.append("- Reference campaign-specific details when relevant.")
        parts.append("- Be concise and actionable for a DM running a live session.")

        return parts.joined(separator: "\n")
    }
}

import SwiftUI
import SwiftData

// MARK: - AI Assistant View

struct AIAssistantView: View {
    let campaign: Campaign

    var body: some View {
        if #available(iOS 26.0, *) {
            OnDeviceAIView(campaign: campaign)
        } else {
            AIUnavailableView(
                title: "On-Device AI",
                message: "The AI Co-DM requires iOS 26 or later with Apple Intelligence enabled. Update your iPad to unlock on-device AI — no internet required."
            )
        }
    }
}

// MARK: - On-Device AI View (iOS 26+)

@available(iOS 26.0, *)
struct OnDeviceAIView: View {
    let campaign: Campaign
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var streamingText = ""
    @State private var llmService = OnDeviceLLMService()
    @State private var hasInitializedSession = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(DMTheme.border)

            switch llmService.state {
            case .checking:
                ProgressView("Checking device capabilities...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DMTheme.background)

            case .unavailable(let detail):
                AIUnavailableView(
                    title: unavailableTitle(for: detail),
                    message: unavailableMessage(for: detail)
                )

            case .available:
                chatContent
            }
        }
        .background(DMTheme.background)
        .onAppear {
            initializeSession()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("AI Co-DM")
                        .font(.title2.bold())
                        .foregroundStyle(DMTheme.accent)
                    onDeviceBadge
                }
                Text(campaign.name)
                    .font(.caption)
                    .foregroundStyle(DMTheme.textDim)
            }
            Spacer()
            Button {
                resetConversation()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
                    .foregroundStyle(DMTheme.textSecondary)
            }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(messages.isEmpty && !isLoading)
        }
        .padding()
    }

    private var onDeviceBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "apple.intelligence")
                .font(.caption2)
            Text("On-Device")
                .font(.caption2.bold())
        }
        .foregroundStyle(DMTheme.accentGreen)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(DMTheme.accentGreen.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Chat Content

    private var chatContent: some View {
        VStack(spacing: 0) {
            if messages.isEmpty && errorMessage == nil {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if let error = errorMessage {
                                errorBanner(error)
                            }
                            ForEach(messages) { msg in
                                messageBubble(msg)
                                    .id(msg.id)
                            }
                            if isLoading && !streamingText.isEmpty {
                                streamingBubble
                                    .id("streaming")
                            } else if isLoading {
                                loadingIndicator
                                    .id("loading")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        withAnimation {
                            proxy.scrollTo(messages.last?.id, anchor: .bottom)
                        }
                    }
                    .onChange(of: streamingText) {
                        withAnimation {
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                    }
                }
            }

            Divider().overlay(DMTheme.border)

            if messages.isEmpty {
                quickPrompts
            }

            inputBar
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "apple.intelligence")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DMTheme.accent.opacity(0.3))
            Text("Your AI Co-DM is ready")
                .font(.headline)
                .foregroundStyle(DMTheme.textPrimary)
            Text("On-device AI — no internet required. Ask for NPC dialogue, location descriptions, encounter ideas, or session recaps.")
                .font(.subheadline)
                .foregroundStyle(DMTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Text("Powered by Apple Intelligence")
                .font(.caption)
                .foregroundStyle(DMTheme.textDim)
            Spacer()
        }
    }

    // MARK: - Quick Prompts

    private var quickPrompts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickPromptButton("Describe this location", icon: "map") {
                    let place = campaign.places.first?.name ?? "the current location"
                    sendMessage("Describe \(place) in vivid, atmospheric detail. What do the adventurers see, hear, and smell?")
                }
                quickPromptButton("NPC dialogue", icon: "person.wave.2") {
                    let npc = campaign.npcs.first?.name ?? "a mysterious stranger"
                    sendMessage("Write dialogue for \(npc) greeting the party. Stay in character and reveal hints about the current situation.")
                }
                quickPromptButton("Suggest encounter", icon: "shield.fill") {
                    let partyLevel = campaign.party.isEmpty ? 3 : campaign.party.map(\.level).reduce(0, +) / max(1, campaign.party.count)
                    sendMessage("Suggest a combat encounter appropriate for a party of \(campaign.party.count) at level \(partyLevel). Include monster selection, terrain, and a tactical twist.")
                }
                quickPromptButton("Recap session", icon: "book") {
                    sendMessage("Based on the campaign context, write a dramatic recap of the most recent session that I can read aloud to my players at the start of next session.")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func quickPromptButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(DMTheme.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(DMTheme.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DMTheme.accent.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Message Bubbles

    private func messageBubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 60) }

            VStack(alignment: msg.role == .user ? .trailing : .leading, spacing: 4) {
                Text(msg.role == .user ? "You" : "Co-DM")
                    .font(.caption2.bold())
                    .foregroundStyle(msg.role == .user ? DMTheme.accent : DMTheme.accentBlue)

                Text(msg.content)
                    .font(.body)
                    .foregroundStyle(DMTheme.textPrimary)
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(msg.role == .user ? DMTheme.accent.opacity(0.15) : DMTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(msg.role == .user ? DMTheme.accent.opacity(0.3) : DMTheme.border, lineWidth: 1)
            )

            if msg.role != .user { Spacer(minLength: 60) }
        }
    }

    private var streamingBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Co-DM")
                    .font(.caption2.bold())
                    .foregroundStyle(DMTheme.accentBlue)

                Text(streamingText)
                    .font(.body)
                    .foregroundStyle(DMTheme.textPrimary)
            }
            .padding(12)
            .background(DMTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(DMTheme.border, lineWidth: 1)
            )
            Spacer(minLength: 60)
        }
    }

    private var loadingIndicator: some View {
        HStack {
            HStack(spacing: 6) {
                ProgressView()
                    .tint(DMTheme.accent)
                Text("Thinking...")
                    .font(.caption)
                    .foregroundStyle(DMTheme.textDim)
            }
            .padding(12)
            .background(DMTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer(minLength: 60)
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DMTheme.accentRed)
            Text(message)
                .font(.caption)
                .foregroundStyle(DMTheme.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DMTheme.accentRed.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(DMTheme.accentRed.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask your Co-DM...", text: $inputText, axis: .vertical)
                .lineLimit(1...5)
                .foregroundStyle(DMTheme.textPrimary)
                .padding(10)
                .background(DMTheme.detail)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DMTheme.border, lineWidth: 1)
                )
                .onSubmit {
                    guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    sendMessage(inputText)
                }

            Button {
                guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                sendMessage(inputText)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? DMTheme.textDim
                            : DMTheme.accent
                    )
            }
            .disabled(isLoading || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(DMTheme.card)
    }

    // MARK: - Session Management

    private func initializeSession() {
        guard !hasInitializedSession, llmService.state == .available else { return }
        hasInitializedSession = true
        let instructions = buildInstructions()
        llmService.createSession(instructions: instructions)
    }

    private func resetConversation() {
        messages.removeAll()
        streamingText = ""
        isLoading = false
        errorMessage = nil
        let instructions = buildInstructions()
        llmService.resetSession(instructions: instructions)
    }

    // MARK: - Send Message

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Ensure session is initialized on first send
        if !hasInitializedSession {
            initializeSession()
        }

        inputText = ""
        errorMessage = nil

        let userMsg = ChatMessage(role: .user, content: trimmed)
        messages.append(userMsg)
        isLoading = true
        streamingText = ""

        Task {
            await performInference(prompt: trimmed)
        }
    }

    // MARK: - On-Device Inference

    private func performInference(prompt: String) async {
        do {
            let fullResponse = try await llmService.streamResponse(to: prompt) { partial in
                Task { @MainActor in
                    streamingText = partial
                }
            }

            await MainActor.run {
                if !fullResponse.isEmpty {
                    messages.append(ChatMessage(role: .assistant, content: fullResponse))
                }
                streamingText = ""
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = friendlyError(from: error)
                isLoading = false
                streamingText = ""
            }
        }
    }

    // MARK: - Campaign Context

    private func buildInstructions() -> String {
        CampaignContextBuilder.buildInstructions(
            campaignName: campaign.name,
            partyDescriptions: campaign.party.map {
                "\($0.name) (Level \($0.level) \($0.race) \($0.characterClass))"
            },
            npcDescriptions: campaign.npcs.prefix(10).map { npc in
                npc.role.isEmpty ? npc.name : "\(npc.name) (\(npc.role))"
            },
            enemyNames: campaign.enemies.filter(\.alive).prefix(5).map(\.name),
            placeNames: campaign.places.prefix(8).map(\.name),
            latestSessionTitle: campaign.sessions
                .sorted(by: { $0.date > $1.date }).first?.title,
            latestSessionRecap: campaign.sessions
                .sorted(by: { $0.date > $1.date }).first?.recap,
            gmNotesExcerpt: campaign.gmNotes.isEmpty ? nil : campaign.gmNotes
        )
    }

    // MARK: - Error Handling

    private func friendlyError(from error: Error) -> String {
        let description = error.localizedDescription
        if description.contains("guardrail") {
            return "The AI declined that request. Try rephrasing your prompt."
        } else if description.contains("context") || description.contains("exceeded") {
            return "The conversation is too long. Tap the reset button to start fresh."
        } else if description.contains("rate") {
            return "Too many requests. Wait a moment and try again."
        } else if description.contains("session") {
            return "AI session error. Tap reset to restart the conversation."
        }
        return "AI error: \(description)"
    }

    // MARK: - Unavailability Helpers

    private func unavailableTitle(for detail: OnDeviceLLMService.UnavailableDetail) -> String {
        switch detail {
        case .deviceNotEligible:
            return "Device Not Supported"
        case .appleIntelligenceDisabled:
            return "Apple Intelligence Disabled"
        case .modelNotReady:
            return "Model Downloading"
        case .unknown:
            return "AI Unavailable"
        }
    }

    private func unavailableMessage(for detail: OnDeviceLLMService.UnavailableDetail) -> String {
        switch detail {
        case .deviceNotEligible:
            return "The AI Co-DM requires an iPad with M1 chip or later (iPad Air 5th gen+, iPad Pro 2021+). Your device does not support on-device AI."
        case .appleIntelligenceDisabled:
            return "Enable Apple Intelligence in Settings > Apple Intelligence & Siri to use the AI Co-DM."
        case .modelNotReady:
            return "The on-device AI model is still downloading. This happens automatically in the background. Check back in a few minutes."
        case .unknown:
            return "On-device AI is currently unavailable. Make sure Apple Intelligence is enabled in Settings."
        }
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String

    enum ChatRole {
        case user
        case assistant
    }
}

// MARK: - AI Unavailable View (shared fallback)

struct AIUnavailableView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DMTheme.accent.opacity(0.25))

            Text(title)
                .font(.title2.bold())
                .foregroundStyle(DMTheme.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(DMTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 8) {
                featureRow(icon: "checkmark.circle.fill", text: "Runs entirely on-device", active: true)
                featureRow(icon: "checkmark.circle.fill", text: "No internet required", active: true)
                featureRow(icon: "checkmark.circle.fill", text: "Campaign-aware responses", active: true)
                featureRow(icon: "checkmark.circle.fill", text: "NPC dialogue generation", active: true)
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DMTheme.background)
    }

    private func featureRow(icon: String, text: String, active: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(active ? DMTheme.accentGreen.opacity(0.5) : DMTheme.textDim)
            Text(text)
                .font(.caption)
                .foregroundStyle(DMTheme.textDim)
        }
    }
}

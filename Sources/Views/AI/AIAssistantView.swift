import SwiftUI
import SwiftData

// MARK: - AI Assistant View

struct AIAssistantView: View {
    let campaign: Campaign
    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showSettings = false
    @State private var errorMessage: String?
    @State private var streamingText = ""

    @AppStorage("aiEndpoint") private var endpoint = "http://localhost:11434"
    @AppStorage("aiModel") private var model = "qwen2.5-coder:7b"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Co-DM")
                        .font(.title2.bold())
                        .foregroundStyle(DMTheme.accent)
                    Text(campaign.name)
                        .font(.caption)
                        .foregroundStyle(DMTheme.textDim)
                }
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundStyle(DMTheme.textSecondary)
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding()

            Divider().overlay(DMTheme.border)

            // Messages area
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

            // Quick prompts
            if messages.isEmpty {
                quickPrompts
            }

            // Input bar
            inputBar
        }
        .background(DMTheme.background)
        .sheet(isPresented: $showSettings) {
            AISettingsSheet(endpoint: $endpoint, model: $model)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(DMTheme.accent.opacity(0.3))
            Text("Your AI Co-DM is ready")
                .font(.headline)
                .foregroundStyle(DMTheme.textPrimary)
            Text("Ask for NPC dialogue, location descriptions, encounter ideas, or session recaps. The AI knows your campaign context.")
                .font(.subheadline)
                .foregroundStyle(DMTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
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
            if msg.role == "user" { Spacer(minLength: 60) }

            VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(msg.role == "user" ? "You" : "Co-DM")
                    .font(.caption2.bold())
                    .foregroundStyle(msg.role == "user" ? DMTheme.accent : DMTheme.accentBlue)

                Text(msg.content)
                    .font(.body)
                    .foregroundStyle(DMTheme.textPrimary)
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(msg.role == "user" ? DMTheme.accent.opacity(0.15) : DMTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(msg.role == "user" ? DMTheme.accent.opacity(0.3) : DMTheme.border, lineWidth: 1)
            )

            if msg.role != "user" { Spacer(minLength: 60) }
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

    // MARK: - Send Message

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        inputText = ""
        errorMessage = nil

        let userMsg = ChatMessage(role: "user", content: trimmed)
        messages.append(userMsg)
        isLoading = true
        streamingText = ""

        Task {
            await callOllama()
        }
    }

    // MARK: - Ollama API

    private func callOllama() async {
        let systemPrompt = buildSystemPrompt()

        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]
        for msg in messages {
            apiMessages.append(["role": msg.role, "content": msg.content])
        }

        let body: [String: Any] = [
            "model": model,
            "messages": apiMessages,
            "stream": true
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let url = URL(string: "\(endpoint)/api/chat") else {
            await MainActor.run {
                errorMessage = "Invalid endpoint URL. Check your AI settings."
                isLoading = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 120

        do {
            let (stream, response) = try await URLSession.shared.bytes(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                await MainActor.run {
                    errorMessage = "Server returned status \(httpResponse.statusCode). Check that Ollama is running and the model '\(model)' is available."
                    isLoading = false
                }
                return
            }

            var fullResponse = ""
            for try await line in stream.lines {
                guard let lineData = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let message = json["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    continue
                }
                fullResponse += content
                await MainActor.run {
                    streamingText = fullResponse
                }
            }

            await MainActor.run {
                if !fullResponse.isEmpty {
                    messages.append(ChatMessage(role: "assistant", content: fullResponse))
                }
                streamingText = ""
                isLoading = false
            }
        } catch let error as URLError {
            await MainActor.run {
                if error.code == .cannotConnectToHost || error.code == .timedOut || error.code == .cannotFindHost {
                    errorMessage = "Cannot connect to AI model at \(endpoint). Set up Ollama on your Mac and enter the endpoint in Settings (gear icon)."
                } else {
                    errorMessage = "Connection error: \(error.localizedDescription)"
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Error: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    // MARK: - Campaign Context Builder

    private func buildSystemPrompt() -> String {
        var parts: [String] = []
        parts.append("You are a D&D 5e Dungeon Master's AI assistant for the campaign '\(campaign.name)'.")

        // Party
        if !campaign.party.isEmpty {
            let pcList = campaign.party.map { "\($0.name) (Level \($0.level) \($0.race) \($0.characterClass))" }.joined(separator: ", ")
            parts.append("Party: \(pcList)")
        }

        // NPCs
        if !campaign.npcs.isEmpty {
            let npcList = campaign.npcs.prefix(10).map { npc in
                npc.role.isEmpty ? npc.name : "\(npc.name) (\(npc.role))"
            }.joined(separator: ", ")
            parts.append("NPCs: \(npcList)")
        }

        // Enemies
        if !campaign.enemies.isEmpty {
            let enemyList = campaign.enemies.filter(\.alive).prefix(5).map(\.name).joined(separator: ", ")
            if !enemyList.isEmpty {
                parts.append("Known enemies: \(enemyList)")
            }
        }

        // Places
        if !campaign.places.isEmpty {
            let placeList = campaign.places.prefix(8).map(\.name).joined(separator: ", ")
            parts.append("Known locations: \(placeList)")
        }

        // Current session
        if let latestSession = campaign.sessions.sorted(by: { $0.date > $1.date }).first {
            parts.append("Current session: \(latestSession.title)")
            if !latestSession.recap.isEmpty {
                let recap = String(latestSession.recap.prefix(300))
                parts.append("Session recap: \(recap)")
            }
        }

        // GM notes excerpt
        if !campaign.gmNotes.isEmpty {
            let notes = String(campaign.gmNotes.prefix(500))
            parts.append("Campaign notes excerpt: \(notes)")
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

// MARK: - Chat Message Model

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
}

// MARK: - AI Settings Sheet

struct AISettingsSheet: View {
    @Binding var endpoint: String
    @Binding var model: String
    @Environment(\.dismiss) private var dismiss
    @State private var testResult: String?
    @State private var isTesting = false

    private let commonModels = [
        "qwen2.5-coder:7b",
        "llama3.1:8b",
        "mistral:7b",
        "gemma2:9b",
        "phi3:14b"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ollama Endpoint")
                            .font(.subheadline.bold())
                            .foregroundStyle(DMTheme.textPrimary)
                        TextField("http://localhost:11434", text: $endpoint)
                            .font(.body.monospaced())
                            .foregroundStyle(DMTheme.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Text("The address of your Ollama server. Use your Mac's local IP for iPad access (e.g. http://192.168.1.100:11434).")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textDim)
                    }
                } header: {
                    Text("Connection")
                }
                .listRowBackground(DMTheme.card)

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model Name")
                            .font(.subheadline.bold())
                            .foregroundStyle(DMTheme.textPrimary)
                        TextField("qwen2.5-coder:7b", text: $model)
                            .font(.body.monospaced())
                            .foregroundStyle(DMTheme.textPrimary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        Text("Suggested models:")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textDim)

                        ForEach(commonModels, id: \.self) { m in
                            Button {
                                model = m
                            } label: {
                                HStack {
                                    Text(m)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(model == m ? DMTheme.accent : DMTheme.textSecondary)
                                    Spacer()
                                    if model == m {
                                        Image(systemName: "checkmark")
                                            .font(.caption)
                                            .foregroundStyle(DMTheme.accent)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Model")
                }
                .listRowBackground(DMTheme.card)

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .tint(DMTheme.accent)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            Text(isTesting ? "Testing..." : "Test Connection")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(DMTheme.accent)
                    }
                    .disabled(isTesting)

                    if let result = testResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("Connected") ? DMTheme.accentGreen : DMTheme.accentRed)
                    }
                } header: {
                    Text("Diagnostics")
                }
                .listRowBackground(DMTheme.card)

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Install Ollama", systemImage: "arrow.down.circle")
                            .font(.subheadline.bold())
                            .foregroundStyle(DMTheme.textPrimary)
                        Text("1. Install Ollama on your Mac: ollama.com\n2. Run: ollama pull \(model)\n3. Ollama starts automatically on port 11434\n4. For iPad access, set OLLAMA_HOST=0.0.0.0 and use your Mac's IP address")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textSecondary)
                    }
                } header: {
                    Text("Setup Guide")
                }
                .listRowBackground(DMTheme.card)
            }
            .scrollContentBackground(.hidden)
            .background(DMTheme.background)
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            guard let url = URL(string: "\(endpoint)/api/tags") else {
                await MainActor.run {
                    testResult = "Invalid URL"
                    isTesting = false
                }
                return
            }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    await MainActor.run {
                        testResult = "Server responded but returned an error"
                        isTesting = false
                    }
                    return
                }

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let models = json["models"] as? [[String: Any]] {
                    let names = models.compactMap { $0["name"] as? String }
                    let hasModel = names.contains { $0.hasPrefix(model.split(separator: ":").first.map(String.init) ?? model) }
                    await MainActor.run {
                        if hasModel {
                            testResult = "Connected. Model '\(model)' available."
                        } else {
                            testResult = "Connected, but '\(model)' not found. Available: \(names.joined(separator: ", "))"
                        }
                        isTesting = false
                    }
                } else {
                    await MainActor.run {
                        testResult = "Connected to Ollama."
                        isTesting = false
                    }
                }
            } catch {
                await MainActor.run {
                    testResult = "Cannot connect: \(error.localizedDescription)"
                    isTesting = false
                }
            }
        }
    }
}

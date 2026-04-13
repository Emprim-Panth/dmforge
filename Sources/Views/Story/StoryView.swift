import SwiftUI
import SwiftData

// MARK: - Story View

struct StoryView: View {
    @Bindable var campaign: Campaign
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSession: StorySession?

    private var sortedSessions: [StorySession] {
        campaign.sessions.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Story Planner")
                        .font(.title2.bold())
                        .foregroundStyle(DMTheme.accent)

                    Spacer()

                    Button {
                        addSession()
                    } label: {
                        Label("New Session", systemImage: "plus")
                            .font(.subheadline.bold())
                    }
                    .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentGreen.opacity(0.3)))
                    .frame(minHeight: 44)
                }
                .padding(DMTheme.contentPadding)

                Divider().overlay(DMTheme.border)

                if sortedSessions.isEmpty {
                    DMEmptyStateView(
                        icon: "book.closed",
                        title: "No Sessions Planned",
                        message: "Create your first session to start planning encounters, story arcs, and key moments.",
                        buttonTitle: "New Session",
                        buttonAction: { addSession() }
                    )
                } else {
                    List(sortedSessions) { session in
                        Button {
                            selectedSession = session
                        } label: {
                            SessionRow(session: session)
                        }
                        .listRowBackground(DMTheme.card)
                        .listRowSeparatorTint(DMTheme.border)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(DMTheme.background)
            .navigationDestination(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
        }
    }

    private func addSession() {
        let count = campaign.sessions.count + 1
        let session = StorySession(title: "Session \(count)")
        session.campaign = campaign
        campaign.sessions.append(session)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: StorySession

    var body: some View {
        HStack(spacing: DMTheme.cardSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                    .foregroundStyle(DMTheme.textPrimary)

                Text(session.date, format: .dateTime.month().day().year())
                    .font(.caption)
                    .foregroundStyle(DMTheme.textSecondary)
            }

            Spacer()

            StatusBadge(status: session.status)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(DMTheme.textDim)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: String

    private var color: Color {
        switch status {
        case "active": return DMTheme.accent
        case "completed": return DMTheme.accentGreen
        default: return DMTheme.accentBlue
        }
    }

    var body: some View {
        Text(status.capitalized)
            .font(.caption2.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Session Detail

struct SessionDetailView: View {
    @Bindable var session: StorySession
    @State private var acts: [StoryAct] = []
    @State private var showAddAct = false

    var body: some View {
        VStack(spacing: 0) {
            // Session info header
            VStack(alignment: .leading, spacing: 8) {
                TextField("Session title", text: $session.title)
                    .font(.title3.bold())
                    .foregroundStyle(DMTheme.textPrimary)

                HStack(spacing: DMTheme.cardSpacing) {
                    DatePicker("", selection: $session.date, displayedComponents: .date)
                        .labelsHidden()

                    Picker("Status", selection: $session.status) {
                        Text("Planned").tag("planned")
                        Text("Active").tag("active")
                        Text("Completed").tag("completed")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }

                if !session.recap.isEmpty || session.status == "completed" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recap")
                            .font(.caption.bold())
                            .foregroundStyle(DMTheme.accent)
                        TextEditor(text: $session.recap)
                            .font(.subheadline)
                            .foregroundStyle(DMTheme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .background(DMTheme.detail)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DMTheme.border, lineWidth: 1)
                            )
                            .frame(height: 80)
                    }
                }
            }
            .padding(DMTheme.contentPadding)

            Divider().overlay(DMTheme.border)

            // Acts list
            ScrollView {
                LazyVStack(spacing: DMTheme.cardSpacing) {
                    ForEach(acts.indices, id: \.self) { index in
                        ActCard(act: $acts[index], onDelete: {
                            acts.remove(at: index)
                            saveActs()
                        })
                    }

                    Button {
                        acts.append(StoryAct(title: "Act \(acts.count + 1)"))
                        saveActs()
                    } label: {
                        Label("Add Act", systemImage: "plus")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DMSmallButtonStyle())
                    .frame(minHeight: 44)
                }
                .padding(DMTheme.contentPadding)
            }
        }
        .background(DMTheme.background)
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadActs() }
        .onChange(of: acts) { _, _ in saveActs() }
    }

    private func loadActs() {
        guard !session.notes.isEmpty,
              let data = session.notes.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([StoryAct].self, from: data) else {
            return
        }
        acts = decoded
    }

    private func saveActs() {
        guard let data = try? JSONEncoder().encode(acts),
              let json = String(data: data, encoding: .utf8) else { return }
        session.notes = json
    }
}

// MARK: - Story Act model (stored as JSON in session.notes)

struct StoryAct: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var description: String = ""
    var status: String = "planned"
    var branches: [StoryBranch] = []
    var npcTags: [String] = []
    var encounterTags: [String] = []
}

struct StoryBranch: Codable, Equatable, Identifiable {
    var id = UUID()
    var condition: String
    var leadsTo: String
}

// MARK: - Act Card

struct ActCard: View {
    @Binding var act: StoryAct
    let onDelete: () -> Void

    @State private var showBranchInput = false
    @State private var newCondition = ""
    @State private var newLeadsTo = ""
    @State private var newTag = ""
    @State private var tagType = "npc"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title row
            HStack {
                TextField("Act title", text: $act.title)
                    .font(.headline)
                    .foregroundStyle(DMTheme.accent)

                Spacer()

                Picker("", selection: $act.status) {
                    Text("Planned").tag("planned")
                    Text("Active").tag("active")
                    Text("Done").tag("completed")
                }
                .pickerStyle(.menu)
                .tint(statusColor)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(DMTheme.accentRed)
                }
                .frame(minWidth: 44, minHeight: 44)
            }

            // Description
            TextEditor(text: $act.description)
                .font(.subheadline)
                .foregroundStyle(DMTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .background(DMTheme.detail)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DMTheme.border, lineWidth: 1)
                )
                .frame(minHeight: 60, maxHeight: 120)

            // Branches
            if !act.branches.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Branches")
                        .font(.caption.bold())
                        .foregroundStyle(DMTheme.textSecondary)

                    ForEach(act.branches) { branch in
                        HStack(spacing: 4) {
                            Text("If")
                                .font(.caption)
                                .foregroundStyle(DMTheme.textDim)
                            Text(branch.condition)
                                .font(.caption)
                                .foregroundStyle(DMTheme.textPrimary)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                                .foregroundStyle(DMTheme.accent)
                            Text(branch.leadsTo)
                                .font(.caption)
                                .foregroundStyle(DMTheme.accentBlue)
                            Spacer()
                            Button {
                                act.branches.removeAll { $0.id == branch.id }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                                    .foregroundStyle(DMTheme.accentRed)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                        }
                    }
                }
            }

            // Tags
            if !act.npcTags.isEmpty || !act.encounterTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(act.npcTags, id: \.self) { tag in
                        TagView(text: tag, color: DMTheme.accentBlue) {
                            act.npcTags.removeAll { $0 == tag }
                        }
                    }
                    ForEach(act.encounterTags, id: \.self) { tag in
                        TagView(text: tag, color: DMTheme.accentRed) {
                            act.encounterTags.removeAll { $0 == tag }
                        }
                    }
                }
            }

            // Action buttons
            HStack(spacing: 8) {
                Button("+ Branch") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showBranchInput.toggle()
                    }
                }
                .font(.caption)
                .frame(minHeight: 44)

                Button("+ NPC") {
                    tagType = "npc"
                    newTag = ""
                    showBranchInput = false
                }
                .font(.caption)
                .frame(minHeight: 44)

                Button("+ Encounter") {
                    tagType = "encounter"
                    newTag = ""
                    showBranchInput = false
                }
                .font(.caption)
                .frame(minHeight: 44)
            }
            .foregroundStyle(DMTheme.textSecondary)

            // Branch input
            if showBranchInput {
                HStack(spacing: 6) {
                    TextField("If...", text: $newCondition)
                        .font(.caption)
                        .padding(8)
                        .background(DMTheme.detail)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(DMTheme.accent)

                    TextField("Then...", text: $newLeadsTo)
                        .font(.caption)
                        .padding(8)
                        .background(DMTheme.detail)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Button("Add") {
                        if !newCondition.isEmpty && !newLeadsTo.isEmpty {
                            act.branches.append(StoryBranch(condition: newCondition, leadsTo: newLeadsTo))
                            newCondition = ""
                            newLeadsTo = ""
                            showBranchInput = false
                        }
                    }
                    .font(.caption)
                    .frame(minHeight: 44)
                }
            }
        }
        .dmCard()
        .overlay(
            RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius)
                .stroke(statusBorderColor, lineWidth: statusBorderWidth)
        )
    }

    private var statusColor: Color {
        switch act.status {
        case "active": return DMTheme.accent
        case "completed": return DMTheme.accentGreen
        default: return DMTheme.accentBlue
        }
    }

    private var statusBorderColor: Color {
        switch act.status {
        case "active": return DMTheme.accent.opacity(0.5)
        default: return DMTheme.border
        }
    }

    private var statusBorderWidth: CGFloat {
        act.status == "active" ? 2 : 1
    }
}

// MARK: - Tag View

struct TagView: View {
    let text: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption2)
                .foregroundStyle(color)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8))
                    .foregroundStyle(color.opacity(0.7))
            }
            .frame(minWidth: 20, minHeight: 20)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

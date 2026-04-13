import SwiftUI
import SwiftData

struct DashboardView: View {
    @Bindable var campaign: Campaign
    @State private var selectedTab: Tab = .encounter
    @State private var showCharacterCreator = false

    enum Tab: String, CaseIterable {
        case encounter = "Encounter"
        case people = "People"
        case places = "Places"
        case story = "Story"
        case bestiary = "Bestiary"
        case map = "Map"
        case notes = "Notes"
        case reference = "Reference"
        case ai = "AI"

        var icon: String {
            switch self {
            case .encounter: return "shield.fill"
            case .people: return "person.3.fill"
            case .places: return "map.fill"
            case .story: return "book.fill"
            case .bestiary: return "pawprint.fill"
            case .map: return "globe.americas.fill"
            case .notes: return "note.text"
            case .reference: return "books.vertical.fill"
            case .ai: return "sparkles"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar — leather DM screen feel
            VStack(spacing: 0) {
                // Campaign header with badge-style treatment
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Image(systemName: "book.closed.fill")
                            .font(.title3)
                            .foregroundStyle(DMTheme.accent)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(campaign.name)
                                .font(.title3.bold())
                                .foregroundStyle(DMTheme.accent)
                            Text("D&D 5e Campaign")
                                .font(.caption)
                                .foregroundStyle(DMTheme.textDim)
                        }
                    }
                }
                .padding(.horizontal, DMTheme.contentPadding)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DMTheme.accent.opacity(0.05))
                .overlay(
                    Rectangle()
                        .fill(DMTheme.accent.opacity(0.2))
                        .frame(height: 1),
                    alignment: .bottom
                )

                // Party compact strip
                PartyStripView(campaign: campaign, onAddPC: { showCharacterCreator = true })

                // Divider with subtle gold tint
                Rectangle()
                    .fill(DMTheme.accent.opacity(0.15))
                    .frame(height: 1)

                // Tab list
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: tab.icon)
                                        .font(.body)
                                        .frame(width: 24)
                                        .foregroundStyle(selectedTab == tab ? DMTheme.accent : DMTheme.textDim)

                                    Text(tab.rawValue)
                                        .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                                        .foregroundStyle(selectedTab == tab ? DMTheme.textPrimary : DMTheme.textSecondary)

                                    Spacer()

                                    if selectedTab == tab {
                                        RoundedRectangle(cornerRadius: 1.5)
                                            .fill(DMTheme.accent)
                                            .frame(width: 3, height: 20)
                                    }
                                }
                                .padding(.horizontal, DMTheme.contentPadding)
                                .padding(.vertical, 10)
                                .frame(minHeight: 44)
                                .background(
                                    selectedTab == tab
                                        ? DMTheme.accent.opacity(0.1)
                                        : Color.clear
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }
            }
            .background(DMTheme.sidebarBackground)
        } detail: {
            // Main content area
            Group {
                switch selectedTab {
                case .encounter:
                    EncounterView(campaign: campaign)
                case .people:
                    PeopleView(campaign: campaign)
                case .places:
                    PlacesView(campaign: campaign)
                case .story:
                    StoryView(campaign: campaign)
                case .bestiary:
                    BestiaryView(campaign: campaign)
                case .map:
                    MapPlaceholder()
                case .notes:
                    NotesView(campaign: campaign)
                case .reference:
                    ReferenceView()
                case .ai:
                    AIPlaceholder()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DMTheme.background)
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showCharacterCreator) {
            CharacterCreatorView(campaign: campaign)
                .presentationDetents([.large])
        }
    }
}

// MARK: - Party Strip (compact sidebar)

struct PartyStripView: View {
    let campaign: Campaign
    var onAddPC: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("PARTY")
                    .font(.caption2.bold())
                    .foregroundStyle(DMTheme.accent)
                    .tracking(1.5)
                Spacer()
                if let onAddPC {
                    Button {
                        onAddPC()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.body)
                            .foregroundStyle(DMTheme.accent)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                Text("\(campaign.party.count)")
                    .font(.caption2.monospacedDigit().bold())
                    .foregroundStyle(DMTheme.textDim)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DMTheme.detail)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, DMTheme.contentPadding)

            if campaign.party.isEmpty {
                Text("No party members")
                    .font(.caption)
                    .foregroundStyle(DMTheme.textDim)
                    .padding(.bottom, 4)
            } else {
                ForEach(campaign.party) { pc in
                    HStack(spacing: 8) {
                        Text(pc.name)
                            .font(.caption)
                            .foregroundStyle(DMTheme.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        // HP bar
                        HPBarView(current: pc.hpCurrent, max: pc.hpMax, height: 8)
                            .frame(width: 60)

                        Text("\(pc.hpCurrent)/\(pc.hpMax)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(DMTheme.textDim)
                    }
                    .padding(.horizontal, DMTheme.contentPadding)
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - HP Bar

struct HPBarView: View {
    let current: Int
    let max: Int
    var height: CGFloat = 22

    var ratio: Double {
        guard max > 0 else { return 0 }
        return Double(current) / Double(max)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track with inner shadow
                RoundedRectangle(cornerRadius: height / 3)
                    .fill(Color(hex: "13131c"))
                    .overlay(
                        RoundedRectangle(cornerRadius: height / 3)
                            .stroke(Color.black.opacity(0.4), lineWidth: 1)
                    )
                    .overlay(
                        // Inner shadow effect
                        RoundedRectangle(cornerRadius: height / 3)
                            .fill(
                                LinearGradient(
                                    colors: [.black.opacity(0.3), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                    )

                // Fill with gradient for depth
                RoundedRectangle(cornerRadius: height / 3)
                    .fill(
                        LinearGradient(
                            colors: [
                                DMTheme.hpColor(ratio: ratio).opacity(0.9),
                                DMTheme.hpColor(ratio: ratio),
                                DMTheme.hpColor(ratio: ratio).opacity(0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: geo.size.width * Swift.max(0, Swift.min(1, ratio)))
                    .animation(.easeInOut(duration: 0.3), value: ratio)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Notes View (fully functional)

struct NotesView: View {
    @Bindable var campaign: Campaign

    var body: some View {
        VStack(alignment: .leading, spacing: DMTheme.contentPadding) {
            Text("DM Notes")
                .font(.title2.bold())
                .foregroundStyle(DMTheme.accent)

            TextEditor(text: $campaign.gmNotes)
                .font(.body)
                .foregroundStyle(DMTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .background(DMTheme.detail)
                .clipShape(RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius)
                        .stroke(DMTheme.border, lineWidth: 1)
                )
        }
        .padding(DMTheme.contentPadding)
    }
}

// MARK: - Placeholder views (to be built out)

struct EncounterPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Encounter", icon: "shield.fill", description: "Combat management — coming in Phase 3")
    }
}

struct PeoplePlaceholder: View {
    var body: some View {
        PlaceholderView(title: "People", icon: "person.3.fill", description: "PCs, NPCs, Enemies, Fallen — coming in Phase 3")
    }
}

struct PlacesPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Places", icon: "map.fill", description: "Location tree — coming in Phase 3")
    }
}

struct StoryPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Story", icon: "book.fill", description: "Session planner — coming in Phase 3")
    }
}

struct BestiaryPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Bestiary", icon: "pawprint.fill", description: "322 SRD monsters — coming in Phase 3")
    }
}

struct MapPlaceholder: View {
    var body: some View {
        ZStack {
            DMTheme.background.ignoresSafeArea()

            // Parchment texture effect
            RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "1a1810").opacity(0.6),
                            Color(hex: "151310").opacity(0.4),
                            Color(hex: "1a1810").opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(40)

            VStack(spacing: 20) {
                Image(systemName: "map")
                    .font(.system(size: 64, weight: .ultraLight))
                    .foregroundStyle(DMTheme.accent.opacity(0.25))

                Text("World Map")
                    .font(.title2.bold())
                    .foregroundStyle(DMTheme.textPrimary)

                Text("Import your Wonderdraft map\nor draw your own")
                    .font(.subheadline)
                    .foregroundStyle(DMTheme.textSecondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: DMTheme.contentPadding) {
                    VStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.title3)
                            .foregroundStyle(DMTheme.accent.opacity(0.5))
                        Text("Import")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textDim)
                    }
                    .frame(width: 80, height: 80)
                    .background(DMTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(spacing: 4) {
                        Image(systemName: "pencil.and.outline")
                            .font(.title3)
                            .foregroundStyle(DMTheme.accent.opacity(0.5))
                        Text("Draw")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textDim)
                    }
                    .frame(width: 80, height: 80)
                    .background(DMTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 8)

                Text("Coming in Phase 4")
                    .font(.caption)
                    .foregroundStyle(DMTheme.textDim)
                    .padding(.top, 4)
            }
        }
    }
}

struct ReferencePlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Reference", icon: "books.vertical.fill", description: "SRD search — coming in Phase 3")
    }
}

struct AIPlaceholder: View {
    var body: some View {
        ZStack {
            DMTheme.background.ignoresSafeArea()

            VStack(spacing: 20) {
                // Sparkle cluster
                ZStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(DMTheme.accent.opacity(0.2))

                    Image(systemName: "sparkle")
                        .font(.system(size: 20))
                        .foregroundStyle(DMTheme.accent.opacity(0.4))
                        .offset(x: 30, y: -25)

                    Image(systemName: "sparkle")
                        .font(.system(size: 14))
                        .foregroundStyle(DMTheme.accent.opacity(0.3))
                        .offset(x: -25, y: 20)
                }

                Text("AI Co-DM")
                    .font(.title2.bold())
                    .foregroundStyle(DMTheme.textPrimary)

                Text("Your AI co-DM is being trained")
                    .font(.subheadline)
                    .foregroundStyle(DMTheme.textSecondary)

                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DMTheme.accentGreen.opacity(0.5))
                        Text("On-device inference")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textDim)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DMTheme.accentGreen.opacity(0.5))
                        Text("No internet required")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textDim)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "circle.dotted")
                            .foregroundStyle(DMTheme.accent.opacity(0.5))
                        Text("NPC dialogue generation")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textDim)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "circle.dotted")
                            .foregroundStyle(DMTheme.accent.opacity(0.5))
                        Text("Encounter suggestions")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textDim)
                    }
                }
                .padding(.top, 8)

                Text("Coming in Phase 4")
                    .font(.caption)
                    .foregroundStyle(DMTheme.textDim)
                    .padding(.top, 4)
            }
        }
    }
}

struct PlaceholderView: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(DMTheme.accent.opacity(0.3))
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(DMTheme.textPrimary)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(DMTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DMTheme.background)
    }
}

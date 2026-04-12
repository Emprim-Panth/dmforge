import SwiftUI
import SwiftData

struct DashboardView: View {
    let campaign: Campaign
    @State private var selectedTab: Tab = .encounter

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
            // Sidebar
            VStack(spacing: 0) {
                // Campaign header
                VStack(alignment: .leading, spacing: 4) {
                    Text(campaign.name)
                        .font(.title2.bold())
                        .foregroundStyle(DMTheme.accent)
                    Text("D&D 5e Campaign")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                // Party compact strip
                PartyStripView(campaign: campaign)

                Divider()

                // Tab list
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(Tab.allCases, id: \.self) { tab in
                            Button {
                                selectedTab = tab
                            } label: {
                                Label(tab.rawValue, systemImage: tab.icon)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .foregroundStyle(selectedTab == tab ? DMTheme.accent : DMTheme.textSecondary)
                                    .background(selectedTab == tab ? DMTheme.cardHover : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .background(DMTheme.background)
        } detail: {
            // Main content area
            Group {
                switch selectedTab {
                case .encounter:
                    EncounterPlaceholder()
                case .people:
                    PeoplePlaceholder()
                case .places:
                    PlacesPlaceholder()
                case .story:
                    StoryPlaceholder()
                case .bestiary:
                    BestiaryPlaceholder()
                case .map:
                    MapPlaceholder()
                case .notes:
                    NotesView(campaign: campaign)
                case .reference:
                    ReferencePlaceholder()
                case .ai:
                    AIPlaceholder()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DMTheme.background)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Party Strip (compact sidebar)

struct PartyStripView: View {
    let campaign: Campaign

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Party")
                    .font(.caption.bold())
                    .foregroundStyle(DMTheme.accent)
                Spacer()
                Text("\(campaign.party.count) PCs")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

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
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 8)
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
                RoundedRectangle(cornerRadius: height / 3)
                    .fill(Color(hex: "13131c"))

                RoundedRectangle(cornerRadius: height / 3)
                    .fill(DMTheme.hpColor(ratio: ratio))
                    .frame(width: geo.size.width * Swift.max(0, Swift.min(1, ratio)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Notes View (fully functional)

struct NotesView: View {
    @Bindable var campaign: Campaign

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("DM Notes")
                .font(.title2.bold())
                .foregroundStyle(DMTheme.accent)

            TextEditor(text: $campaign.gmNotes)
                .font(.body)
                .foregroundStyle(DMTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .background(DMTheme.detail)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DMTheme.border, lineWidth: 1)
                )
        }
        .padding()
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
        PlaceholderView(title: "World Map", icon: "globe.americas.fill", description: "Travel paths + encounter zones — coming in Phase 4")
    }
}

struct ReferencePlaceholder: View {
    var body: some View {
        PlaceholderView(title: "Reference", icon: "books.vertical.fill", description: "SRD search — coming in Phase 3")
    }
}

struct AIPlaceholder: View {
    var body: some View {
        PlaceholderView(title: "AI Co-DM", icon: "sparkles", description: "On-device AI assistant — coming in Phase 4")
    }
}

struct PlaceholderView: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(DMTheme.accent.opacity(0.4))
            Text(title)
                .font(.title.bold())
                .foregroundStyle(DMTheme.textPrimary)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

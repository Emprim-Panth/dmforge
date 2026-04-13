import SwiftUI
import SwiftData

// MARK: - BestiaryView

struct BestiaryView: View {
    let campaign: Campaign
    @State private var allMonsters: [SRDMonster] = []
    @State private var searchText = ""
    @State private var selectedCR: String = "All"
    @State private var selectedType: String = "All"
    @State private var showRosterOnly = false
    @State private var selectedMonster: SRDMonster?

    private let crFilters = ["All", "0-1", "2-4", "5-8", "9-12", "13-17", "18+"]
    private let typeFilters = [
        "All", "Aberration", "Beast", "Celestial", "Construct", "Dragon",
        "Elemental", "Fey", "Fiend", "Giant", "Humanoid", "Monstrosity",
        "Ooze", "Plant", "Undead"
    ]

    private var filteredMonsters: [SRDMonster] {
        var result = allMonsters

        // Roster filter
        if showRosterOnly {
            let roster = Set(campaign.monsterRoster)
            result = result.filter { roster.contains($0.srdID) }
        }

        // Search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(query) }
        }

        // CR filter
        if selectedCR != "All" {
            let range = crRange(for: selectedCR)
            result = result.filter { $0.challengeRating >= range.0 && $0.challengeRating <= range.1 }
        }

        // Type filter
        if selectedType != "All" {
            let typeLower = selectedType.lowercased()
            result = result.filter { $0.type.lowercased() == typeLower }
        }

        return result.sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Bestiary")
                    .font(.title2.bold())
                    .foregroundStyle(DMTheme.accent)
                Spacer()
                Text("\(filteredMonsters.count) of \(allMonsters.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DMTheme.textDim)
            }
            .padding(DMTheme.contentPadding)

            // Mode toggle
            HStack(spacing: 0) {
                modeButton("Campaign Roster", active: showRosterOnly) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRosterOnly = true
                    }
                }
                modeButton("Full SRD", active: !showRosterOnly) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showRosterOnly = false
                    }
                }
            }
            .background(DMTheme.detail)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, DMTheme.contentPadding)

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DMTheme.textDim)
                TextField("Search monsters...", text: $searchText)
                    .foregroundStyle(DMTheme.textPrimary)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DMTheme.textDim)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(DMTheme.detail)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DMTheme.border, lineWidth: 1)
            )
            .padding(.horizontal, DMTheme.contentPadding)
            .padding(.top, DMTheme.cardSpacing)

            // CR filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(crFilters, id: \.self) { cr in
                        filterChip(cr, selected: selectedCR == cr) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCR = cr
                            }
                        }
                    }
                }
                .padding(.horizontal, DMTheme.contentPadding)
            }
            .padding(.top, DMTheme.cardSpacing)

            // Type filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(typeFilters, id: \.self) { type in
                        filterChip(type, selected: selectedType == type) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedType = type
                            }
                        }
                    }
                }
                .padding(.horizontal, DMTheme.contentPadding)
            }
            .padding(.top, 4)

            // Monster list
            ScrollView {
                if showRosterOnly && filteredMonsters.isEmpty {
                    DMEmptyStateView(
                        icon: "pawprint",
                        title: "No Monsters in Roster",
                        message: "Switch to Full SRD to browse and add monsters to your campaign roster."
                    )
                } else {
                    LazyVStack(spacing: DMTheme.cardSpacing) {
                        ForEach(filteredMonsters) { monster in
                            monsterCard(monster)
                                .onTapGesture {
                                    selectedMonster = monster
                                }
                        }
                    }
                    .padding(.horizontal, DMTheme.contentPadding)
                    .padding(.vertical, DMTheme.cardSpacing)
                }
            }
        }
        .background(DMTheme.background)
        .onAppear { loadMonsters() }
        .sheet(item: $selectedMonster) { monster in
            MonsterDetailView(monster: monster, campaign: campaign)
                .presentationDetents([.large])
        }
    }

    // MARK: - Subviews

    private func modeButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(active ? .semibold : .regular))
                .foregroundStyle(active ? DMTheme.accent : DMTheme.textDim)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(active ? DMTheme.card : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func filterChip(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .foregroundStyle(selected ? DMTheme.background : DMTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? DMTheme.accent : DMTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .frame(minHeight: 32)
    }

    private func monsterCard(_ monster: SRDMonster) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(monster.name)
                    .font(.headline)
                    .foregroundStyle(DMTheme.textPrimary)
                HStack(spacing: 8) {
                    Text("\(monster.size) \(monster.type)")
                        .font(.caption)
                        .foregroundStyle(DMTheme.textSecondary)
                    Label("\(monster.hitPoints) HP", systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(DMTheme.accentRed)
                    Label("AC \(monster.armorClass)", systemImage: "shield.fill")
                        .font(.caption)
                        .foregroundStyle(DMTheme.textDim)
                }
            }
            Spacer()
            Text("CR \(monster.crDisplay)")
                .font(.caption.bold())
                .foregroundStyle(DMTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DMTheme.accent.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .dmCard()
    }

    // MARK: - Helpers

    private func loadMonsters() {
        guard allMonsters.isEmpty else { return }
        guard let url = Bundle.main.url(forResource: "monsters", withExtension: "json", subdirectory: "SRD") else { return }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(SRDMonsterFile.self, from: data)
            allMonsters = file.monsters
        } catch {
            print("Failed to load SRD monsters: \(error)")
        }
    }

    private func crRange(for filter: String) -> (Double, Double) {
        switch filter {
        case "0-1": return (0, 1)
        case "2-4": return (2, 4)
        case "5-8": return (5, 8)
        case "9-12": return (9, 12)
        case "13-17": return (13, 17)
        case "18+": return (18, 100)
        default: return (-1, 100)
        }
    }
}

// MARK: - Monster Detail View

struct MonsterDetailView: View {
    let monster: SRDMonster
    let campaign: Campaign
    @Environment(\.dismiss) private var dismiss

    private var isInRoster: Bool {
        campaign.monsterRoster.contains(monster.srdID)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DMTheme.contentPadding) {
                    // Title + CR
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(monster.name)
                                .font(.title2.bold())
                                .foregroundStyle(DMTheme.textPrimary)
                            Text("\(monster.size) \(monster.type), \(monster.alignment)")
                                .font(.subheadline)
                                .foregroundStyle(DMTheme.textSecondary)
                        }
                        Spacer()
                        Text("CR \(monster.crDisplay)")
                            .font(.headline)
                            .foregroundStyle(DMTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DMTheme.accent.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Divider().background(DMTheme.border)

                    // Core stats
                    HStack(spacing: DMTheme.contentPadding) {
                        statBlock("AC", value: "\(monster.armorClass)")
                        statBlock("HP", value: "\(monster.hitPoints)")
                        statBlock("Hit Dice", value: monster.hitDice)
                    }

                    // Speed
                    let speedText = monster.speed.map { "\($0.key) \($0.value) ft." }.joined(separator: ", ")
                    if !speedText.isEmpty {
                        detailRow("Speed", value: speedText)
                    }

                    Divider().background(DMTheme.border)

                    // Ability Scores Grid
                    abilityScoreGrid

                    Divider().background(DMTheme.border)

                    // Skills
                    if !monster.skills.isEmpty {
                        let skillText = monster.skills.map { "\($0.key.capitalized) +\($0.value)" }.joined(separator: ", ")
                        detailRow("Skills", value: skillText)
                    }

                    // Senses
                    if !monster.senses.isEmpty {
                        let senseText = monster.senses.map { "\($0.key.replacingOccurrences(of: "_", with: " ").capitalized) \($0.value.displayString)" }.joined(separator: ", ")
                        detailRow("Senses", value: senseText)
                    }

                    // Languages
                    if !monster.languages.isEmpty {
                        detailRow("Languages", value: monster.languages.joined(separator: ", "))
                    }

                    // Damage Immunities
                    if !monster.damageImmunities.isEmpty {
                        detailRow("Damage Immunities", value: monster.damageImmunities.joined(separator: ", "))
                    }

                    // Damage Resistances
                    if !monster.damageResistances.isEmpty {
                        detailRow("Damage Resistances", value: monster.damageResistances.joined(separator: ", "))
                    }

                    // Damage Vulnerabilities
                    if !monster.damageVulnerabilities.isEmpty {
                        detailRow("Damage Vulnerabilities", value: monster.damageVulnerabilities.joined(separator: ", "))
                    }

                    // Condition Immunities
                    if !monster.conditionImmunities.isEmpty {
                        detailRow("Condition Immunities", value: monster.conditionImmunities.joined(separator: ", "))
                    }

                    // Special Abilities
                    if !monster.specialAbilities.isEmpty {
                        Divider().background(DMTheme.border)
                        sectionTitle("Special Abilities")
                        ForEach(monster.specialAbilities) { ability in
                            abilityBlock(name: ability.name, desc: ability.description)
                        }
                    }

                    // Actions
                    if !monster.actions.isEmpty {
                        Divider().background(DMTheme.border)
                        sectionTitle("Actions")
                        ForEach(monster.actions) { action in
                            actionBlock(action)
                        }
                    }

                    // Legendary Actions
                    if !monster.legendaryActions.isEmpty {
                        Divider().background(DMTheme.border)
                        sectionTitle("Legendary Actions")
                        ForEach(monster.legendaryActions) { action in
                            abilityBlock(name: action.name, desc: action.description)
                        }
                    }

                    Divider().background(DMTheme.border)

                    // Add/Remove from Campaign
                    Button {
                        if isInRoster {
                            campaign.monsterRoster.removeAll { $0 == monster.srdID }
                        } else {
                            campaign.monsterRoster.append(monster.srdID)
                        }
                    } label: {
                        Label(
                            isInRoster ? "Remove from Campaign" : "Add to Campaign",
                            systemImage: isInRoster ? "minus.circle" : "plus.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DMButtonStyle(color: isInRoster ? DMTheme.accentRed.opacity(0.3) : DMTheme.accentGreen.opacity(0.3)))
                    .frame(minHeight: 44)
                }
                .padding(DMTheme.contentPadding)
            }
            .background(DMTheme.background)
            .navigationTitle(monster.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Ability Score Grid

    private var abilityScoreGrid: some View {
        let scores = monster.abilityScores
        let abilities: [(String, Int)] = [
            ("STR", scores.str), ("DEX", scores.dex), ("CON", scores.con),
            ("INT", scores.int), ("WIS", scores.wis), ("CHA", scores.cha)
        ]
        return HStack(spacing: 8) {
            ForEach(abilities, id: \.0) { label, score in
                VStack(spacing: 2) {
                    Text(label)
                        .font(.caption2.bold())
                        .foregroundStyle(DMTheme.accent)
                    Text("\(score)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(DMTheme.textPrimary)
                    Text(SRDMonster.modifierString(for: score))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DMTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(DMTheme.detail)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Detail Components

    private func statBlock(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DMTheme.textDim)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(DMTheme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DMTheme.detail)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func detailRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(DMTheme.accent)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(DMTheme.textPrimary)
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(DMTheme.accent)
    }

    private func abilityBlock(name: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.subheadline.bold())
                .foregroundStyle(DMTheme.textPrimary)
            Text(desc)
                .font(.caption)
                .foregroundStyle(DMTheme.textSecondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DMTheme.detail)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func actionBlock(_ action: SRDMonster.MonsterAction) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(action.name)
                .font(.subheadline.bold())
                .foregroundStyle(DMTheme.textPrimary)

            if action.type.contains("weapon") {
                var parts: [String] = []
                let _ = {
                    if let bonus = action.attackBonus {
                        parts.append("+\(bonus) to hit")
                    }
                    if let reach = action.reach {
                        parts.append("reach \(reach) ft.")
                    }
                    if let dmg = action.damage, let dtype = action.damageType {
                        parts.append("\(dmg) \(dtype) damage")
                    }
                }()
                Text(parts.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(DMTheme.accentRed)
            }

            if let desc = action.description {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(DMTheme.textSecondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DMTheme.detail)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

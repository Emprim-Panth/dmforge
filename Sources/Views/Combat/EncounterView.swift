import SwiftUI
import SwiftData

// MARK: - Encounter View

struct EncounterView: View {
    @Bindable var campaign: Campaign
    @Environment(\.modelContext) private var modelContext
    @State private var showMonsterPicker = false

    private var aliveEnemies: [Enemy] {
        campaign.enemies.filter { $0.alive }
    }

    private var partyLevel: Int {
        let levels = campaign.party.map(\.level)
        guard !levels.isEmpty else { return 1 }
        return levels.reduce(0, +) / levels.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Encounter")
                    .font(.title2.bold())
                    .foregroundStyle(DMTheme.accent)

                Spacer()

                DifficultyBadge(
                    partySize: campaign.party.count,
                    partyLevel: partyLevel,
                    monsterCRs: aliveEnemies.map(\.cr)
                )

                Button {
                    showMonsterPicker = true
                } label: {
                    Label("Add Monster", systemImage: "plus")
                        .font(.subheadline.bold())
                }
                .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentGreen.opacity(0.3)))
                .frame(minHeight: 44)
            }
            .padding(DMTheme.contentPadding)

            Divider().overlay(DMTheme.border)

            // Monster list
            ScrollView {
                LazyVStack(spacing: DMTheme.cardSpacing) {
                    if aliveEnemies.isEmpty {
                        DMEmptyStateView(
                            icon: "shield.slash",
                            title: "No Monsters in Encounter",
                            message: "Tap Add Monster to pull creatures from the SRD Bestiary and begin combat.",
                            buttonTitle: "Add Monster",
                            buttonAction: { showMonsterPicker = true }
                        )
                    } else {
                        ForEach(aliveEnemies) { enemy in
                            MonsterCard(enemy: enemy, onKill: {
                                killMonster(enemy)
                            })
                        }
                    }
                }
                .padding(DMTheme.contentPadding)
            }

            Divider().overlay(DMTheme.border)

            // Initiative list
            InitiativeStripView(campaign: campaign)
        }
        .background(DMTheme.background)
        .sheet(isPresented: $showMonsterPicker) {
            MonsterPickerSheet(campaign: campaign)
                .presentationDetents([.medium, .large])
        }
    }

    private func killMonster(_ enemy: Enemy) {
        withAnimation(.easeInOut(duration: 0.3)) {
            enemy.alive = false
            enemy.hpCurrent = 0
        }
    }
}

// MARK: - Monster Card

struct MonsterCard: View {
    @Bindable var enemy: Enemy
    let onKill: () -> Void
    @State private var showConditions = false
    @State private var damageText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: name, CR, AC
            HStack(spacing: 8) {
                Text(enemy.name)
                    .font(.headline)
                    .foregroundStyle(DMTheme.textPrimary)
                    .lineLimit(1)

                Spacer()

                // CR badge
                Text("CR \(crString)")
                    .font(.caption.bold())
                    .foregroundStyle(DMTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DMTheme.accent.opacity(0.15))
                    .clipShape(Capsule())

                // AC badge
                HStack(spacing: 2) {
                    Image(systemName: "shield.fill")
                        .font(.caption2)
                    Text("\(enemy.armorClass)")
                        .font(.caption.bold().monospacedDigit())
                }
                .foregroundStyle(DMTheme.accentBlue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(DMTheme.accentBlue.opacity(0.15))
                .clipShape(Capsule())
            }

            // HP bar
            HStack(spacing: 8) {
                HPBarView(current: enemy.hpCurrent, max: enemy.hpMax, height: 16)

                Text("\(enemy.hpCurrent)/\(enemy.hpMax)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DMTheme.textSecondary)
                    .frame(width: 60, alignment: .trailing)
            }

            // Action row
            HStack(spacing: 8) {
                // Damage input
                HStack(spacing: 4) {
                    TextField("Dmg", text: $damageText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DMTheme.textPrimary)
                        .frame(width: 50)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(DMTheme.detail)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DMTheme.border, lineWidth: 1)
                        )
                        .keyboardType(.numberPad)

                    Button("Hit") {
                        applyDamage()
                    }
                    .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentRed.opacity(0.3)))
                    .frame(minWidth: 44, minHeight: 44)

                    Button("Heal") {
                        applyHeal()
                    }
                    .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentGreen.opacity(0.3)))
                    .frame(minWidth: 44, minHeight: 44)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showConditions.toggle()
                    }
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.subheadline)
                }
                .buttonStyle(DMSmallButtonStyle())
                .frame(minWidth: 44, minHeight: 44)

                Button {
                    onKill()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(DMTheme.accentRed)
                }
                .buttonStyle(DMSmallButtonStyle())
                .frame(minWidth: 44, minHeight: 44)
            }

            // Conditions
            if showConditions {
                ConditionPickerRow(conditions: Binding(
                    get: { enemy.notes.isEmpty ? [] : enemy.notes.components(separatedBy: ",") },
                    set: { enemy.notes = $0.joined(separator: ",") }
                ))
            }
        }
        .dmCard()
    }

    private var crString: String {
        if enemy.cr < 1 {
            if enemy.cr == 0.125 { return "1/8" }
            if enemy.cr == 0.25 { return "1/4" }
            if enemy.cr == 0.5 { return "1/2" }
            return String(format: "%.0f", enemy.cr)
        }
        return String(format: "%.0f", enemy.cr)
    }

    private func applyDamage() {
        guard let dmg = Int(damageText), dmg > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            enemy.hpCurrent = max(0, enemy.hpCurrent - dmg)
        }
        damageText = ""
        if enemy.hpCurrent <= 0 {
            onKill()
        }
    }

    private func applyHeal() {
        guard let heal = Int(damageText), heal > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            enemy.hpCurrent = min(enemy.hpMax, enemy.hpCurrent + heal)
        }
        damageText = ""
    }
}

// MARK: - Condition Picker Row

struct ConditionPickerRow: View {
    @Binding var conditions: [String]

    private let allConditions = [
        "Blinded", "Charmed", "Deafened", "Frightened", "Grappled",
        "Incapacitated", "Invisible", "Paralyzed", "Petrified",
        "Poisoned", "Prone", "Restrained", "Stunned", "Unconscious"
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(allConditions, id: \.self) { condition in
                    let isActive = conditions.contains(condition)
                    Button(condition) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if isActive {
                                conditions.removeAll { $0 == condition }
                            } else {
                                conditions.append(condition)
                            }
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(isActive ? DMTheme.background : DMTheme.textPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(isActive ? DMTheme.accentRed : DMTheme.detail)
                    .clipShape(Capsule())
                    .frame(minHeight: 32)
                }
            }
        }
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let partySize: Int
    let partyLevel: Int
    let monsterCRs: [Double]

    private var difficulty: (label: String, color: Color) {
        guard !monsterCRs.isEmpty, partySize > 0 else {
            return ("No Encounter", DMTheme.textDim)
        }
        let totalXP = monsterCRs.reduce(0) { $0 + xpForCR($1) }
        let multiplier = encounterMultiplier(monsterCRs.count)
        let adjustedXP = Int(Double(totalXP) * multiplier)
        let thresholds = xpThresholds(level: partyLevel, partySize: partySize)

        if adjustedXP >= thresholds.deadly {
            return ("Deadly", DMTheme.accentRed)
        } else if adjustedXP >= thresholds.hard {
            return ("Hard", Color(hex: "cc7744"))
        } else if adjustedXP >= thresholds.medium {
            return ("Medium", DMTheme.accent)
        } else {
            return ("Easy", DMTheme.accentGreen)
        }
    }

    var body: some View {
        let diff = difficulty
        Text(diff.label)
            .font(.caption.bold())
            .foregroundStyle(diff.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(diff.color.opacity(0.15))
            .clipShape(Capsule())
    }

    private func xpForCR(_ cr: Double) -> Int {
        let table: [Double: Int] = [
            0: 10, 0.125: 25, 0.25: 50, 0.5: 100,
            1: 200, 2: 450, 3: 700, 4: 1100, 5: 1800,
            6: 2300, 7: 2900, 8: 3900, 9: 5000, 10: 5900,
            11: 7200, 12: 8400, 13: 10000, 14: 11500, 15: 13000,
            16: 15000, 17: 18000, 18: 20000, 19: 22000, 20: 25000,
            21: 33000, 22: 41000, 23: 50000, 24: 62000, 25: 75000,
            26: 90000, 27: 105000, 28: 120000, 29: 135000, 30: 155000,
        ]
        return table[cr] ?? 0
    }

    private func encounterMultiplier(_ count: Int) -> Double {
        switch count {
        case 1: return 1.0
        case 2: return 1.5
        case 3...6: return 2.0
        case 7...10: return 2.5
        case 11...14: return 3.0
        default: return 4.0
        }
    }

    private func xpThresholds(level: Int, partySize: Int) -> (easy: Int, medium: Int, hard: Int, deadly: Int) {
        let perPlayer: [(easy: Int, medium: Int, hard: Int, deadly: Int)] = [
            (0, 0, 0, 0),        // level 0 placeholder
            (25, 50, 75, 100),
            (50, 100, 150, 200),
            (75, 150, 225, 400),
            (125, 250, 375, 500),
            (250, 500, 750, 1100),
            (300, 600, 900, 1400),
            (350, 750, 1100, 1700),
            (450, 900, 1400, 2100),
            (550, 1100, 1600, 2400),
            (600, 1200, 1900, 2800),
            (800, 1600, 2400, 3600),
            (1000, 2000, 3000, 4500),
            (1100, 2200, 3400, 5100),
            (1250, 2500, 3800, 5700),
            (1400, 2800, 4300, 6400),
            (1600, 3200, 4800, 7200),
            (2000, 3900, 5900, 8800),
            (2100, 4200, 6300, 9500),
            (2400, 4900, 7300, 10900),
            (2800, 5700, 8500, 12700),
        ]
        let lvl = min(max(level, 1), 20)
        let t = perPlayer[lvl]
        return (t.easy * partySize, t.medium * partySize, t.hard * partySize, t.deadly * partySize)
    }
}

// MARK: - Initiative Strip

struct InitiativeStripView: View {
    let campaign: Campaign
    @State private var initiativeEntries: [InitiativeEntry] = []
    @State private var showAddEntry = false
    @State private var newName = ""
    @State private var newRoll = ""

    struct InitiativeEntry: Identifiable {
        let id = UUID()
        var name: String
        var roll: Int
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("INITIATIVE")
                    .font(.caption2.bold())
                    .foregroundStyle(DMTheme.accent)
                    .tracking(1.5)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAddEntry.toggle()
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.body)
                        .foregroundStyle(DMTheme.accent)
                }
                .frame(minWidth: 44, minHeight: 44)

                if !initiativeEntries.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            initiativeEntries.removeAll()
                        }
                    } label: {
                        Text("Clear")
                            .font(.caption)
                            .foregroundStyle(DMTheme.accentRed)
                    }
                    .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, DMTheme.contentPadding)

            if showAddEntry {
                HStack(spacing: 8) {
                    TextField("Name", text: $newName)
                        .font(.subheadline)
                        .foregroundStyle(DMTheme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(DMTheme.detail)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    TextField("Roll", text: $newRoll)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(DMTheme.textPrimary)
                        .frame(width: 50)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(DMTheme.detail)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .keyboardType(.numberPad)

                    Button("Add") {
                        if let roll = Int(newRoll), !newName.isEmpty {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                initiativeEntries.append(InitiativeEntry(name: newName, roll: roll))
                                initiativeEntries.sort { $0.roll > $1.roll }
                            }
                            newName = ""
                            newRoll = ""
                            showAddEntry = false
                        }
                    }
                    .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentGreen.opacity(0.3)))
                    .frame(minHeight: 44)
                }
                .padding(.horizontal, DMTheme.contentPadding)
            }

            if initiativeEntries.isEmpty {
                Text("No initiative order set")
                    .font(.caption)
                    .foregroundStyle(DMTheme.textDim)
                    .padding(.vertical, 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(initiativeEntries.enumerated()), id: \.element.id) { index, entry in
                            VStack(spacing: 2) {
                                Text(entry.name)
                                    .font(.caption)
                                    .foregroundStyle(index == 0 ? DMTheme.accent : DMTheme.textPrimary)
                                    .lineLimit(1)
                                Text("\(entry.roll)")
                                    .font(.caption2.monospacedDigit().bold())
                                    .foregroundStyle(DMTheme.textSecondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(index == 0 ? DMTheme.accent.opacity(0.15) : DMTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(index == 0 ? DMTheme.accent : DMTheme.border, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, DMTheme.contentPadding)
                }
            }
        }
        .padding(.vertical, 10)
        .background(DMTheme.card)
    }
}

// MARK: - Monster Picker Sheet

struct MonsterPickerSheet: View {
    @Bindable var campaign: Campaign
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var allMonsters: [SRDMonster] = []
    @State private var showFullSRD = false

    /// Monsters bookmarked in the campaign's roster
    private var rosterMonsters: [SRDMonster] {
        let rosterIDs = Set(campaign.monsterRoster)
        let roster = allMonsters.filter { rosterIDs.contains($0.srdID) }
        if searchText.isEmpty { return roster }
        return roster.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// All SRD monsters (filtered by search)
    private var srdMonsters: [SRDMonster] {
        if searchText.isEmpty { return allMonsters }
        return allMonsters.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search
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
                .padding(DMTheme.contentPadding)

                List {
                    // Campaign Roster section
                    if !rosterMonsters.isEmpty {
                        Section {
                            ForEach(rosterMonsters) { monster in
                                Button { addMonster(monster) } label: {
                                    monsterRow(monster, isRoster: true)
                                }
                                .listRowBackground(DMTheme.card)
                            }
                        } header: {
                            Label("Campaign Roster", systemImage: "star.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(DMTheme.accent)
                        }
                    } else if !campaign.monsterRoster.isEmpty {
                        // Roster exists but search filtered everything out
                        Section {
                            Text("No roster matches")
                                .font(.caption)
                                .foregroundStyle(DMTheme.textDim)
                                .listRowBackground(DMTheme.card)
                        } header: {
                            Label("Campaign Roster", systemImage: "star.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(DMTheme.accent)
                        }
                    }

                    // Full SRD section
                    Section {
                        if showFullSRD || campaign.monsterRoster.isEmpty {
                            ForEach(srdMonsters) { monster in
                                Button { addMonster(monster) } label: {
                                    monsterRow(monster, isRoster: false)
                                }
                                .listRowBackground(DMTheme.card)
                            }
                        } else {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showFullSRD = true
                                }
                            } label: {
                                Label("Browse Full SRD (\(allMonsters.count) monsters)", systemImage: "book.pages")
                                    .font(.subheadline)
                                    .foregroundStyle(DMTheme.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(minHeight: 44)
                            }
                            .listRowBackground(DMTheme.card)
                        }
                    } header: {
                        Label("SRD Bestiary", systemImage: "book.closed")
                            .font(.subheadline.bold())
                            .foregroundStyle(DMTheme.textSecondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .background(DMTheme.background)
            .navigationTitle("Add Monster")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear { loadMonsters() }
    }

    private func monsterRow(_ monster: SRDMonster, isRoster: Bool) -> some View {
        HStack {
            if isRoster {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(DMTheme.accent.opacity(0.6))
            }
            Text(monster.name)
                .foregroundStyle(DMTheme.textPrimary)
            Spacer()
            Text("CR \(monster.crString)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(DMTheme.accent)
            Text("AC \(monster.armorClass)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(DMTheme.accentBlue)
            Text("HP \(monster.hitPoints)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(DMTheme.accentGreen)
        }
    }

    private func addMonster(_ monster: SRDMonster) {
        let enemy = Enemy(name: monster.name, cr: monster.challengeRating)
        enemy.hpMax = monster.hitPoints
        enemy.hpCurrent = monster.hitPoints
        enemy.armorClass = monster.armorClass
        enemy.srdID = monster.srdID
        enemy.campaign = campaign
        campaign.enemies.append(enemy)
        dismiss()
    }

    private func loadMonsters() {
        guard let url = Bundle.main.url(forResource: "monsters", withExtension: "json", subdirectory: "SRD") else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        guard let wrapper = try? JSONDecoder().decode(SRDMonsterFile.self, from: data) else { return }
        allMonsters = wrapper.monsters
    }
}

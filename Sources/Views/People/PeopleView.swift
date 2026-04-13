import SwiftUI
import SwiftData

// MARK: - PeopleView

struct PeopleView: View {
    let campaign: Campaign
    @Environment(\.modelContext) private var modelContext

    @State private var showQuickAdd = false
    @State private var collapsedSections: Set<String> = ["fallen"]

    // Damage/Heal sheet state
    @State private var damageHealTarget: PlayerCharacter?
    @State private var damageHealAmount: String = ""
    @State private var isDamageMode = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerBar

            ScrollView {
                VStack(spacing: DMTheme.sectionSpacing) {
                    // Active Party
                    VStack(spacing: DMTheme.cardSpacing) {
                        sectionHeader(key: "party", title: "Active Party", count: campaign.party.count, color: DMTheme.accent)
                        if !collapsedSections.contains("party") {
                            if campaign.party.isEmpty {
                                DMEmptyStateView(
                                    icon: "person.3",
                                    title: "No Party Members",
                                    message: "Tap + New PC to create your first character and begin your adventure.",
                                    buttonTitle: "New PC",
                                    buttonAction: {
                                        let pc = PlayerCharacter(name: "New Hero", race: "Human", characterClass: "Fighter")
                                        pc.campaign = campaign
                                        modelContext.insert(pc)
                                    }
                                )
                                .frame(height: 240)
                            } else {
                                ForEach(campaign.party.sorted(by: { $0.name < $1.name })) { pc in
                                    pcCard(pc)
                                }
                            }
                        }
                    }

                    // NPCs
                    VStack(spacing: DMTheme.cardSpacing) {
                        sectionHeader(key: "npcs", title: "NPCs", count: campaign.npcs.count, color: DMTheme.accentBlue)
                        if !collapsedSections.contains("npcs") {
                            if campaign.npcs.isEmpty {
                                DMEmptyStateView(
                                    icon: "person.text.rectangle",
                                    title: "No NPCs",
                                    message: "Add shopkeepers, quest givers, and allies your party will meet along the way.",
                                    buttonTitle: "Quick Add",
                                    buttonAction: { showQuickAdd = true }
                                )
                                .frame(height: 220)
                            } else {
                                ForEach(campaign.npcs.sorted(by: { $0.name < $1.name })) { npc in
                                    npcCard(npc)
                                }
                            }
                        }
                    }

                    // Enemies
                    VStack(spacing: DMTheme.cardSpacing) {
                        sectionHeader(key: "enemies", title: "Enemies", count: campaign.enemies.count, color: DMTheme.accentRed)
                        if !collapsedSections.contains("enemies") {
                            if campaign.enemies.isEmpty {
                                DMEmptyStateView(
                                    icon: "bolt.shield",
                                    title: "No Tracked Enemies",
                                    message: "Enemies added from the Bestiary or encounters will appear here."
                                )
                                .frame(height: 180)
                            } else {
                                ForEach(campaign.enemies.sorted(by: { $0.name < $1.name })) { enemy in
                                    enemyCard(enemy)
                                }
                            }
                        }
                    }

                    // Fallen Heroes
                    if !campaign.fallen.isEmpty {
                        VStack(spacing: DMTheme.cardSpacing) {
                            sectionHeader(key: "fallen", title: "Fallen Heroes", count: campaign.fallen.count, color: DMTheme.textDim)
                            if !collapsedSections.contains("fallen") {
                                ForEach(campaign.fallen.sorted(by: { $0.diedDate < $1.diedDate })) { hero in
                                    fallenCard(hero)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DMTheme.contentPadding)
                .padding(.bottom, 20)
            }
        }
        .background(DMTheme.background)
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(campaign: campaign)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $damageHealTarget) { pc in
            DamageHealSheet(pc: pc, isDamage: isDamageMode)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 8) {
            Text("People")
                .font(.title2.bold())
                .foregroundStyle(DMTheme.accent)

            Spacer()

            Button {
                let pc = PlayerCharacter(name: "New Hero", race: "Human", characterClass: "Fighter")
                pc.campaign = campaign
                modelContext.insert(pc)
            } label: {
                Label("New PC", systemImage: "plus")
                    .font(.subheadline.bold())
            }
            .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentGreen.opacity(0.3)))
            .frame(minHeight: 44)

            Button {
                showQuickAdd = true
            } label: {
                Label("Quick Add", systemImage: "plus")
                    .font(.subheadline)
            }
            .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentBlue.opacity(0.2)))
            .frame(minHeight: 44)
        }
        .padding(DMTheme.contentPadding)
    }

    // MARK: - Section Headers

    private func sectionHeader(key: String, title: String, count: Int, color: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if collapsedSections.contains(key) {
                    collapsedSections.remove(key)
                } else {
                    collapsedSections.insert(key)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: collapsedSections.contains(key) ? "chevron.right" : "chevron.down")
                    .font(.caption.bold())
                    .frame(width: 16)
                Text(title)
                    .font(.headline)
                Text("\(count)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(color.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(DMTheme.detail)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - PC Card

    private func pcCard(_ pc: PlayerCharacter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Name + Class/Level
            HStack {
                Text(pc.name)
                    .font(.headline)
                    .foregroundStyle(DMTheme.textPrimary)
                Spacer()
                Text("\(pc.characterClass) \(pc.level)")
                    .font(.subheadline)
                    .foregroundStyle(DMTheme.textSecondary)
            }

            // HP Bar
            HStack(spacing: 8) {
                HPBarView(current: pc.hpCurrent, max: pc.hpMax)
                    .frame(height: 22)

                Text("\(pc.hpCurrent)/\(pc.hpMax)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DMTheme.textSecondary)
                    .frame(width: 60, alignment: .trailing)
            }

            // Stats row: AC, Speed, Mana pips
            HStack(spacing: DMTheme.contentPadding) {
                statBadge(icon: "shield.fill", value: "\(pc.armorClass)", label: "AC")
                statBadge(icon: "figure.walk", value: "\(pc.speed)ft", label: "SPD")

                // Mana pips (spell slots)
                if !pc.spellSlotsMax.isEmpty {
                    let totalSlots = pc.spellSlotsMax.values.reduce(0, +)
                    let usedSlots = pc.spellSlots.values.reduce(0, +)
                    manaPips(current: usedSlots, max: totalSlots)
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 8) {
                Button("Damage") {
                    isDamageMode = true
                    damageHealTarget = pc
                }
                .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentRed.opacity(0.3)))
                .frame(minHeight: 44)

                Button("Heal") {
                    isDamageMode = false
                    damageHealTarget = pc
                }
                .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentGreen.opacity(0.3)))
                .frame(minHeight: 44)

                Spacer()
            }
        }
        .dmCard()
    }

    // MARK: - NPC Card

    private func npcCard(_ npc: NPC) -> some View {
        HStack(spacing: 0) {
            // Blue left border
            Rectangle()
                .fill(DMTheme.accentBlue)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(npc.name)
                        .font(.headline)
                        .foregroundStyle(DMTheme.textPrimary)
                    if !npc.role.isEmpty {
                        Text(npc.role)
                            .font(.caption)
                            .foregroundStyle(DMTheme.accentBlue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(DMTheme.accentBlue.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer()
                }

                if !npc.notes.isEmpty {
                    Text(String(npc.notes.prefix(100)))
                        .font(.subheadline)
                        .foregroundStyle(DMTheme.textDim)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Button("Remove") {
                        modelContext.delete(npc)
                    }
                    .buttonStyle(DMDestructiveButtonStyle())
                }
            }
            .padding(DMTheme.cardPadding)
        }
        .background(DMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius)
                .stroke(DMTheme.border, lineWidth: 1)
        )
        .shadow(color: DMTheme.cardShadow, radius: 4, y: 2)
    }

    // MARK: - Enemy Card

    private func enemyCard(_ enemy: Enemy) -> some View {
        HStack(spacing: 0) {
            // Red left border
            Rectangle()
                .fill(DMTheme.accentRed)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(enemy.name)
                        .font(.headline)
                        .foregroundStyle(DMTheme.textPrimary)
                    Spacer()
                    crBadge(enemy.cr)
                }

                HStack(spacing: DMTheme.cardSpacing) {
                    if enemy.hpMax > 0 {
                        Label("\(enemy.hpCurrent)/\(enemy.hpMax) HP", systemImage: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(DMTheme.accentRed)
                    }
                    if enemy.armorClass > 0 {
                        Label("AC \(enemy.armorClass)", systemImage: "shield.fill")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textSecondary)
                    }
                }

                HStack(spacing: 8) {
                    Button("To Encounter") {
                        addEnemyToEncounter(enemy)
                    }
                        .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentRed.opacity(0.2)))
                        .frame(minHeight: 44)

                    Button("Remove") {
                        modelContext.delete(enemy)
                    }
                    .buttonStyle(DMDestructiveButtonStyle())
                }
            }
            .padding(DMTheme.cardPadding)
        }
        .background(DMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius)
                .stroke(DMTheme.border, lineWidth: 1)
        )
        .shadow(color: DMTheme.cardShadow, radius: 4, y: 2)
    }

    // MARK: - Fallen Card

    private func fallenCard(_ hero: FallenHero) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\u{271D} \(hero.name)")
                .font(.headline)
                .foregroundStyle(DMTheme.textDim)

            Text("\(hero.characterClass) \(hero.level)")
                .font(.subheadline)
                .foregroundStyle(DMTheme.textDim.opacity(0.7))

            HStack {
                Text(hero.diedCause)
                    .font(.caption)
                    .foregroundStyle(DMTheme.textDim.opacity(0.6))
                if !hero.diedSession.isEmpty {
                    Text("- \(hero.diedSession)")
                        .font(.caption)
                        .foregroundStyle(DMTheme.textDim.opacity(0.5))
                }
            }
        }
        .padding(DMTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DMTheme.card.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius)
                .stroke(DMTheme.border.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func statBadge(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(DMTheme.textDim)
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(DMTheme.textPrimary)
        }
    }

    private func manaPips(current: Int, max: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<Swift.min(max, 10), id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i < current ? DMTheme.manaFull : DMTheme.manaEmpty)
                    .frame(width: 10, height: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(DMTheme.manaBorder, lineWidth: 1)
                    )
                    .shadow(color: i < current ? DMTheme.manaFull.opacity(0.4) : .clear, radius: 3)
            }
            if max > 10 {
                Text("+\(max - 10)")
                    .font(.caption2)
                    .foregroundStyle(DMTheme.manaFull)
            }
        }
    }

    /// Clone this enemy into the active encounter as a fresh combatant
    private func addEnemyToEncounter(_ enemy: Enemy) {
        let clone = Enemy(name: enemy.name, cr: enemy.cr)
        clone.hpMax = enemy.hpMax
        clone.hpCurrent = enemy.hpMax  // full health for encounter
        clone.armorClass = enemy.armorClass
        clone.srdID = enemy.srdID
        clone.campaign = campaign
        campaign.enemies.append(clone)
    }

    private func crBadge(_ cr: Double) -> some View {
        let crText = cr < 1 ? (cr == 0.5 ? "1/2" : cr == 0.25 ? "1/4" : cr == 0.125 ? "1/8" : "\(cr)") : "\(Int(cr))"
        return Text("CR \(crText)")
            .font(.caption.bold())
            .foregroundStyle(DMTheme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(DMTheme.accent.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Quick Add Sheet

struct QuickAddSheet: View {
    let campaign: Campaign
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var entityType = "NPC"
    @State private var role = ""
    @State private var cr = ""
    @State private var hp = ""
    @State private var ac = ""

    private let types = ["NPC", "Enemy"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $entityType) {
                        ForEach(types, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Role", text: $role)
                }

                if entityType == "Enemy" {
                    Section("Combat Stats (optional)") {
                        TextField("Challenge Rating", text: $cr)
                            .keyboardType(.decimalPad)
                        TextField("Hit Points", text: $hp)
                            .keyboardType(.numberPad)
                        TextField("Armor Class", text: $ac)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DMTheme.background)
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addEntity()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func addEntity() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if entityType == "NPC" {
            let npc = NPC(name: trimmed, role: role)
            npc.campaign = campaign
            modelContext.insert(npc)
        } else {
            let enemy = Enemy(name: trimmed, cr: Double(cr) ?? 0)
            enemy.role = role
            enemy.hpMax = Int(hp) ?? 0
            enemy.hpCurrent = enemy.hpMax
            enemy.armorClass = Int(ac) ?? 0
            enemy.campaign = campaign
            modelContext.insert(enemy)
        }
    }
}

// MARK: - Damage/Heal Sheet

struct DamageHealSheet: View {
    @Bindable var pc: PlayerCharacter
    let isDamage: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var amount: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(pc.name)
                    .font(.title2.bold())
                    .foregroundStyle(DMTheme.textPrimary)

                HPBarView(current: pc.hpCurrent, max: pc.hpMax)
                    .frame(height: 28)
                    .padding(.horizontal)

                Text("\(pc.hpCurrent) / \(pc.hpMax) HP")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(DMTheme.textSecondary)

                TextField("Amount", text: $amount)
                    .keyboardType(.numberPad)
                    .font(.title)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(DMTheme.detail)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DMTheme.border, lineWidth: 1)
                    )
                    .padding(.horizontal)

                Button(isDamage ? "Apply Damage" : "Apply Healing") {
                    if let val = Int(amount), val > 0 {
                        if isDamage {
                            pc.hpCurrent = Swift.max(0, pc.hpCurrent - val)
                        } else {
                            pc.hpCurrent = Swift.min(pc.hpMax, pc.hpCurrent + val)
                        }
                        dismiss()
                    }
                }
                .buttonStyle(DMButtonStyle(color: isDamage ? DMTheme.accentRed : DMTheme.accentGreen))

                Spacer()
            }
            .padding(.top, 24)
            .background(DMTheme.background)
            .navigationTitle(isDamage ? "Damage" : "Heal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

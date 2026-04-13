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
                VStack(spacing: 4) {
                    // Active Party
                    sectionHeader(key: "party", title: "Active Party", count: campaign.party.count, color: DMTheme.accent)
                    if !collapsedSections.contains("party") {
                        if campaign.party.isEmpty {
                            emptyLabel("No party members yet. Tap '+ New PC' to create one.")
                        } else {
                            ForEach(campaign.party.sorted(by: { $0.name < $1.name })) { pc in
                                pcCard(pc)
                            }
                        }
                    }

                    // NPCs
                    sectionHeader(key: "npcs", title: "NPCs", count: campaign.npcs.count, color: DMTheme.accentBlue)
                    if !collapsedSections.contains("npcs") {
                        if campaign.npcs.isEmpty {
                            emptyLabel("No NPCs yet. Tap '+ Quick Add' to create one.")
                        } else {
                            ForEach(campaign.npcs.sorted(by: { $0.name < $1.name })) { npc in
                                npcCard(npc)
                            }
                        }
                    }

                    // Enemies
                    sectionHeader(key: "enemies", title: "Enemies", count: campaign.enemies.count, color: DMTheme.accentRed)
                    if !collapsedSections.contains("enemies") {
                        if campaign.enemies.isEmpty {
                            emptyLabel("No tracked enemies.")
                        } else {
                            ForEach(campaign.enemies.sorted(by: { $0.name < $1.name })) { enemy in
                                enemyCard(enemy)
                            }
                        }
                    }

                    // Fallen Heroes
                    if !campaign.fallen.isEmpty {
                        sectionHeader(key: "fallen", title: "Fallen Heroes", count: campaign.fallen.count, color: DMTheme.textDim)
                        if !collapsedSections.contains("fallen") {
                            ForEach(campaign.fallen.sorted(by: { $0.diedDate < $1.diedDate })) { hero in
                                fallenCard(hero)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .background(DMTheme.background)
        .sheet(isPresented: $showQuickAdd) {
            QuickAddSheet(campaign: campaign)
        }
        .sheet(item: $damageHealTarget) { pc in
            DamageHealSheet(pc: pc, isDamage: isDamageMode)
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
                Text("+ New PC")
                    .font(.subheadline)
                    .foregroundStyle(DMTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "1a4a2a"))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Button {
                showQuickAdd = true
            } label: {
                Text("+ Quick Add")
                    .font(.subheadline)
                    .foregroundStyle(DMTheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "2a2a5a"))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding()
    }

    // MARK: - Section Headers

    private func sectionHeader(key: String, title: String, count: Int, color: Color) -> some View {
        Button {
            if collapsedSections.contains(key) {
                collapsedSections.remove(key)
            } else {
                collapsedSections.insert(key)
            }
        } label: {
            HStack {
                Image(systemName: collapsedSections.contains(key) ? "chevron.right" : "chevron.down")
                    .font(.caption)
                Text("\(title) (\(count))")
                    .font(.subheadline.bold())
                Spacer()
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(DMTheme.detail)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - PC Card

    private func pcCard(_ pc: PlayerCharacter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
            HStack(spacing: 16) {
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
            HStack(spacing: 6) {
                Button("Damage") {
                    isDamageMode = true
                    damageHealTarget = pc
                }
                .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentRed.opacity(0.3)))

                Button("Heal") {
                    isDamageMode = false
                    damageHealTarget = pc
                }
                .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentGreen.opacity(0.3)))

                Spacer()
            }
        }
        .padding(12)
        .background(DMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - NPC Card

    private func npcCard(_ npc: NPC) -> some View {
        HStack(spacing: 0) {
            // Blue left border
            Rectangle()
                .fill(DMTheme.accentBlue)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(npc.name)
                        .font(.headline)
                        .foregroundStyle(DMTheme.textPrimary)
                    if !npc.role.isEmpty {
                        Text(npc.role)
                            .font(.caption)
                            .foregroundStyle(DMTheme.accentBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DMTheme.accentBlue.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer()
                }

                if !npc.notes.isEmpty {
                    Text(String(npc.notes.prefix(100)))
                        .font(.caption)
                        .foregroundStyle(DMTheme.textDim)
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Button("Remove") {
                        modelContext.delete(npc)
                    }
                    .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentRed.opacity(0.2)))
                }
            }
            .padding(12)
        }
        .background(DMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Enemy Card

    private func enemyCard(_ enemy: Enemy) -> some View {
        HStack(spacing: 0) {
            // Red left border
            Rectangle()
                .fill(DMTheme.accentRed)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(enemy.name)
                        .font(.headline)
                        .foregroundStyle(DMTheme.textPrimary)
                    Spacer()
                    crBadge(enemy.cr)
                }

                HStack(spacing: 12) {
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

                HStack(spacing: 6) {
                    Button("To Encounter") { }
                        .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentRed.opacity(0.2)))

                    Button("Remove") {
                        modelContext.delete(enemy)
                    }
                    .buttonStyle(DMSmallButtonStyle(color: Color(hex: "4a2020")))
                }
            }
            .padding(12)
        }
        .background(DMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Fallen Card

    private func fallenCard(_ hero: FallenHero) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DMTheme.card.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func statBadge(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(DMTheme.textDim)
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(DMTheme.textPrimary)
        }
    }

    private func manaPips(current: Int, max: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<Swift.min(max, 10), id: \.self) { i in
                Circle()
                    .fill(i < current ? DMTheme.manaFull : DMTheme.manaEmpty)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(DMTheme.manaBorder, lineWidth: 1)
                    )
            }
            if max > 10 {
                Text("+\(max - 10)")
                    .font(.caption2)
                    .foregroundStyle(DMTheme.manaFull)
            }
        }
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

    private func emptyLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(DMTheme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
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

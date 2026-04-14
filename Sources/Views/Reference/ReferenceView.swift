import SwiftUI

// MARK: - Reference View

struct ReferenceView: View {
    @State private var selectedTab: RefTab = .bestiary
    @State private var searchText = ""

    enum RefTab: String, CaseIterable {
        case bestiary = "Bestiary"
        case spells = "Spells"
        case items = "Items"
        case conditions = "Conditions"

        var icon: String {
            switch self {
            case .bestiary: return "pawprint.fill"
            case .spells: return "sparkles"
            case .items: return "shield.fill"
            case .conditions: return "exclamationmark.triangle"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SRD Reference")
                    .font(.title2.bold())
                    .foregroundStyle(DMTheme.accent)
                Spacer()
            }
            .padding()

            // Tab picker
            Picker("Category", selection: $selectedTab) {
                ForEach(RefTab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(DMTheme.textDim)
                TextField("Search \(selectedTab.rawValue.lowercased())...", text: $searchText)
                    .foregroundStyle(DMTheme.textPrimary)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(DMTheme.textDim)
                    }
                }
            }
            .padding(10)
            .background(DMTheme.detail)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding()

            Divider().overlay(DMTheme.border)

            // Content
            Group {
                switch selectedTab {
                case .bestiary:
                    RefBestiaryListView(searchText: searchText)
                case .spells:
                    SpellListView(searchText: searchText)
                case .items:
                    RefItemListView(searchText: searchText)
                case .conditions:
                    ConditionListView(searchText: searchText)
                }
            }

            // Attribution
            Text("Contains content from the SRD 5.1, (c) Wizards of the Coast, licensed under CC-BY-4.0.")
                .font(.caption2)
                .foregroundStyle(DMTheme.textDim)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .background(DMTheme.background)
    }
}

// MARK: - Reference Bestiary List (quick lookup with full stat block)

struct RefBestiaryListView: View {
    let searchText: String
    @State private var monsters: [SRDMonster] = []
    @State private var selectedMonster: SRDMonster?

    private var filtered: [SRDMonster] {
        if searchText.isEmpty { return monsters }
        return monsters.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(filtered) { monster in
            Button {
                selectedMonster = monster
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(monster.name)
                            .font(.subheadline)
                            .foregroundStyle(DMTheme.textPrimary)
                        Text("\(monster.size) \(monster.type)")
                            .font(.caption2)
                            .foregroundStyle(DMTheme.textDim)
                    }
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
            .listRowBackground(DMTheme.card)
            .listRowSeparatorTint(DMTheme.border)
        }
        .scrollContentBackground(.hidden)
        .onAppear { loadMonsters() }
        .sheet(item: $selectedMonster) { monster in
            RefMonsterDetailSheet(monster: monster)
        }
    }

    private func loadMonsters() {
        guard monsters.isEmpty else { return }
        let url = Bundle.main.bundleURL.appendingPathComponent("SRD/monsters.json")
        guard
              let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(SRDMonsterFile.self, from: data)
        else { return }
        monsters = wrapper.monsters
    }
}

// MARK: - Reference Monster Detail Sheet (full stat block, read-only)

struct RefMonsterDetailSheet: View {
    let monster: SRDMonster
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
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
                    HStack(spacing: 12) {
                        refStatBlock("AC", value: "\(monster.armorClass)")
                        refStatBlock("HP", value: "\(monster.hitPoints)")
                        refStatBlock("Hit Dice", value: monster.hitDice)
                    }

                    // Speed
                    let speedText = monster.speed.map { "\($0.key) \($0.value) ft." }.joined(separator: ", ")
                    if !speedText.isEmpty {
                        refDetailRow("Speed", value: speedText)
                    }

                    Divider().background(DMTheme.border)

                    // Ability Scores Grid
                    refAbilityScoreGrid(monster)

                    Divider().background(DMTheme.border)

                    // Skills
                    if !monster.skills.isEmpty {
                        let skillText = monster.skills.map { "\($0.key.capitalized) +\($0.value)" }.joined(separator: ", ")
                        refDetailRow("Skills", value: skillText)
                    }

                    // Senses
                    if !monster.senses.isEmpty {
                        let senseText = monster.senses.map { "\($0.key.replacingOccurrences(of: "_", with: " ").capitalized) \($0.value.displayString)" }.joined(separator: ", ")
                        refDetailRow("Senses", value: senseText)
                    }

                    // Languages
                    if !monster.languages.isEmpty {
                        refDetailRow("Languages", value: monster.languages.joined(separator: ", "))
                    }

                    // Damage Immunities
                    if !monster.damageImmunities.isEmpty {
                        refDetailRow("Damage Immunities", value: monster.damageImmunities.joined(separator: ", "))
                    }

                    // Damage Resistances
                    if !monster.damageResistances.isEmpty {
                        refDetailRow("Damage Resistances", value: monster.damageResistances.joined(separator: ", "))
                    }

                    // Damage Vulnerabilities
                    if !monster.damageVulnerabilities.isEmpty {
                        refDetailRow("Damage Vulnerabilities", value: monster.damageVulnerabilities.joined(separator: ", "))
                    }

                    // Condition Immunities
                    if !monster.conditionImmunities.isEmpty {
                        refDetailRow("Condition Immunities", value: monster.conditionImmunities.joined(separator: ", "))
                    }

                    // Special Abilities
                    if !monster.specialAbilities.isEmpty {
                        Divider().background(DMTheme.border)
                        Text("Special Abilities")
                            .font(.headline)
                            .foregroundStyle(DMTheme.accent)
                        ForEach(monster.specialAbilities) { ability in
                            refAbilityBlock(name: ability.name, desc: ability.description)
                        }
                    }

                    // Actions
                    if !monster.actions.isEmpty {
                        Divider().background(DMTheme.border)
                        Text("Actions")
                            .font(.headline)
                            .foregroundStyle(DMTheme.accent)
                        ForEach(monster.actions) { action in
                            refActionBlock(action)
                        }
                    }

                    // Legendary Actions
                    if !monster.legendaryActions.isEmpty {
                        Divider().background(DMTheme.border)
                        Text("Legendary Actions")
                            .font(.headline)
                            .foregroundStyle(DMTheme.accent)
                        ForEach(monster.legendaryActions) { action in
                            refAbilityBlock(name: action.name, desc: action.description)
                        }
                    }
                }
                .padding()
            }
            .background(DMTheme.background)
            .navigationTitle(monster.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func refStatBlock(_ label: String, value: String) -> some View {
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

    private func refAbilityScoreGrid(_ monster: SRDMonster) -> some View {
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

    private func refDetailRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(DMTheme.accent)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(DMTheme.textPrimary)
        }
    }

    private func refAbilityBlock(name: String, desc: String) -> some View {
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

    private func refActionBlock(_ action: SRDMonster.MonsterAction) -> some View {
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
                    if let dmg = action.damage, let dmgType = action.damageType {
                        parts.append("\(dmg) \(dmgType)")
                    }
                }()
                if !parts.isEmpty {
                    Text(parts.joined(separator: " | "))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DMTheme.accentRed)
                }
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

// MARK: - Spell List

struct SpellListView: View {
    let searchText: String
    @State private var spells: [SRDSpell] = []
    @State private var selectedSpell: SRDSpell?

    private var filtered: [SRDSpell] {
        if searchText.isEmpty { return spells }
        return spells.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(filtered) { spell in
            Button {
                selectedSpell = spell
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(spell.name)
                            .font(.subheadline)
                            .foregroundStyle(DMTheme.textPrimary)
                        Text(spell.classes.joined(separator: ", ").capitalized)
                            .font(.caption2)
                            .foregroundStyle(DMTheme.textDim)
                    }
                    Spacer()
                    Text(spell.levelString)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DMTheme.accent)
                    Text(spell.school.capitalized)
                        .font(.caption)
                        .foregroundStyle(DMTheme.accentBlue)
                }
            }
            .listRowBackground(DMTheme.card)
            .listRowSeparatorTint(DMTheme.border)
        }
        .scrollContentBackground(.hidden)
        .onAppear { loadSpells() }
        .sheet(item: $selectedSpell) { spell in
            SpellDetailSheet(spell: spell)
        }
    }

    private func loadSpells() {
        let url = Bundle.main.bundleURL.appendingPathComponent("SRD/spells.json")
        guard
              let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(SRDSpellWrapper.self, from: data)
        else { return }
        spells = wrapper.spells
    }
}

// MARK: - Spell Detail Sheet

struct SpellDetailSheet: View {
    let spell: SRDSpell
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Level + School
                    HStack {
                        Text(spell.levelString)
                            .font(.headline)
                            .foregroundStyle(DMTheme.accent)
                        Text(spell.school.capitalized)
                            .font(.headline)
                            .foregroundStyle(DMTheme.accentBlue)
                        if spell.ritual {
                            Text("(ritual)")
                                .font(.subheadline)
                                .foregroundStyle(DMTheme.textSecondary)
                        }
                    }

                    Divider().overlay(DMTheme.border)

                    // Stats grid
                    SpellStatRow(label: "Casting Time", value: spell.castingTime)
                    SpellStatRow(label: "Range", value: spell.rangeString)
                    SpellStatRow(label: "Components", value: spell.components.joined(separator: ", "))
                    SpellStatRow(label: "Duration", value: spell.duration)
                    if spell.concentration {
                        SpellStatRow(label: "Concentration", value: "Yes")
                    }
                    SpellStatRow(label: "Classes", value: spell.classes.map { $0.capitalized }.joined(separator: ", "))

                    Divider().overlay(DMTheme.border)

                    // Description
                    Text(spell.description)
                        .font(.body)
                        .foregroundStyle(DMTheme.textPrimary)

                    if let higher = spell.atHigherLevels, !higher.isEmpty {
                        Text("At Higher Levels")
                            .font(.subheadline.bold())
                            .foregroundStyle(DMTheme.accent)
                        Text(higher)
                            .font(.body)
                            .foregroundStyle(DMTheme.textPrimary)
                    }
                }
                .padding()
            }
            .background(DMTheme.background)
            .navigationTitle(spell.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct SpellStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline.bold())
                .foregroundStyle(DMTheme.textSecondary)
                .frame(width: 120, alignment: .trailing)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(DMTheme.textPrimary)
        }
    }
}

// MARK: - Item List (weapons, armor, adventuring gear, magic items)

struct RefItemListView: View {
    let searchText: String
    @State private var allItems: [RefDisplayItem] = []
    @State private var selectedCategory: String = "All"
    @State private var selectedItem: RefDisplayItem?

    private let categories = ["All", "Weapons", "Armor", "Adventuring Gear", "Magic Items"]

    private var filtered: [RefDisplayItem] {
        var result = allItems
        if selectedCategory != "All" {
            result = result.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCategory = cat
                            }
                        } label: {
                            Text(cat)
                                .font(.caption)
                                .foregroundStyle(selectedCategory == cat ? DMTheme.background : DMTheme.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedCategory == cat ? DMTheme.accent : DMTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                        .frame(minHeight: 32)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }

            Divider().overlay(DMTheme.border)

            List(filtered) { item in
                Button {
                    selectedItem = item
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline)
                                .foregroundStyle(DMTheme.textPrimary)
                            Text(item.subtitle)
                                .font(.caption2)
                                .foregroundStyle(DMTheme.textDim)
                        }
                        Spacer()
                        if let badge = item.badge {
                            Text(badge)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(DMTheme.accentRed)
                        }
                        Text(item.costOrRarity)
                            .font(.caption)
                            .foregroundStyle(DMTheme.accent)
                    }
                }
                .listRowBackground(DMTheme.card)
                .listRowSeparatorTint(DMTheme.border)
            }
            .scrollContentBackground(.hidden)
        }
        .onAppear { loadAllItems() }
        .sheet(item: $selectedItem) { item in
            RefItemDetailSheet(item: item)
        }
    }

    private func loadAllItems() {
        guard allItems.isEmpty else { return }
        var items: [RefDisplayItem] = []

        // Weapons
        let url = Bundle.main.bundleURL.appendingPathComponent("SRD/items.json")
        if
           let data = try? Data(contentsOf: url) {
            if let wrapper = try? JSONDecoder().decode(SRDFullItemFile.self, from: data) {
                // Weapons
                for w in wrapper.weapons {
                    let props = w.properties.joined(separator: ", ")
                    var details = ["\(w.damage ?? "") \(w.damageType ?? "")".trimmingCharacters(in: .whitespaces)]
                    if !props.isEmpty { details.append(props) }
                    if let wt = w.weight { details.append("\(wt.cleanWeight) lb.") }

                    items.append(RefDisplayItem(
                        id: w.srdID,
                        name: w.name,
                        category: "Weapons",
                        subtitle: w.category.replacingOccurrences(of: "_", with: " ").capitalized,
                        costOrRarity: w.cost,
                        badge: w.damage,
                        description: details.filter { !$0.isEmpty }.joined(separator: "\n")
                    ))
                }

                // Armor
                for a in wrapper.armor {
                    var acText: String
                    if let bonus = a.acBonus {
                        acText = "+\(bonus) AC"
                    } else {
                        acText = "AC \(a.baseAC ?? 0)"
                        if a.dexBonus == true {
                            if let maxDex = a.maxDexBonus {
                                acText += " + Dex (max \(maxDex))"
                            } else {
                                acText += " + Dex"
                            }
                        }
                    }
                    var desc = acText
                    if a.stealthDisadvantage == true { desc += "\nStealth: Disadvantage" }
                    if let str = a.strengthRequirement { desc += "\nStr required: \(str)" }

                    items.append(RefDisplayItem(
                        id: a.srdID,
                        name: a.name,
                        category: "Armor",
                        subtitle: "\(a.type.capitalized) armor",
                        costOrRarity: a.cost,
                        badge: acText,
                        description: desc
                    ))
                }

                // Adventuring Gear
                for g in wrapper.adventuringGear {
                    items.append(RefDisplayItem(
                        id: g.srdID,
                        name: g.name,
                        category: "Adventuring Gear",
                        subtitle: "\(g.weight.cleanWeight) lb.",
                        costOrRarity: g.cost,
                        badge: nil,
                        description: g.description ?? ""
                    ))
                }
            }
        }

        // Magic Items
        let magicURL = Bundle.main.bundleURL.appendingPathComponent("SRD/magic_items.json")
        if
           let data = try? Data(contentsOf: magicURL),
           let wrapper = try? JSONDecoder().decode(SRDMagicItemFile.self, from: data) {
            for m in wrapper.magicItems {
                var subtitle = m.type.capitalized
                if m.requiresAttunement { subtitle += " (requires attunement)" }

                items.append(RefDisplayItem(
                    id: m.srdID,
                    name: m.name,
                    category: "Magic Items",
                    subtitle: subtitle,
                    costOrRarity: m.rarity.capitalized,
                    badge: nil,
                    description: m.description
                ))
            }
        }

        allItems = items
    }
}

// MARK: - Item Detail Sheet

struct RefItemDetailSheet: View {
    let item: RefDisplayItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Category + cost/rarity
                    HStack {
                        Text(item.category)
                            .font(.subheadline.bold())
                            .foregroundStyle(DMTheme.accentBlue)
                        Spacer()
                        Text(item.costOrRarity)
                            .font(.subheadline.bold())
                            .foregroundStyle(DMTheme.accent)
                    }

                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(DMTheme.textSecondary)

                    if let badge = item.badge {
                        Text(badge)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(DMTheme.accentRed)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DMTheme.accentRed.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Divider().overlay(DMTheme.border)

                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(.body)
                            .foregroundStyle(DMTheme.textPrimary)
                    } else {
                        Text("No additional details available.")
                            .font(.body)
                            .foregroundStyle(DMTheme.textDim)
                    }
                }
                .padding()
            }
            .background(DMTheme.background)
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Condition List

struct ConditionListView: View {
    let searchText: String
    @State private var conditions: [SRDCondition] = []

    private var filtered: [SRDCondition] {
        if searchText.isEmpty { return conditions }
        return conditions.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(filtered) { condition in
            VStack(alignment: .leading, spacing: 6) {
                Text(condition.name)
                    .font(.headline)
                    .foregroundStyle(DMTheme.accent)

                ForEach(condition.effects, id: \.self) { effect in
                    HStack(alignment: .top, spacing: 6) {
                        Text("*")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textDim)
                        Text(effect)
                            .font(.caption)
                            .foregroundStyle(DMTheme.textPrimary)
                    }
                }
            }
            .padding(.vertical, 4)
            .listRowBackground(DMTheme.card)
            .listRowSeparatorTint(DMTheme.border)
        }
        .scrollContentBackground(.hidden)
        .onAppear { loadConditions() }
    }

    private func loadConditions() {
        let url = Bundle.main.bundleURL.appendingPathComponent("SRD/conditions.json")
        guard
              let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(SRDConditionWrapper.self, from: data)
        else { return }
        conditions = wrapper.conditions
    }
}

// MARK: - SRD JSON Models

struct SRDSpellWrapper: Codable, Sendable {
    let spells: [SRDSpell]
}

struct SRDSpell: Codable, Identifiable, Sendable {
    var id: String { srdID }
    let srdID: String
    let name: String
    let level: Int
    let school: String
    let castingTime: String
    let range: Int
    let components: [String]
    let duration: String
    let concentration: Bool
    let ritual: Bool
    let classes: [String]
    let description: String
    let atHigherLevels: String?

    var levelString: String {
        level == 0 ? "Cantrip" : "Level \(level)"
    }

    var rangeString: String {
        if range == 0 { return "Self" }
        return "\(range) ft."
    }

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name, level, school
        case castingTime = "casting_time"
        case range, components, duration, concentration, ritual, classes, description
        case atHigherLevels = "at_higher_levels"
    }
}

// MARK: - Unified Display Item

struct RefDisplayItem: Identifiable {
    let id: String
    let name: String
    let category: String
    let subtitle: String
    let costOrRarity: String
    let badge: String?
    let description: String
}

// MARK: - Full Items JSON Models

struct SRDFullItemFile: Codable, Sendable {
    let weapons: [SRDWeapon]
    let armor: [SRDArmor]
    let adventuringGear: [SRDGear]

    enum CodingKeys: String, CodingKey {
        case weapons, armor
        case adventuringGear = "adventuring_gear"
    }
}

struct SRDWeapon: Codable, Sendable {
    let srdID: String
    let name: String
    let category: String
    let damage: String?
    let damageType: String?
    let weight: Double?
    let cost: String
    let properties: [String]

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name, category, damage
        case damageType = "damage_type"
        case weight, cost, properties
    }
}

struct SRDArmor: Codable, Sendable {
    let srdID: String
    let name: String
    let type: String
    let baseAC: Int?
    let acBonus: Int?
    let dexBonus: Bool?
    let maxDexBonus: Int?
    let strengthRequirement: Int?
    let stealthDisadvantage: Bool?
    let cost: String

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name, type
        case baseAC = "base_ac"
        case acBonus = "ac_bonus"
        case dexBonus = "dex_bonus"
        case maxDexBonus = "max_dex_bonus"
        case strengthRequirement = "strength_requirement"
        case stealthDisadvantage = "stealth_disadvantage"
        case cost
    }
}

struct SRDGear: Codable, Sendable {
    let srdID: String
    let name: String
    let cost: String
    let weight: Double
    let description: String?

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name, cost, weight, description
    }
}

struct SRDMagicItemFile: Codable, Sendable {
    let magicItems: [SRDMagicItem]

    enum CodingKeys: String, CodingKey {
        case magicItems = "magic_items"
    }
}

struct SRDMagicItem: Codable, Sendable {
    let srdID: String
    let name: String
    let type: String
    let rarity: String
    let requiresAttunement: Bool
    let description: String

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name, type, rarity
        case requiresAttunement = "requires_attunement"
        case description
    }
}

// Keep old SRDItem/SRDItemWrapper for backward compat (used nowhere else now)
struct SRDItemWrapper: Codable, Sendable {
    let weapons: [SRDItem]
}

struct SRDItem: Codable, Identifiable, Sendable {
    var id: String { srdID }
    let srdID: String
    let name: String
    let category: String
    let damage: String?
    let cost: String

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name, category, damage, cost
    }
}

struct SRDConditionWrapper: Codable, Sendable {
    let conditions: [SRDCondition]
}

struct SRDCondition: Codable, Identifiable, Sendable {
    var id: String { name }
    let name: String
    let effects: [String]
}

// MARK: - Helpers

private extension Double {
    var cleanWeight: String {
        if self == floor(self) {
            return "\(Int(self))"
        }
        return String(format: "%.1f", self)
    }
}

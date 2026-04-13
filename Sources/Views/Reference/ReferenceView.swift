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
                    BestiaryListView(searchText: searchText)
                case .spells:
                    SpellListView(searchText: searchText)
                case .items:
                    ItemListView(searchText: searchText)
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

// MARK: - Bestiary List

struct BestiaryListView: View {
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
                    Text(monster.name)
                        .font(.subheadline)
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
            .listRowBackground(DMTheme.card)
            .listRowSeparatorTint(DMTheme.border)
        }
        .scrollContentBackground(.hidden)
        .onAppear { loadMonsters() }
        .sheet(item: $selectedMonster) { _ in
            // Monster detail would go here in a future phase
            Text("Monster detail coming soon")
                .foregroundStyle(DMTheme.textSecondary)
        }
    }

    private func loadMonsters() {
        guard let url = Bundle.main.url(forResource: "monsters", withExtension: "json", subdirectory: "SRD"),
              let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(SRDMonsterFile.self, from: data)
        else { return }
        monsters = wrapper.monsters
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
        guard let url = Bundle.main.url(forResource: "spells", withExtension: "json", subdirectory: "SRD"),
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
                    SpellStatRow(label: "Range", value: "\(spell.range) ft.")
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

// MARK: - Item List

struct ItemListView: View {
    let searchText: String
    @State private var items: [SRDItem] = []

    private var filtered: [SRDItem] {
        if searchText.isEmpty { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(filtered) { item in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline)
                        .foregroundStyle(DMTheme.textPrimary)
                    Text(item.category.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.caption2)
                        .foregroundStyle(DMTheme.textDim)
                }
                Spacer()
                Text(item.damage ?? "")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DMTheme.accentRed)
                Text(item.cost)
                    .font(.caption)
                    .foregroundStyle(DMTheme.accent)
            }
            .listRowBackground(DMTheme.card)
            .listRowSeparatorTint(DMTheme.border)
        }
        .scrollContentBackground(.hidden)
        .onAppear { loadItems() }
    }

    private func loadItems() {
        guard let url = Bundle.main.url(forResource: "items", withExtension: "json", subdirectory: "SRD"),
              let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(SRDItemWrapper.self, from: data)
        else { return }
        items = wrapper.weapons
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
        guard let url = Bundle.main.url(forResource: "conditions", withExtension: "json", subdirectory: "SRD"),
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

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name, level, school
        case castingTime = "casting_time"
        case range, components, duration, concentration, ritual, classes, description
        case atHigherLevels = "at_higher_levels"
    }
}

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

import SwiftUI
import SwiftData

// MARK: - Character Creator View

struct CharacterCreatorView: View {
    let campaign: Campaign
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var name = ""
    @State private var selectedRace = ""
    @State private var selectedClass = ""
    @State private var abilityScores: [String: Int] = [
        "STR": 15, "DEX": 14, "CON": 13, "INT": 12, "WIS": 10, "CHA": 8
    ]
    @State private var selectedSkills: Set<String> = []

    @State private var races: [SRDRace] = []
    @State private var classes: [SRDClass] = []

    private let standardArray = [15, 14, 13, 12, 10, 8]
    private let abilityOrder = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
    private let stepTitles = ["Name & Race", "Class", "Ability Scores", "Skills", "Summary"]

    private var selectedRaceData: SRDRace? {
        races.first(where: { $0.name == selectedRace })
    }

    private var selectedClassData: SRDClass? {
        classes.first(where: { $0.name == selectedClass })
    }

    /// Ability scores after applying racial bonuses
    private var finalAbilityScores: [String: Int] {
        var scores = abilityScores
        if let race = selectedRaceData {
            for (key, bonus) in race.abilityBonuses {
                let upperKey = key.uppercased()
                // Skip half-elf choice keys
                if upperKey == "CHOICE_1" || upperKey == "CHOICE_2" { continue }
                // Map "INT" key (JSON uses lowercase "int")
                let mappedKey = upperKey == "INT" ? "INT" : upperKey
                if scores[mappedKey] != nil {
                    scores[mappedKey]! += bonus
                }
            }
        }
        return scores
    }

    private func abilityModifier(for ability: String) -> Int {
        ((finalAbilityScores[ability] ?? 10) - 10) / 2
    }

    private var computedAC: Int {
        let dexMod = abilityModifier(for: "DEX")
        // Barbarian unarmored defense: 10 + DEX + CON
        if selectedClass == "Barbarian" {
            let conMod = abilityModifier(for: "CON")
            return 10 + dexMod + conMod
        }
        // Monk unarmored defense: 10 + DEX + WIS
        if selectedClass == "Monk" {
            let wisMod = abilityModifier(for: "WIS")
            return 10 + dexMod + wisMod
        }
        return 10 + dexMod
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                StepIndicatorView(steps: stepTitles, current: currentStep)
                    .padding()

                Divider().overlay(DMTheme.border)

                // Step content - plain switch instead of TabView to avoid gesture conflicts
                Group {
                    switch currentStep {
                    case 0: nameRaceStep
                    case 1: classStep
                    case 2: abilityScoreStep
                    case 3: skillStep
                    case 4: summaryStep
                    default: EmptyView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // No animation on step switch — prevents gesture conflicts

                Divider().overlay(DMTheme.border)

                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button {
                            withAnimation { currentStep -= 1 }
                        } label: {
                            Text("Back")
                                .font(.headline)
                                .foregroundStyle(DMTheme.textPrimary)
                                .frame(minWidth: 80, minHeight: 44)
                                .background(DMTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    Spacer()

                    // Show what's needed
                    if !canAdvance {
                        Text(advanceHint)
                            .font(.caption)
                            .foregroundStyle(DMTheme.accentRed)
                    }

                    if currentStep < 4 {
                        Button {
                            withAnimation { currentStep += 1 }
                        } label: {
                            Text("Next →")
                                .font(.headline)
                                .foregroundStyle(canAdvance ? DMTheme.background : DMTheme.textDim)
                                .frame(minWidth: 100, minHeight: 44)
                                .background(canAdvance ? DMTheme.accent : DMTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(!canAdvance)
                    } else {
                        Button {
                            createCharacter()
                        } label: {
                            Text("Create Character ✓")
                                .font(.headline)
                                .foregroundStyle(DMTheme.background)
                                .frame(minWidth: 160, minHeight: 44)
                                .background(DMTheme.accentGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(name.isEmpty || selectedRace.isEmpty || selectedClass.isEmpty)
                    }
                }
                .padding()
            }
            .background(DMTheme.background)
            .navigationTitle("New Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                loadRaces()
                loadClasses()
            }
        }
    }

    private var advanceHint: String {
        switch currentStep {
        case 0:
            if name.isEmpty && selectedRace.isEmpty { return "Enter a name and select a race" }
            if name.isEmpty { return "Enter a name" }
            if selectedRace.isEmpty { return "Select a race" }
            return ""
        case 1: return selectedClass.isEmpty ? "Select a class" : ""
        case 3:
            if let cls = selectedClassData {
                let needed = cls.skillChoices.count - selectedSkills.count
                return needed > 0 ? "Select \(needed) more skill\(needed == 1 ? "" : "s")" : ""
            }
            return ""
        default: return ""
        }
    }

    private var canAdvance: Bool {
        switch currentStep {
        case 0: return !name.isEmpty && !selectedRace.isEmpty
        case 1: return !selectedClass.isEmpty
        case 2: return true
        case 3:
            guard let cls = selectedClassData else { return true }
            return selectedSkills.count == cls.skillChoices.count
        default: return true
        }
    }

    // MARK: - Step 1: Name & Race

    private var nameRaceStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Name & Race")
                    .font(.title3.bold())
                    .foregroundStyle(DMTheme.accent)

                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Character Name")
                        .font(.subheadline.bold())
                        .foregroundStyle(DMTheme.textSecondary)
                    TextField("Enter name", text: $name)
                        .font(.title3)
                        .foregroundStyle(DMTheme.textPrimary)
                        .padding(12)
                        .background(DMTheme.detail)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Race picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Race")
                        .font(.subheadline.bold())
                        .foregroundStyle(DMTheme.textSecondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: 8) {
                        ForEach(races) { race in
                            Button {
                                selectedRace = race.name
                            } label: {
                                VStack(spacing: 4) {
                                    Text(race.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(selectedRace == race.name ? DMTheme.accent : DMTheme.textPrimary)
                                    Text("Speed \(race.speed)")
                                        .font(.caption2)
                                        .foregroundStyle(DMTheme.textDim)
                                    if race.darkvision > 0 {
                                        Text("Darkvision \(race.darkvision)ft")
                                            .font(.caption2)
                                            .foregroundStyle(DMTheme.textDim)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(selectedRace == race.name ? DMTheme.accent.opacity(0.15) : DMTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedRace == race.name ? DMTheme.accent : DMTheme.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Step 2: Class

    private var classStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Class")
                    .font(.title3.bold())
                    .foregroundStyle(DMTheme.accent)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 8) {
                    ForEach(classes) { cls in
                        Button {
                            if selectedClass != cls.name {
                                selectedClass = cls.name
                                selectedSkills = [] // Reset skills when class changes
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cls.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(selectedClass == cls.name ? DMTheme.accent : DMTheme.textPrimary)
                                Text("Hit Die: \(cls.hitDie)")
                                    .font(.caption2)
                                    .foregroundStyle(DMTheme.textDim)
                                Text("Primary: \(cls.primaryAbility.uppercased())")
                                    .font(.caption2)
                                    .foregroundStyle(DMTheme.textDim)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(selectedClass == cls.name ? DMTheme.accent.opacity(0.15) : DMTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedClass == cls.name ? DMTheme.accent : DMTheme.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Step 3: Ability Scores

    private var abilityScoreStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ability Scores")
                    .font(.title3.bold())
                    .foregroundStyle(DMTheme.accent)

                Text("Standard Array: \(standardArray.map(String.init).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(DMTheme.textSecondary)

                Text("Tap two scores to swap them.")
                    .font(.caption)
                    .foregroundStyle(DMTheme.textDim)

                if let race = selectedRaceData {
                    let bonusText = race.abilityBonuses
                        .filter { $0.key != "choice_1" && $0.key != "choice_2" }
                        .map { "+\($0.value) \($0.key.uppercased())" }
                        .joined(separator: ", ")
                    if !bonusText.isEmpty {
                        Text("Racial bonuses (\(selectedRace)): \(bonusText)")
                            .font(.caption)
                            .foregroundStyle(DMTheme.accentGreen)
                    }
                }

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    ForEach(abilityOrder, id: \.self) { ability in
                        let baseScore = abilityScores[ability] ?? 10
                        let finalScore = finalAbilityScores[ability] ?? 10
                        let bonus = finalScore - baseScore
                        AbilityScoreCard(
                            ability: ability,
                            score: baseScore,
                            bonus: bonus,
                            isSelected: swapSource == ability,
                            onTap: { swapAbility(ability) }
                        )
                    }
                }
            }
            .padding()
        }
    }

    @State private var swapSource: String?

    private func swapAbility(_ ability: String) {
        if let source = swapSource {
            let temp = abilityScores[source] ?? 10
            abilityScores[source] = abilityScores[ability] ?? 10
            abilityScores[ability] = temp
            swapSource = nil
        } else {
            swapSource = ability
        }
    }

    // MARK: - Step 4: Skills

    private var skillStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Skill Proficiencies")
                    .font(.title3.bold())
                    .foregroundStyle(DMTheme.accent)

                if let cls = selectedClassData {
                    let needed = cls.skillChoices.count
                    let chosen = selectedSkills.count
                    Text("Choose \(needed) skill\(needed == 1 ? "" : "s") (\(chosen)/\(needed) selected)")
                        .font(.subheadline)
                        .foregroundStyle(DMTheme.textSecondary)

                    let options = cls.skillChoices.options
                    // "any" means all standard skills
                    let skillList: [String] = options.contains("any")
                        ? ["Acrobatics", "Animal Handling", "Arcana", "Athletics", "Deception",
                           "History", "Insight", "Intimidation", "Investigation", "Medicine",
                           "Nature", "Perception", "Performance", "Persuasion", "Religion",
                           "Sleight of Hand", "Stealth", "Survival"]
                        : options

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(skillList, id: \.self) { skill in
                            let isSelected = selectedSkills.contains(skill)
                            Button {
                                if isSelected {
                                    selectedSkills.remove(skill)
                                } else if selectedSkills.count < needed {
                                    selectedSkills.insert(skill)
                                }
                            } label: {
                                Text(skill)
                                    .font(.subheadline)
                                    .foregroundStyle(isSelected ? DMTheme.accent : DMTheme.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(10)
                                    .background(isSelected ? DMTheme.accent.opacity(0.15) : DMTheme.card)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isSelected ? DMTheme.accent : DMTheme.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .opacity(!isSelected && selectedSkills.count >= needed ? 0.4 : 1.0)
                        }
                    }
                } else {
                    Text("Select a class first.")
                        .font(.subheadline)
                        .foregroundStyle(DMTheme.textDim)
                }
            }
            .padding()
        }
    }

    // MARK: - Step 5: Summary

    private var summaryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Summary")
                    .font(.title3.bold())
                    .foregroundStyle(DMTheme.accent)

                VStack(alignment: .leading, spacing: 8) {
                    SummaryRow(label: "Name", value: name)
                    SummaryRow(label: "Race", value: selectedRace)
                    SummaryRow(label: "Class", value: selectedClass)
                    SummaryRow(label: "Level", value: "1")

                    Divider().overlay(DMTheme.border)

                    // Combat stats
                    if let cls = selectedClassData {
                        let conMod = abilityModifier(for: "CON")
                        let hp = cls.startingHP + conMod
                        SummaryRow(label: "Hit Points", value: "\(hp) (\(cls.hitDie) + \(conMod >= 0 ? "+" : "")\(conMod) CON)")
                        SummaryRow(label: "Hit Die", value: cls.hitDie)
                    }

                    SummaryRow(label: "Armor Class", value: "\(computedAC)")

                    if let race = selectedRaceData {
                        SummaryRow(label: "Speed", value: "\(race.speed) ft")
                    }

                    // Saving throws
                    if let cls = selectedClassData {
                        let saves = cls.savingThrows.map { $0.uppercased() }.joined(separator: ", ")
                        SummaryRow(label: "Saving Throws", value: saves)
                    }

                    // Skills
                    if !selectedSkills.isEmpty {
                        Divider().overlay(DMTheme.border)
                        Text("Skill Proficiencies")
                            .font(.subheadline.bold())
                            .foregroundStyle(DMTheme.textSecondary)
                        Text(selectedSkills.sorted().joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(DMTheme.textPrimary)
                    }

                    Divider().overlay(DMTheme.border)

                    Text("Ability Scores (with racial bonuses)")
                        .font(.subheadline.bold())
                        .foregroundStyle(DMTheme.textSecondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(abilityOrder, id: \.self) { ability in
                            VStack(spacing: 2) {
                                Text(ability)
                                    .font(.caption2.bold())
                                    .foregroundStyle(DMTheme.textDim)
                                Text("\(finalAbilityScores[ability] ?? 10)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(DMTheme.textPrimary)
                                let mod = abilityModifier(for: ability)
                                Text(mod >= 0 ? "+\(mod)" : "\(mod)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(DMTheme.accent)
                            }
                        }
                    }

                    // Racial traits
                    if let race = selectedRaceData, !race.traits.isEmpty {
                        Divider().overlay(DMTheme.border)
                        Text("Racial Traits")
                            .font(.subheadline.bold())
                            .foregroundStyle(DMTheme.textSecondary)
                        Text(race.traits.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(DMTheme.textPrimary)
                    }

                    // Languages
                    if let race = selectedRaceData, !race.languages.isEmpty {
                        Text("Languages")
                            .font(.subheadline.bold())
                            .foregroundStyle(DMTheme.textSecondary)
                        Text(race.languages.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(DMTheme.textPrimary)
                    }
                }
                .padding(16)
                .background(DMTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(DMTheme.border, lineWidth: 1)
                )
            }
            .padding()
        }
    }

    // MARK: - Create

    private func createCharacter() {
        let pc = PlayerCharacter(name: name, race: selectedRace, characterClass: selectedClass)

        // Apply final ability scores (with racial bonuses)
        let final = finalAbilityScores
        pc.str = final["STR"] ?? 10
        pc.dex = final["DEX"] ?? 10
        pc.con = final["CON"] ?? 10
        pc.int_ = final["INT"] ?? 10
        pc.wis = final["WIS"] ?? 10
        pc.cha = final["CHA"] ?? 10

        // HP
        if let cls = selectedClassData {
            let conMod = (pc.con - 10) / 2
            pc.hpMax = cls.startingHP + conMod
            pc.hpCurrent = pc.hpMax

            // Saving throws & proficiencies
            pc.savingThrowProficiencies = cls.savingThrows
            pc.armorProficiencies = cls.armorProficiencies
            pc.weaponProficiencies = cls.weaponProficiencies

            // Spellcasting
            if cls.spellcaster, let slots = cls.spellSlotsByLevel["1"] {
                pc.spellcastingAbility = cls.spellcastingAbility
                // Filter out cantrips for spell slot tracking
                var slotDict: [String: Int] = [:]
                for (key, val) in slots where key != "cantrips" {
                    slotDict[key] = val
                }
                pc.spellSlotsMax = slotDict
                pc.spellSlots = slotDict
                let abilityMod = pc.abilityModifier(cls.spellcastingAbility)
                pc.spellSaveDC = 8 + 2 + abilityMod // 8 + prof + mod
                pc.spellAttackBonus = 2 + abilityMod
            }
        }

        // AC
        pc.armorClass = computedAC

        // Speed from race
        if let race = selectedRaceData {
            pc.speed = race.speed
            pc.traits = race.traits
            pc.languages = race.languages
            pc.darkvision = race.darkvision
        }

        // Proficiency bonus (level 1 = 2)
        pc.proficiencyBonus = 2

        // Skills
        pc.skillProficiencies = Array(selectedSkills).sorted()

        pc.campaign = campaign
        campaign.party.append(pc)
        dismiss()
    }

    // MARK: - Data Loading

    private func loadRaces() {
        let url = Bundle.main.bundleURL.appendingPathComponent("SRD/races.json")
        guard
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raceArray = json["races"] as? [[String: Any]]
        else { return }
        let decoder = JSONDecoder()
        races = raceArray.compactMap { dict in
            guard let raceData = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return try? decoder.decode(SRDRace.self, from: raceData)
        }
    }

    private func loadClasses() {
        let url = Bundle.main.bundleURL.appendingPathComponent("SRD/classes.json")
        guard
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let classArray = json["classes"] as? [[String: Any]]
        else { return }
        // Decode each class individually so one bad entry doesn't kill all
        let decoder = JSONDecoder()
        self.classes = classArray.compactMap { dict in
            guard let classData = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
            return try? decoder.decode(SRDClass.self, from: classData)
        }
    }
}

// MARK: - Step Indicator

struct StepIndicatorView: View {
    let steps: [String]
    let current: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, title in
                VStack(spacing: 4) {
                    Circle()
                        .fill(index <= current ? DMTheme.accent : DMTheme.detail)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text("\(index + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(index <= current ? DMTheme.background : DMTheme.textDim)
                        )
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(index <= current ? DMTheme.accent : DMTheme.textDim)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < current ? DMTheme.accent : DMTheme.border)
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                        .padding(.bottom, 16)
                }
            }
        }
    }
}

// MARK: - Ability Score Card

struct AbilityScoreCard: View {
    let ability: String
    let score: Int
    var bonus: Int = 0
    var isSelected: Bool = false
    let onTap: () -> Void

    private var modifier: Int { (score + bonus - 10) / 2 }
    private var finalScore: Int { score + bonus }

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 4) {
                Text(ability)
                    .font(.caption.bold())
                    .foregroundStyle(DMTheme.textSecondary)
                HStack(spacing: 2) {
                    Text("\(finalScore)")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(DMTheme.textPrimary)
                    if bonus > 0 {
                        Text("(+\(bonus))")
                            .font(.caption2)
                            .foregroundStyle(DMTheme.accentGreen)
                    }
                }
                Text(modifier >= 0 ? "+\(modifier)" : "\(modifier)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DMTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(isSelected ? DMTheme.accent.opacity(0.15) : DMTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? DMTheme.accent : DMTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary Row

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(DMTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(DMTheme.textPrimary)
        }
    }
}

// MARK: - SRD JSON Models

struct SRDRaceWrapper: Codable, Sendable {
    let races: [SRDRace]
}

struct SRDRace: Codable, Identifiable, Sendable {
    var id: String { srdID }
    let srdID: String
    let name: String
    let size: String
    let speed: Int
    let abilityBonuses: [String: Int]
    let traits: [String]
    let languages: [String]
    let darkvision: Int

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name, size, speed, traits, languages, darkvision
        case abilityBonuses = "ability_bonuses"
    }
}

struct SRDClassWrapper: Codable, Sendable {
    let classes: [SRDClass]
}

struct SRDSkillChoices: Codable, Sendable {
    let count: Int
    let options: [String]
}

struct SRDClass: Codable, Identifiable, Sendable {
    var id: String { srdID }
    let srdID: String
    let name: String
    let hitDie: String
    let primaryAbility: String
    let startingHP: Int
    let savingThrows: [String]
    let armorProficiencies: [String]
    let weaponProficiencies: [String]
    let skillChoices: SRDSkillChoices
    let spellcaster: Bool
    let spellcastingAbility: String
    let asiLevels: [Int]
    let featuresByLevel: [String: [String]]
    let spellSlotsByLevel: [String: [String: Int]]

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name
        case hitDie = "hit_die"
        case primaryAbility = "primary_ability"
        case startingHP = "starting_hp"
        case savingThrows = "saving_throws"
        case armorProficiencies = "armor_proficiencies"
        case weaponProficiencies = "weapon_proficiencies"
        case skillChoices = "skill_choices"
        case spellcaster
        case spellcastingAbility = "spellcasting_ability"
        case asiLevels = "asi_levels"
        case featuresByLevel = "features_by_level"
        case spellSlotsByLevel = "spell_slots_by_level"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        srdID = try c.decode(String.self, forKey: .srdID)
        name = try c.decode(String.self, forKey: .name)
        hitDie = try c.decode(String.self, forKey: .hitDie)
        primaryAbility = try c.decode(String.self, forKey: .primaryAbility)
        startingHP = try c.decode(Int.self, forKey: .startingHP)
        savingThrows = try c.decodeIfPresent([String].self, forKey: .savingThrows) ?? []
        armorProficiencies = try c.decodeIfPresent([String].self, forKey: .armorProficiencies) ?? []
        weaponProficiencies = try c.decodeIfPresent([String].self, forKey: .weaponProficiencies) ?? []
        skillChoices = try c.decodeIfPresent(SRDSkillChoices.self, forKey: .skillChoices) ?? SRDSkillChoices(count: 0, options: [])
        spellcaster = try c.decodeIfPresent(Bool.self, forKey: .spellcaster) ?? false
        spellcastingAbility = try c.decodeIfPresent(String.self, forKey: .spellcastingAbility) ?? ""
        asiLevels = try c.decodeIfPresent([Int].self, forKey: .asiLevels) ?? []
        featuresByLevel = try c.decodeIfPresent([String: [String]].self, forKey: .featuresByLevel) ?? [:]
        spellSlotsByLevel = (try? c.decodeIfPresent([String: [String: Int]].self, forKey: .spellSlotsByLevel)) ?? [:]
    }
}

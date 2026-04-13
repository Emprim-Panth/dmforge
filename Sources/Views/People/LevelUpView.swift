import SwiftUI
import SwiftData

// MARK: - Level Up View

struct LevelUpView: View {
    @Bindable var pc: PlayerCharacter
    @Environment(\.dismiss) private var dismiss

    @State private var classes: [SRDClass] = []
    @State private var hpRollResult: Int?
    @State private var useAverage = true
    @State private var asiChoice: ASIChoice = .none
    @State private var asiAbility1 = "STR"
    @State private var asiAbility2 = "DEX"
    @State private var asiSingleAbility = "STR"
    @State private var confirmed = false

    private let abilityOrder = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]

    private var classData: SRDClass? {
        classes.first(where: { $0.name == pc.characterClass })
    }

    private var newLevel: Int { pc.level + 1 }

    private var conMod: Int { (pc.con - 10) / 2 }

    private var hitDieMax: Int {
        guard let cls = classData else { return 8 }
        // Parse "d12" -> 12
        return Int(cls.hitDie.replacingOccurrences(of: "d", with: "")) ?? 8
    }

    private var hitDieAverage: Int {
        (hitDieMax / 2) + 1
    }

    private var hpIncrease: Int {
        let roll = useAverage ? hitDieAverage : (hpRollResult ?? hitDieAverage)
        return max(1, roll + conMod)
    }

    private var newProficiencyBonus: Int {
        switch newLevel {
        case 1...4: return 2
        case 5...8: return 3
        case 9...12: return 4
        case 13...16: return 5
        case 17...20: return 6
        default: return 2
        }
    }

    private var isASILevel: Bool {
        guard let cls = classData else { return false }
        return cls.asiLevels.contains(newLevel)
    }

    private var newFeatures: [String] {
        guard let cls = classData else { return [] }
        return cls.featuresByLevel["\(newLevel)"] ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Level header
                    HStack {
                        Text("\(pc.name)")
                            .font(.title2.bold())
                            .foregroundStyle(DMTheme.textPrimary)
                        Spacer()
                        Text("Level \(pc.level) -> \(newLevel)")
                            .font(.title3.bold())
                            .foregroundStyle(DMTheme.accent)
                    }

                    Divider().overlay(DMTheme.border)

                    // HP Increase
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hit Points")
                            .font(.headline)
                            .foregroundStyle(DMTheme.accent)

                        HStack {
                            Button {
                                useAverage = true
                            } label: {
                                Text("Average (\(hitDieAverage))")
                                    .font(.subheadline)
                                    .foregroundStyle(useAverage ? DMTheme.accent : DMTheme.textSecondary)
                                    .padding(8)
                                    .background(useAverage ? DMTheme.accent.opacity(0.15) : DMTheme.detail)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)

                            Button {
                                useAverage = false
                                rollHP()
                            } label: {
                                Text("Roll \(classData?.hitDie ?? "d8")")
                                    .font(.subheadline)
                                    .foregroundStyle(!useAverage ? DMTheme.accent : DMTheme.textSecondary)
                                    .padding(8)
                                    .background(!useAverage ? DMTheme.accent.opacity(0.15) : DMTheme.detail)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)

                            if !useAverage {
                                Button {
                                    rollHP()
                                } label: {
                                    Image(systemName: "dice.fill")
                                        .foregroundStyle(DMTheme.accent)
                                }
                                .buttonStyle(.plain)
                                .frame(minHeight: 44)
                            }
                        }

                        let rollText = useAverage ? "\(hitDieAverage)" : "\(hpRollResult ?? hitDieAverage)"
                        Text("HP increase: \(rollText) + \(conMod >= 0 ? "+" : "")\(conMod) CON = +\(hpIncrease)")
                            .font(.subheadline)
                            .foregroundStyle(DMTheme.textSecondary)

                        Text("\(pc.hpMax) -> \(pc.hpMax + hpIncrease) HP")
                            .font(.subheadline.bold())
                            .foregroundStyle(DMTheme.accentGreen)
                    }
                    .padding(12)
                    .background(DMTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(DMTheme.border, lineWidth: 1))

                    // Proficiency bonus change
                    if newProficiencyBonus != pc.proficiencyBonus {
                        HStack {
                            Text("Proficiency Bonus")
                                .font(.headline)
                                .foregroundStyle(DMTheme.accent)
                            Spacer()
                            Text("+\(pc.proficiencyBonus) -> +\(newProficiencyBonus)")
                                .font(.subheadline.bold())
                                .foregroundStyle(DMTheme.accentGreen)
                        }
                        .padding(12)
                        .background(DMTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DMTheme.border, lineWidth: 1))
                    }

                    // New features
                    if !newFeatures.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Features")
                                .font(.headline)
                                .foregroundStyle(DMTheme.accent)

                            ForEach(newFeatures, id: \.self) { feature in
                                HStack(spacing: 8) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(DMTheme.accent)
                                    Text(feature)
                                        .font(.subheadline)
                                        .foregroundStyle(DMTheme.textPrimary)
                                }
                            }
                        }
                        .padding(12)
                        .background(DMTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DMTheme.border, lineWidth: 1))
                    }

                    // ASI
                    if isASILevel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ability Score Improvement")
                                .font(.headline)
                                .foregroundStyle(DMTheme.accent)

                            Picker("ASI Type", selection: $asiChoice) {
                                Text("Two +1").tag(ASIChoice.twoPlus1)
                                Text("One +2").tag(ASIChoice.onePlus2)
                            }
                            .pickerStyle(.segmented)

                            if asiChoice == .twoPlus1 {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("First +1")
                                            .font(.caption)
                                            .foregroundStyle(DMTheme.textDim)
                                        Picker("Ability 1", selection: $asiAbility1) {
                                            ForEach(abilityOrder, id: \.self) { Text($0).tag($0) }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Second +1")
                                            .font(.caption)
                                            .foregroundStyle(DMTheme.textDim)
                                        Picker("Ability 2", selection: $asiAbility2) {
                                            ForEach(abilityOrder, id: \.self) { Text($0).tag($0) }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }
                            } else if asiChoice == .onePlus2 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Ability +2")
                                        .font(.caption)
                                        .foregroundStyle(DMTheme.textDim)
                                    Picker("Ability", selection: $asiSingleAbility) {
                                        ForEach(abilityOrder, id: \.self) { Text($0).tag($0) }
                                    }
                                    .pickerStyle(.menu)
                                }
                            }
                        }
                        .padding(12)
                        .background(DMTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DMTheme.border, lineWidth: 1))
                    }

                    // Spell slots update
                    if let cls = classData, cls.spellcaster {
                        let currentSlots = cls.spellSlotsByLevel["\(pc.level)"] ?? [:]
                        let newSlots = cls.spellSlotsByLevel["\(newLevel)"] ?? [:]
                        if currentSlots != newSlots {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Spell Slots")
                                    .font(.headline)
                                    .foregroundStyle(DMTheme.accent)

                                let allKeys = Set(currentSlots.keys).union(newSlots.keys)
                                    .sorted { keyOrder($0) < keyOrder($1) }
                                ForEach(allKeys, id: \.self) { key in
                                    if key != "cantrips" {
                                        let old = currentSlots[key] ?? 0
                                        let new = newSlots[key] ?? 0
                                        if old != new {
                                            HStack {
                                                Text(key.capitalized)
                                                    .font(.subheadline)
                                                    .foregroundStyle(DMTheme.textSecondary)
                                                Spacer()
                                                Text("\(old) -> \(new)")
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(new > old ? DMTheme.accentGreen : DMTheme.textPrimary)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(12)
                            .background(DMTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DMTheme.border, lineWidth: 1))
                        }
                    }

                    // Confirm button
                    Button {
                        applyLevelUp()
                    } label: {
                        Text("Confirm Level Up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DMButtonStyle(color: DMTheme.accentGreen))
                    .disabled(isASILevel && asiChoice == .none)
                }
                .padding()
            }
            .background(DMTheme.background)
            .navigationTitle("Level Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                loadClasses()
                if isASILevel {
                    asiChoice = .twoPlus1
                }
            }
        }
    }

    // MARK: - Actions

    private func rollHP() {
        hpRollResult = Int.random(in: 1...hitDieMax)
    }

    private func applyLevelUp() {
        // Level
        pc.level = newLevel

        // HP
        pc.hpMax += hpIncrease
        pc.hpCurrent = pc.hpMax // Full HP on level up

        // Proficiency bonus
        pc.proficiencyBonus = newProficiencyBonus

        // ASI
        if isASILevel {
            applyASI()
        }

        // Spell slots
        if let cls = classData, cls.spellcaster {
            if let newSlots = cls.spellSlotsByLevel["\(newLevel)"] {
                var slotDict: [String: Int] = [:]
                for (key, val) in newSlots where key != "cantrips" {
                    slotDict[key] = val
                }
                pc.spellSlotsMax = slotDict
                pc.spellSlots = slotDict
                // Update spell save DC and attack bonus
                let abilityMod = pc.abilityModifier(cls.spellcastingAbility)
                pc.spellSaveDC = 8 + pc.proficiencyBonus + abilityMod
                pc.spellAttackBonus = pc.proficiencyBonus + abilityMod
            }
        }

        dismiss()
    }

    private func applyASI() {
        switch asiChoice {
        case .twoPlus1:
            bumpAbility(asiAbility1, by: 1)
            bumpAbility(asiAbility2, by: 1)
        case .onePlus2:
            bumpAbility(asiSingleAbility, by: 2)
        case .none:
            break
        }
    }

    private func bumpAbility(_ ability: String, by amount: Int) {
        switch ability {
        case "STR": pc.str = min(20, pc.str + amount)
        case "DEX": pc.dex = min(20, pc.dex + amount)
        case "CON": pc.con = min(20, pc.con + amount)
        case "INT": pc.int_ = min(20, pc.int_ + amount)
        case "WIS": pc.wis = min(20, pc.wis + amount)
        case "CHA": pc.cha = min(20, pc.cha + amount)
        default: break
        }
    }

    private func keyOrder(_ key: String) -> Int {
        switch key {
        case "cantrips": return 0
        case "1st": return 1; case "2nd": return 2; case "3rd": return 3
        case "4th": return 4; case "5th": return 5; case "6th": return 6
        case "7th": return 7; case "8th": return 8; case "9th": return 9
        default: return 10
        }
    }

    private func loadClasses() {
        guard let url = Bundle.main.url(forResource: "classes", withExtension: "json", subdirectory: "SRD"),
              let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(SRDClassWrapper.self, from: data)
        else { return }
        self.classes = wrapper.classes
    }
}

enum ASIChoice {
    case none, twoPlus1, onePlus2
}

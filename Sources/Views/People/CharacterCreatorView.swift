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

    @State private var races: [SRDRace] = []
    @State private var classes: [SRDClass] = []

    private let standardArray = [15, 14, 13, 12, 10, 8]
    private let abilityOrder = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]
    private let stepTitles = ["Name & Race", "Class", "Ability Scores", "Summary", "Create"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Step indicator
                StepIndicatorView(steps: stepTitles, current: currentStep)
                    .padding()

                Divider().overlay(DMTheme.border)

                // Step content
                TabView(selection: $currentStep) {
                    nameRaceStep.tag(0)
                    classStep.tag(1)
                    abilityScoreStep.tag(2)
                    summaryStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                Divider().overlay(DMTheme.border)

                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            currentStep -= 1
                        }
                        .buttonStyle(DMSmallButtonStyle())
                        .frame(minHeight: 44)
                    }

                    Spacer()

                    if currentStep < 3 {
                        Button("Next") {
                            currentStep += 1
                        }
                        .buttonStyle(DMSmallButtonStyle(color: DMTheme.accent.opacity(0.3)))
                        .frame(minHeight: 44)
                        .disabled(!canAdvance)
                    } else {
                        Button("Create Character") {
                            createCharacter()
                        }
                        .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentGreen.opacity(0.3)))
                        .frame(minHeight: 44)
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

    private var canAdvance: Bool {
        switch currentStep {
        case 0: return !name.isEmpty && !selectedRace.isEmpty
        case 1: return !selectedClass.isEmpty
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
                            selectedClass = cls.name
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

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 12) {
                    ForEach(abilityOrder, id: \.self) { ability in
                        AbilityScoreCard(
                            ability: ability,
                            score: abilityScores[ability] ?? 10,
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

    // MARK: - Step 4: Summary

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

                    Text("Ability Scores")
                        .font(.subheadline.bold())
                        .foregroundStyle(DMTheme.textSecondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(abilityOrder, id: \.self) { ability in
                            VStack(spacing: 2) {
                                Text(ability)
                                    .font(.caption2.bold())
                                    .foregroundStyle(DMTheme.textDim)
                                Text("\(abilityScores[ability] ?? 10)")
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(DMTheme.textPrimary)
                                let mod = ((abilityScores[ability] ?? 10) - 10) / 2
                                Text(mod >= 0 ? "+\(mod)" : "\(mod)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(DMTheme.accent)
                            }
                        }
                    }

                    if let cls = classes.first(where: { $0.name == selectedClass }) {
                        Divider().overlay(DMTheme.border)
                        SummaryRow(label: "Hit Points", value: "\(cls.startingHP)")
                        SummaryRow(label: "Hit Die", value: cls.hitDie)
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
        pc.str = abilityScores["STR"] ?? 10
        pc.dex = abilityScores["DEX"] ?? 10
        pc.con = abilityScores["CON"] ?? 10
        pc.int_ = abilityScores["INT"] ?? 10
        pc.wis = abilityScores["WIS"] ?? 10
        pc.cha = abilityScores["CHA"] ?? 10

        if let cls = classes.first(where: { $0.name == selectedClass }) {
            let conMod = (pc.con - 10) / 2
            pc.hpMax = cls.startingHP + conMod
            pc.hpCurrent = pc.hpMax
        }

        pc.campaign = campaign
        campaign.party.append(pc)
        dismiss()
    }

    // MARK: - Data Loading

    private func loadRaces() {
        guard let url = Bundle.main.url(forResource: "races", withExtension: "json", subdirectory: "SRD"),
              let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(SRDRaceWrapper.self, from: data)
        else { return }
        races = wrapper.races
    }

    private func loadClasses() {
        guard let url = Bundle.main.url(forResource: "classes", withExtension: "json", subdirectory: "SRD"),
              let data = try? Data(contentsOf: url),
              let wrapper = try? JSONDecoder().decode(SRDClassWrapper.self, from: data)
        else { return }
        self.classes = wrapper.classes
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
    let onTap: () -> Void

    private var modifier: Int { (score - 10) / 2 }

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 4) {
                Text(ability)
                    .font(.caption.bold())
                    .foregroundStyle(DMTheme.textSecondary)
                Text("\(score)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(DMTheme.textPrimary)
                Text(modifier >= 0 ? "+\(modifier)" : "\(modifier)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DMTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(DMTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DMTheme.border, lineWidth: 1)
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
    let speed: Int

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name, speed
    }
}

struct SRDClassWrapper: Codable, Sendable {
    let classes: [SRDClass]
}

struct SRDClass: Codable, Identifiable, Sendable {
    var id: String { srdID }
    let srdID: String
    let name: String
    let hitDie: String
    let primaryAbility: String
    let startingHP: Int

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name
        case hitDie = "hit_die"
        case primaryAbility = "primary_ability"
        case startingHP = "starting_hp"
    }
}

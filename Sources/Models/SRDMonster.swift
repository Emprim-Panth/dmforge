import Foundation

// MARK: - SRD Monster Model (shared across Bestiary, Encounter, Reference views)

struct SRDMonster: Codable, Identifiable, Sendable {
    var id: String { srdID }
    let srdID: String
    let name: String
    let size: String
    let type: String
    let alignment: String
    let armorClass: Int
    let armorType: String?
    let hitPoints: Int
    let hitDice: String
    let speed: [String: Int]
    let abilityScores: AbilityScores
    let skills: [String: Int]
    let senses: [String: SenseValue]
    let languages: [String]
    let challengeRating: Double
    let xp: Int
    let specialAbilities: [MonsterAbility]
    let actions: [MonsterAction]
    let legendaryActions: [MonsterAbility]
    let damageImmunities: [String]
    let damageResistances: [String]
    let damageVulnerabilities: [String]
    let conditionImmunities: [String]

    // Backwards-compatible computed property used by EncounterView/ReferenceView
    var crString: String { crDisplay }

    var crDisplay: String {
        if challengeRating == 0.125 { return "1/8" }
        if challengeRating == 0.25 { return "1/4" }
        if challengeRating == 0.5 { return "1/2" }
        if challengeRating == floor(challengeRating) { return "\(Int(challengeRating))" }
        return String(format: "%.1f", challengeRating)
    }

    static func modifier(for score: Int) -> Int {
        (score - 10) / 2
    }

    static func modifierString(for score: Int) -> String {
        let mod = modifier(for: score)
        return mod >= 0 ? "+\(mod)" : "\(mod)"
    }

    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name, size, type, alignment
        case armorClass = "armor_class"
        case armorType = "armor_type"
        case hitPoints = "hit_points"
        case hitDice = "hit_dice"
        case speed
        case abilityScores = "ability_scores"
        case skills, senses, languages
        case challengeRating = "challenge_rating"
        case xp
        case specialAbilities = "special_abilities"
        case actions
        case legendaryActions = "legendary_actions"
        case damageImmunities = "damage_immunities"
        case damageResistances = "damage_resistances"
        case damageVulnerabilities = "damage_vulnerabilities"
        case conditionImmunities = "condition_immunities"
    }

    struct AbilityScores: Codable, Sendable {
        let str: Int
        let dex: Int
        let con: Int
        let int: Int
        let wis: Int
        let cha: Int
    }

    struct MonsterAbility: Codable, Identifiable, Sendable {
        var id: String { name }
        let name: String
        let description: String
    }

    struct MonsterAction: Codable, Identifiable, Sendable {
        var id: String { name }
        let name: String
        let type: String
        let description: String?
        let attackBonus: Int?
        let reach: Int?
        let damage: String?
        let damageType: String?

        enum CodingKeys: String, CodingKey {
            case name, type, description
            case attackBonus = "attack_bonus"
            case reach, damage
            case damageType = "damage_type"
        }
    }
}

// Senses can be int or string in the JSON
enum SenseValue: Codable, Sendable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            self = .int(0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }

    var displayString: String {
        switch self {
        case .int(let v): return "\(v) ft."
        case .string(let v): return v
        }
    }
}

// JSON file wrapper
struct SRDMonsterFile: Codable {
    let monsters: [SRDMonster]
}

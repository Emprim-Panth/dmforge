import Foundation
import Observation

// MARK: - Result Types

/// Result of resolving an attack roll.
struct AttackResult: Sendable {
    let hit: Bool
    let critical: Bool
    let fumble: Bool
    let damage: Int
    let damageType: String
    let attackRoll: D20Result
    let targetAC: Int
}

/// Result of a death saving throw.
struct DeathSaveResult: Sendable {
    let roll: Int
    let success: Bool
    let stable: Bool
    let dead: Bool
    let revived: Bool
}

/// Result of applying damage, accounting for resistances/immunities/vulnerabilities.
struct DamageResult: Sendable {
    let originalAmount: Int
    let finalAmount: Int
    let damageType: String
    let hpBefore: Int
    let hpAfter: Int
    let immune: Bool
    let resisted: Bool
    let vulnerable: Bool
}

/// Result of an ability check or saving throw.
struct CheckResult: Sendable {
    let success: Bool
    let roll: D20Result
    let total: Int
    let dc: Int
    let autoFail: Bool
}

// MARK: - Encounter Difficulty

/// Encounter difficulty rating per DMG.
enum EncounterDifficulty: String, Sendable {
    case trivial, easy, medium, hard, deadly
}

// MARK: - D&D 5e Condition

/// All 14 SRD conditions and their mechanical effects.
enum DnDCondition: String, CaseIterable, Sendable {
    case blinded, charmed, deafened, frightened, grappled
    case incapacitated, invisible, paralyzed, petrified
    case poisoned, prone, restrained, stunned, unconscious

    /// Human-readable mechanical effects of this condition.
    var effects: [String] {
        switch self {
        case .blinded:
            return [
                "Attack rolls have disadvantage",
                "Attack rolls against the creature have advantage",
                "Automatically fails any ability check requiring sight",
            ]
        case .charmed:
            return [
                "Cannot attack the charmer or target them with harmful abilities",
                "Charmer has advantage on social ability checks",
            ]
        case .deafened:
            return [
                "Automatically fails any ability check requiring hearing",
            ]
        case .frightened:
            return [
                "Disadvantage on ability checks and attack rolls while source is visible",
                "Cannot willingly move closer to the source of fear",
            ]
        case .grappled:
            return [
                "Speed becomes 0 and cannot benefit from speed bonuses",
            ]
        case .incapacitated:
            return [
                "Cannot take actions or reactions",
            ]
        case .invisible:
            return [
                "Attack rolls have advantage",
                "Attack rolls against the creature have disadvantage",
            ]
        case .paralyzed:
            return [
                "Incapacitated; cannot move or speak",
                "Automatically fails STR and DEX saving throws",
                "Attack rolls against have advantage",
                "Melee hits within 5 feet are automatic critical hits",
                "Speed becomes 0",
            ]
        case .petrified:
            return [
                "Incapacitated; cannot move or speak",
                "Automatically fails STR and DEX saving throws",
                "Resistance to all damage",
                "Immune to poison and disease",
                "Speed becomes 0",
            ]
        case .poisoned:
            return [
                "Disadvantage on attack rolls",
                "Disadvantage on ability checks",
            ]
        case .prone:
            return [
                "Melee attack rolls against have advantage",
                "Ranged attack rolls against have disadvantage",
                "Attack rolls have disadvantage",
                "Must crawl; standing costs half movement",
            ]
        case .restrained:
            return [
                "Speed becomes 0",
                "Disadvantage on attack rolls",
                "Disadvantage on DEX saving throws",
                "Attack rolls against have advantage",
            ]
        case .stunned:
            return [
                "Incapacitated; cannot move; can only speak falteringly",
                "Automatically fails STR and DEX saving throws",
                "Attack rolls against have advantage",
                "Speed becomes 0",
            ]
        case .unconscious:
            return [
                "Incapacitated; cannot move or speak; unaware of surroundings",
                "Drops whatever it is holding; falls prone",
                "Automatically fails STR and DEX saving throws",
                "Attack rolls against have advantage",
                "Melee hits within 5 feet are automatic critical hits",
                "Speed becomes 0",
            ]
        }
    }
}

// MARK: - Rules Engine

/// D&D 5e rules engine. Pure game logic — no UI, no persistence.
@Observable
@MainActor
final class RulesEngine {

    // MARK: - XP Thresholds (DMG p.82)

    /// XP thresholds per character level: [easy, medium, hard, deadly]
    static let xpThresholds: [Int: [Int]] = [
        1:  [25, 50, 75, 100],
        2:  [50, 100, 150, 200],
        3:  [75, 150, 225, 400],
        4:  [125, 250, 375, 500],
        5:  [250, 500, 750, 1100],
        6:  [300, 600, 900, 1400],
        7:  [350, 750, 1100, 1700],
        8:  [450, 900, 1400, 2100],
        9:  [550, 1100, 1600, 2400],
        10: [600, 1200, 1900, 2800],
        11: [800, 1600, 2400, 3600],
        12: [1000, 2000, 3000, 4500],
        13: [1100, 2200, 3400, 5100],
        14: [1250, 2500, 3800, 5700],
        15: [1400, 2800, 4300, 6400],
        16: [1600, 3200, 4800, 7200],
        17: [2000, 3900, 5900, 8800],
        18: [2100, 4200, 6300, 9500],
        19: [2400, 4900, 7300, 10900],
        20: [2800, 5700, 8500, 12700],
    ]

    // MARK: - Ability Scores

    /// Standard 5e modifier: floor((score - 10) / 2)
    func getAbilityModifier(_ score: Int) -> Int {
        return Int(floor(Double(score - 10) / 2.0))
    }

    /// Proficiency bonus by character level (PHB p.15).
    func getProficiencyBonus(_ level: Int) -> Int {
        switch level {
        case ...4: return 2
        case 5...8: return 3
        case 9...12: return 4
        case 13...16: return 5
        default: return 6
        }
    }

    // MARK: - Dice Convenience

    /// Parse and roll a dice notation string.
    func rollDice(_ notation: String) -> DiceResult {
        DiceRoller.roll(notation)
    }

    // MARK: - Attack Resolution

    /// Resolve a melee or ranged attack.
    ///
    /// - Parameters:
    ///   - attackBonus: Total attack modifier (ability + proficiency + magic).
    ///   - targetAC: Target's armor class.
    ///   - damageDice: Damage notation, e.g. "1d8+3".
    ///   - damageType: Damage type, e.g. "slashing".
    ///   - advantage: Whether the attacker has advantage.
    ///   - disadvantage: Whether the attacker has disadvantage.
    func resolveAttack(
        attackBonus: Int,
        targetAC: Int,
        damageDice: String,
        damageType: String = "slashing",
        advantage: Bool = false,
        disadvantage: Bool = false
    ) -> AttackResult {
        let attackRoll = DiceRoller.rollD20(
            modifier: attackBonus,
            advantage: advantage,
            disadvantage: disadvantage
        )

        var hit = attackRoll.total >= targetAC || attackRoll.isCritical
        // Natural 1 always misses (PHB p.194)
        if attackRoll.isFumble { hit = false }

        var damage = 0
        if hit {
            let damageRoll = DiceRoller.rollDamage(damageDice, critical: attackRoll.isCritical)
            damage = max(0, damageRoll.total)
        }

        return AttackResult(
            hit: hit, critical: attackRoll.isCritical, fumble: attackRoll.isFumble,
            damage: damage, damageType: damageType,
            attackRoll: attackRoll, targetAC: targetAC
        )
    }

    // MARK: - Death Saves

    /// Roll a death saving throw for a character (PHB p.197).
    ///
    /// - Nat 1: two failures
    /// - Nat 20: regain 1 HP, conscious
    /// - 10+: one success
    /// - <10: one failure
    /// - 3 successes: stable
    /// - 3 failures: dead
    func rollDeathSave(for character: PlayerCharacter) -> DeathSaveResult {
        let roll = Int.random(in: 1...20)
        var successes = character.deathSaveSuccesses
        var failures = character.deathSaveFailures

        // Nat 20: revive with 1 HP
        if roll == 20 {
            character.hpCurrent = 1
            character.deathSaveSuccesses = 0
            character.deathSaveFailures = 0
            return DeathSaveResult(roll: roll, success: true, stable: true,
                                   dead: false, revived: true)
        }

        let success = roll >= 10

        if roll == 1 {
            failures += 2
        } else if success {
            successes += 1
        } else {
            failures += 1
        }

        let stable = successes >= 3
        let dead = failures >= 3

        character.deathSaveSuccesses = successes
        character.deathSaveFailures = failures

        return DeathSaveResult(roll: roll, success: success, stable: stable,
                               dead: dead, revived: false)
    }

    // MARK: - Encounter Difficulty

    /// Determine encounter difficulty for a party vs. a set of monsters.
    ///
    /// Uses DMG XP threshold tables and encounter multipliers.
    func getEncounterDifficulty(partyLevels: [Int], monsterXPs: [Int]) -> EncounterDifficulty {
        guard !partyLevels.isEmpty, !monsterXPs.isEmpty else { return .trivial }

        let rawXP = monsterXPs.reduce(0, +)
        let multiplier = Self.encounterMultiplier(for: monsterXPs.count)
        let adjustedXP = Int(Double(rawXP) * multiplier)

        // Sum party thresholds
        var thresholds = [0, 0, 0, 0] // easy, medium, hard, deadly
        for level in partyLevels {
            let clamped = min(max(level, 1), 20)
            guard let t = Self.xpThresholds[clamped] else { continue }
            for i in 0..<4 { thresholds[i] += t[i] }
        }

        if adjustedXP >= thresholds[3] { return .deadly }
        if adjustedXP >= thresholds[2] { return .hard }
        if adjustedXP >= thresholds[1] { return .medium }
        if adjustedXP >= thresholds[0] { return .easy }
        return .trivial
    }

    /// Encounter multiplier based on number of monsters (DMG p.82).
    private static func encounterMultiplier(for monsterCount: Int) -> Double {
        switch monsterCount {
        case ...0: return 0.0
        case 1: return 1.0
        case 2: return 1.5
        case 3...6: return 2.0
        case 7...10: return 2.5
        case 11...14: return 3.0
        default: return 4.0
        }
    }

    // MARK: - Conditions

    /// Get the mechanical effects for a named D&D condition.
    func getConditionEffects(_ condition: String) -> [String] {
        guard let cond = DnDCondition(rawValue: condition.lowercased()) else { return [] }
        return cond.effects
    }

    // MARK: - Initiative

    /// Roll initiative: d20 + DEX modifier (PHB p.189).
    func rollInitiative(dexModifier: Int) -> Int {
        Int.random(in: 1...20) + dexModifier
    }

    // MARK: - Ability Checks & Saves

    /// Resolve an ability check against a DC.
    func resolveAbilityCheck(
        abilityScore: Int,
        dc: Int,
        proficient: Bool = false,
        level: Int = 1,
        advantage: Bool = false,
        disadvantage: Bool = false
    ) -> CheckResult {
        let abilityMod = getAbilityModifier(abilityScore)
        var bonus = abilityMod
        if proficient { bonus += getProficiencyBonus(level) }

        let roll = DiceRoller.rollD20(modifier: bonus, advantage: advantage,
                                      disadvantage: disadvantage)
        return CheckResult(success: roll.total >= dc, roll: roll,
                           total: roll.total, dc: dc, autoFail: false)
    }

    /// Resolve a saving throw.
    func resolveSavingThrow(
        abilityScore: Int,
        dc: Int,
        proficient: Bool = false,
        level: Int = 1,
        conditions: [String] = [],
        ability: String = ""
    ) -> CheckResult {
        // Paralyzed/stunned: auto-fail STR and DEX saves (PHB p.291)
        let hasParalyzed = conditions.contains("paralyzed")
        let hasStunned = conditions.contains("stunned")
        if (hasParalyzed || hasStunned) && (ability == "str" || ability == "dex") {
            let zeroRoll = D20Result(roll1: 0, roll2: 0, chosen: 0, modifier: 0,
                                     total: 0, isCritical: false, isFumble: false,
                                     advantage: false, disadvantage: false)
            return CheckResult(success: false, roll: zeroRoll, total: 0,
                               dc: dc, autoFail: true)
        }

        let abilityMod = getAbilityModifier(abilityScore)
        var bonus = abilityMod
        if proficient { bonus += getProficiencyBonus(level) }

        // Restrained: disadvantage on DEX saves
        var disadv = false
        if conditions.contains("restrained") && ability == "dex" { disadv = true }

        let roll = DiceRoller.rollD20(modifier: bonus, disadvantage: disadv)
        return CheckResult(success: roll.total >= dc, roll: roll,
                           total: roll.total, dc: dc, autoFail: false)
    }

    // MARK: - Spell DC

    /// Spell save DC = 8 + proficiency + spellcasting ability modifier (PHB p.205).
    func calculateSpellDC(level: Int, castingAbilityScore: Int) -> Int {
        8 + getProficiencyBonus(level) + getAbilityModifier(castingAbilityScore)
    }

    // MARK: - AC Calculation

    /// Calculate AC from armor type, DEX score, shield, and bonus.
    func calculateAC(
        dexScore: Int,
        armorType: String = "none",
        baseAC: Int = 10,
        hasShield: Bool = false,
        acBonus: Int = 0
    ) -> Int {
        let dexMod = getAbilityModifier(dexScore)

        var ac: Int
        switch armorType.lowercased() {
        case "none": ac = 10 + dexMod
        case "light": ac = baseAC + dexMod
        case "medium": ac = baseAC + min(dexMod, 2)
        case "heavy": ac = baseAC
        default: ac = 10 + dexMod
        }

        if hasShield { ac += 2 }
        ac += acBonus
        return ac
    }

    // MARK: - Damage Application

    /// Apply damage to an entity, respecting resistances, immunities, and vulnerabilities.
    func applyDamage(
        currentHP: Int,
        amount: Int,
        damageType: String,
        immunities: [String] = [],
        resistances: [String] = [],
        vulnerabilities: [String] = []
    ) -> DamageResult {
        var finalAmount = amount
        var immune = false
        var resisted = false
        var vulnerable = false

        if immunities.contains(damageType) {
            finalAmount = 0
            immune = amount > 0
        } else if vulnerabilities.contains(damageType) {
            finalAmount = amount * 2
            vulnerable = true
        } else if resistances.contains(damageType) {
            finalAmount = Int(floor(Double(amount) / 2.0))
            resisted = true
        }

        let newHP = max(0, currentHP - finalAmount)

        return DamageResult(
            originalAmount: amount, finalAmount: finalAmount,
            damageType: damageType, hpBefore: currentHP, hpAfter: newHP,
            immune: immune, resisted: resisted, vulnerable: vulnerable
        )
    }
}

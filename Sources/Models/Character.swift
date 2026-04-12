import Foundation
import SwiftData

@Model
final class PlayerCharacter {
    var id: UUID
    var name: String
    var race: String
    var characterClass: String
    var level: Int

    // Combat stats
    var hpCurrent: Int
    var hpMax: Int
    var tempHP: Int
    var armorClass: Int
    var speed: Int
    var proficiencyBonus: Int

    // Ability scores
    var str: Int
    var dex: Int
    var con: Int
    var int_: Int  // 'int' is reserved
    var wis: Int
    var cha: Int

    // Spell slots
    var spellSlots: [String: Int]     // "1st": 4, "2nd": 2
    var spellSlotsMax: [String: Int]
    var spellcastingAbility: String
    var spellSaveDC: Int
    var spellAttackBonus: Int

    // State
    var conditions: [String]
    var deathSaveSuccesses: Int
    var deathSaveFailures: Int
    var concentratingOn: String

    // Location
    var locationID: UUID?

    // Relationship
    var campaign: Campaign?

    var isDead: Bool { deathSaveFailures >= 3 }

    var hpRatio: Double {
        guard hpMax > 0 else { return 0 }
        return Double(hpCurrent) / Double(hpMax)
    }

    var abilityModifier: (String) -> Int {
        { ability in
            let score: Int
            switch ability {
            case "str": score = self.str
            case "dex": score = self.dex
            case "con": score = self.con
            case "int": score = self.int_
            case "wis": score = self.wis
            case "cha": score = self.cha
            default: score = 10
            }
            return (score - 10) / 2
        }
    }

    init(name: String, race: String, characterClass: String, level: Int = 1) {
        self.id = UUID()
        self.name = name
        self.race = race
        self.characterClass = characterClass
        self.level = level
        self.hpCurrent = 10
        self.hpMax = 10
        self.tempHP = 0
        self.armorClass = 10
        self.speed = 30
        self.proficiencyBonus = 2
        self.str = 10; self.dex = 10; self.con = 10
        self.int_ = 10; self.wis = 10; self.cha = 10
        self.spellSlots = [:]
        self.spellSlotsMax = [:]
        self.spellcastingAbility = ""
        self.spellSaveDC = 0
        self.spellAttackBonus = 0
        self.conditions = []
        self.deathSaveSuccesses = 0
        self.deathSaveFailures = 0
        self.concentratingOn = ""
    }
}

@Model
final class NPC {
    var id: UUID
    var name: String
    var role: String
    var race: String
    var notes: String
    var locationID: UUID?
    var alive: Bool

    var campaign: Campaign?

    init(name: String, role: String = "") {
        self.id = UUID()
        self.name = name
        self.role = role
        self.race = ""
        self.notes = ""
        self.alive = true
    }
}

@Model
final class Enemy {
    var id: UUID
    var name: String
    var role: String
    var cr: Double
    var hpCurrent: Int
    var hpMax: Int
    var armorClass: Int
    var notes: String
    var srdID: String
    var locationID: UUID?
    var alive: Bool

    var campaign: Campaign?

    init(name: String, cr: Double = 0) {
        self.id = UUID()
        self.name = name
        self.role = ""
        self.cr = cr
        self.hpCurrent = 0
        self.hpMax = 0
        self.armorClass = 0
        self.notes = ""
        self.srdID = ""
        self.alive = true
    }
}

@Model
final class FallenHero {
    var id: UUID
    var name: String
    var characterClass: String
    var level: Int
    var diedCause: String
    var diedSession: String
    var diedDate: Date
    var characterData: Data?  // Serialized full PC snapshot

    var campaign: Campaign?

    init(from pc: PlayerCharacter, cause: String, session: String) {
        self.id = UUID()
        self.name = pc.name
        self.characterClass = pc.characterClass
        self.level = pc.level
        self.diedCause = cause
        self.diedSession = session
        self.diedDate = .now
        // Serialize the PC data for the memorial
        self.characterData = try? JSONEncoder().encode([
            "hp_max": pc.hpMax,
            "ac": pc.armorClass,
            "str": pc.str, "dex": pc.dex, "con": pc.con,
            "int": pc.int_, "wis": pc.wis, "cha": pc.cha,
        ])
    }
}

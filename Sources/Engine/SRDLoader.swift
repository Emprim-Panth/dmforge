import Foundation
import Observation
import OSLog

// MARK: - SRD Data Types

/// A raw SRD entry from JSON. Thin wrapper around a dictionary for type safety.
struct SRDEntry: Identifiable, @unchecked Sendable {
    let data: [String: Any]

    var id: String { srdID }
    var srdID: String { data["srd_id"] as? String ?? "" }
    var name: String { data["name"] as? String ?? "" }

    subscript(key: String) -> Any? { data[key] }

    // Monster-specific convenience
    var challengeRating: Double { data["challenge_rating"] as? Double ?? 0 }
    var xp: Int { data["xp"] as? Int ?? 0 }
    var armorClass: Int { data["armor_class"] as? Int ?? 0 }
    var hitPoints: Int { data["hit_points"] as? Int ?? 0 }
    var hitDice: String { data["hit_dice"] as? String ?? "" }
    var size: String { data["size"] as? String ?? "" }
    var type: String { data["type"] as? String ?? "" }

    // Spell-specific convenience
    var level: Int { data["level"] as? Int ?? 0 }
    var school: String { data["school"] as? String ?? "" }
    var castingTime: String { data["casting_time"] as? String ?? "" }
    var range: String { data["range"] as? String ?? "" }
    var duration: String { data["duration"] as? String ?? "" }
    var description: String { data["description"] as? String ?? "" }
    var classes: [String] { data["classes"] as? [String] ?? [] }

    // Item-specific convenience
    var rarity: String { data["rarity"] as? String ?? "" }
}

// MARK: - SRD Loader

/// Loads and indexes all SRD JSON data from the app bundle for O(1) lookups.
///
/// JSON files are expected in `Resources/SRD/` within the app bundle.
/// Each file contains a top-level object with a keyed array (e.g. `"monsters": [...]`).
@Observable
@MainActor
final class SRDLoader {
    private static let logger = Logger(subsystem: "com.forgecode.dmforge", category: "SRDLoader")

    // Primary stores keyed by srd_id
    private var monsters: [String: SRDEntry] = [:]
    private var spells: [String: SRDEntry] = [:]
    private var races: [String: SRDEntry] = [:]
    private var classes: [String: SRDEntry] = [:]
    private var weapons: [String: SRDEntry] = [:]
    private var armor: [String: SRDEntry] = [:]
    private var gear: [String: SRDEntry] = [:]
    private var magicItems: [String: SRDEntry] = [:]
    private var throwableItems: [String: SRDEntry] = [:]
    private var conditions: [String: SRDEntry] = [:]

    // Raw arrays for iteration/search
    private var monsterList: [SRDEntry] = []
    private var spellList: [SRDEntry] = []
    private var magicItemList: [SRDEntry] = []
    private var gearList: [SRDEntry] = []
    private var throwableList: [SRDEntry] = []

    private(set) var loaded = false

    // MARK: - Loading

    /// Load all SRD JSON files from the app bundle.
    func loadAll() {
        guard !loaded else { return }

        loadMonsters()
        loadSpells()
        loadRaces()
        loadClasses()
        loadItems()
        loadMagicItems()
        loadThrowableItems()
        loadConditions()

        loaded = true
        Self.logger.info("""
            Loaded: \(self.monsters.count) monsters, \(self.spells.count) spells, \
            \(self.races.count) races, \(self.classes.count) classes, \
            \(self.weapons.count) weapons, \(self.armor.count) armor, \
            \(self.gear.count) gear, \(self.magicItems.count) magic items, \
            \(self.throwableItems.count) throwables, \(self.conditions.count) conditions
            """)
    }

    // MARK: - Private Loaders

    private func loadJSON(_ filename: String) -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json",
                                        subdirectory: "SRD") else {
            Self.logger.warning("File not found: SRD/\(filename).json")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                Self.logger.warning("JSON root is not a dictionary: \(filename).json")
                return nil
            }
            return json
        } catch {
            Self.logger.error("Failed to load \(filename).json: \(error.localizedDescription)")
            return nil
        }
    }

    private func entries(from json: [String: Any]?, key: String) -> [SRDEntry] {
        guard let json, let list = json[key] as? [[String: Any]] else { return [] }
        return list.compactMap { dict in
            guard dict["srd_id"] != nil || dict["name"] != nil else { return nil }
            return SRDEntry(data: dict)
        }
    }

    private func loadMonsters() {
        let json = loadJSON("monsters")
        let list = entries(from: json, key: "monsters")
        monsterList = list
        for entry in list where !entry.srdID.isEmpty {
            monsters[entry.srdID] = entry
        }
    }

    private func loadSpells() {
        let json = loadJSON("spells")
        let list = entries(from: json, key: "spells")
        spellList = list
        for entry in list where !entry.srdID.isEmpty {
            spells[entry.srdID] = entry
        }
    }

    private func loadRaces() {
        let json = loadJSON("races")
        let list = entries(from: json, key: "races")
        for entry in list where !entry.srdID.isEmpty {
            races[entry.srdID] = entry
        }
    }

    private func loadClasses() {
        let json = loadJSON("classes")
        let list = entries(from: json, key: "classes")
        for entry in list where !entry.srdID.isEmpty {
            classes[entry.srdID] = entry
        }
    }

    private func loadItems() {
        let json = loadJSON("items")
        guard let json else { return }

        if let weaponList = json["weapons"] as? [[String: Any]] {
            for dict in weaponList {
                let entry = SRDEntry(data: dict)
                guard !entry.srdID.isEmpty else { continue }
                weapons[entry.srdID] = entry
            }
        }
        if let armorList = json["armor"] as? [[String: Any]] {
            for dict in armorList {
                let entry = SRDEntry(data: dict)
                guard !entry.srdID.isEmpty else { continue }
                armor[entry.srdID] = entry
            }
        }
        if let gearArray = json["adventuring_gear"] as? [[String: Any]] {
            for dict in gearArray {
                let entry = SRDEntry(data: dict)
                guard !entry.srdID.isEmpty else { continue }
                gear[entry.srdID] = entry
                gearList.append(entry)
            }
        }
    }

    private func loadMagicItems() {
        let json = loadJSON("magic_items")
        let list = entries(from: json, key: "magic_items")
        magicItemList = list
        for entry in list where !entry.srdID.isEmpty {
            magicItems[entry.srdID] = entry
        }
    }

    private func loadThrowableItems() {
        let json = loadJSON("throwable_items")
        let list = entries(from: json, key: "throwable_items")
        throwableList = list
        for entry in list where !entry.srdID.isEmpty {
            throwableItems[entry.srdID] = entry
        }
    }

    private func loadConditions() {
        let json = loadJSON("conditions")
        guard let json, let list = json["conditions"] as? [[String: Any]] else { return }
        for dict in list {
            let entry = SRDEntry(data: dict)
            let key = entry.name.lowercased()
            guard !key.isEmpty else { continue }
            conditions[key] = entry
        }
    }

    // MARK: - Monster Queries

    /// Get a monster by its SRD ID.
    func getMonster(_ srdID: String) -> SRDEntry? {
        monsters[srdID]
    }

    /// Get all loaded monsters.
    func getAllMonsters() -> [SRDEntry] {
        monsterList
    }

    /// Search monsters by name (case-insensitive substring match).
    func searchMonsters(query: String) -> [SRDEntry] {
        let q = query.lowercased()
        return monsterList.filter { $0.name.lowercased().contains(q) }
    }

    /// Get monsters within a challenge rating range.
    func getMonstersByCR(min minCR: Double, max maxCR: Double) -> [SRDEntry] {
        monsterList.filter { $0.challengeRating >= minCR && $0.challengeRating <= maxCR }
    }

    // MARK: - Spell Queries

    /// Get a spell by its SRD ID.
    func getSpell(srdID: String) -> SRDEntry? {
        spells[srdID]
    }

    /// Get all loaded spells.
    func getAllSpells() -> [SRDEntry] {
        spellList
    }

    /// Get spells available to a specific class.
    func getSpellsForClass(_ className: String) -> [SRDEntry] {
        let cn = className.lowercased()
        return spellList.filter { entry in
            entry.classes.contains { $0.lowercased() == cn }
        }
    }

    /// Get spells of a specific level.
    func getSpellsByLevel(_ level: Int) -> [SRDEntry] {
        spellList.filter { $0.level == level }
    }

    // MARK: - Race & Class Queries

    func getRace(srdID: String) -> SRDEntry? { races[srdID] }
    func getAllRaces() -> [SRDEntry] { Array(races.values) }

    func getCharClass(srdID: String) -> SRDEntry? { classes[srdID] }
    func getAllClasses() -> [SRDEntry] { Array(classes.values) }

    // MARK: - Item Queries

    /// Search all item categories for a given SRD ID.
    func getItem(srdID: String) -> SRDEntry? {
        weapons[srdID] ?? armor[srdID] ?? gear[srdID]
            ?? magicItems[srdID] ?? throwableItems[srdID]
    }

    func getWeapons() -> [SRDEntry] { Array(weapons.values) }
    func getArmor() -> [SRDEntry] { Array(armor.values) }

    // MARK: - Gear Queries

    func getGear(srdID: String) -> SRDEntry? { gear[srdID] }
    func getAllGear() -> [SRDEntry] { gearList }

    func searchGear(query: String) -> [SRDEntry] {
        let q = query.lowercased()
        return gearList.filter { $0.name.lowercased().contains(q) }
    }

    // MARK: - Magic Item Queries

    func getMagicItem(srdID: String) -> SRDEntry? { magicItems[srdID] }
    func getAllMagicItems() -> [SRDEntry] { magicItemList }

    func searchMagicItems(query: String) -> [SRDEntry] {
        let q = query.lowercased()
        return magicItemList.filter { $0.name.lowercased().contains(q) }
    }

    func getMagicItemsByRarity(_ rarity: String) -> [SRDEntry] {
        let r = rarity.lowercased()
        return magicItemList.filter { $0.rarity.lowercased() == r }
    }

    // MARK: - Throwable Item Queries

    func getThrowableItem(srdID: String) -> SRDEntry? { throwableItems[srdID] }
    func getAllThrowableItems() -> [SRDEntry] { throwableList }
    func isThrowable(_ srdID: String) -> Bool { throwableItems[srdID] != nil }

    // MARK: - Condition Queries

    func getCondition(_ name: String) -> SRDEntry? { conditions[name.lowercased()] }
    func getAllConditions() -> [SRDEntry] { Array(conditions.values) }
}

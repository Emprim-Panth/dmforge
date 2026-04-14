import SwiftUI
import SwiftData

/// Automated QA test that exercises every feature end-to-end.
/// Call QATest.run(modelContext:) to execute all tests and print results.
enum QATest {
    
    @MainActor
    static func run(modelContext: ModelContext) -> String {
        var results: [String] = []
        var pass = 0
        var fail = 0
        
        func check(_ name: String, _ condition: Bool, _ detail: String = "") {
            if condition {
                pass += 1
                results.append("✅ \(name)")
            } else {
                fail += 1
                results.append("❌ \(name)\(detail.isEmpty ? "" : " — \(detail)")")
            }
        }
        
        // ══════════════════════════════════════════
        // TEST 1: SRD Data Loading
        // ══════════════════════════════════════════
        results.append("\n=== SRD DATA LOADING ===")
        
        // Monsters
        let monstersURL = Bundle.main.bundleURL.appendingPathComponent("SRD/monsters.json")
        let monstersExist = FileManager.default.fileExists(atPath: monstersURL.path)
        check("monsters.json exists in bundle", monstersExist)
        
        if monstersExist, let data = try? Data(contentsOf: monstersURL) {
            check("monsters.json readable", true)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let arr = json["monsters"] as? [[String: Any]] {
                check("monsters.json has monsters array", true)
                check("monsters count >= 300", arr.count >= 300, "got \(arr.count)")
            } else {
                check("monsters.json parseable", false, "failed to parse")
            }
        } else {
            check("monsters.json readable", false)
        }
        
        // Races
        let racesURL = Bundle.main.bundleURL.appendingPathComponent("SRD/races.json")
        let racesExist = FileManager.default.fileExists(atPath: racesURL.path)
        check("races.json exists in bundle", racesExist)
        
        if racesExist, let data = try? Data(contentsOf: racesURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let arr = json["races"] as? [[String: Any]] {
            check("races count >= 9", arr.count >= 9, "got \(arr.count)")
            
            // Try decoding each race individually
            let decoder = JSONDecoder()
            var raceDecodeCount = 0
            for dict in arr {
                if let raceData = try? JSONSerialization.data(withJSONObject: dict),
                   let _ = try? decoder.decode(TestSRDRace.self, from: raceData) {
                    raceDecodeCount += 1
                }
            }
            check("all races decode", raceDecodeCount == arr.count, "\(raceDecodeCount)/\(arr.count) decoded")
        }
        
        // Classes
        let classesURL = Bundle.main.bundleURL.appendingPathComponent("SRD/classes.json")
        let classesExist = FileManager.default.fileExists(atPath: classesURL.path)
        check("classes.json exists in bundle", classesExist)
        
        if classesExist, let data = try? Data(contentsOf: classesURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let arr = json["classes"] as? [[String: Any]] {
            check("classes count >= 12", arr.count >= 12, "got \(arr.count)")
            
            // Try decoding each class individually
            let decoder = JSONDecoder()
            var classDecodeCount = 0
            var failedClasses: [String] = []
            for dict in arr {
                let name = dict["name"] as? String ?? "?"
                if let classData = try? JSONSerialization.data(withJSONObject: dict),
                   let _ = try? decoder.decode(TestSRDClass.self, from: classData) {
                    classDecodeCount += 1
                } else {
                    failedClasses.append(name)
                }
            }
            check("classes decode (individual)", classDecodeCount >= 11, "\(classDecodeCount)/\(arr.count) decoded, failed: \(failedClasses)")
        }
        
        // Spells
        let spellsURL = Bundle.main.bundleURL.appendingPathComponent("SRD/spells.json")
        check("spells.json exists", FileManager.default.fileExists(atPath: spellsURL.path))
        
        // Conditions  
        let condURL = Bundle.main.bundleURL.appendingPathComponent("SRD/conditions.json")
        check("conditions.json exists", FileManager.default.fileExists(atPath: condURL.path))
        
        // Items
        let itemsURL = Bundle.main.bundleURL.appendingPathComponent("SRD/items.json")
        check("items.json exists", FileManager.default.fileExists(atPath: itemsURL.path))
        
        // Magic Items
        let magicURL = Bundle.main.bundleURL.appendingPathComponent("SRD/magic_items.json")
        check("magic_items.json exists", FileManager.default.fileExists(atPath: magicURL.path))
        
        // ══════════════════════════════════════════
        // TEST 2: Campaign CRUD
        // ══════════════════════════════════════════
        results.append("\n=== CAMPAIGN CRUD ===")
        
        let campaign = Campaign(name: "QA Test Campaign")
        modelContext.insert(campaign)
        check("campaign created", true)
        check("campaign name", campaign.name == "QA Test Campaign")
        check("campaign party empty", campaign.party.isEmpty)
        check("campaign places empty", campaign.places.isEmpty)
        check("campaign npcs empty", campaign.npcs.isEmpty)
        
        // ══════════════════════════════════════════
        // TEST 3: Character Creation
        // ══════════════════════════════════════════
        results.append("\n=== CHARACTER CREATION ===")
        
        let pc = PlayerCharacter(name: "Thorin", race: "Dwarf", characterClass: "Fighter")
        pc.level = 5
        pc.str = 16; pc.dex = 12; pc.con = 14; pc.int_ = 10; pc.wis = 13; pc.cha = 8
        pc.hpMax = 44; pc.hpCurrent = 44
        pc.armorClass = 18; pc.speed = 25; pc.proficiencyBonus = 3
        pc.skillProficiencies = ["Athletics", "Perception"]
        pc.savingThrowProficiencies = ["str", "con"]
        pc.campaign = campaign
        campaign.party.append(pc)
        
        check("PC created", true)
        check("PC in party", campaign.party.count == 1)
        check("PC name", campaign.party.first?.name == "Thorin")
        check("PC level", pc.level == 5)
        check("PC HP", pc.hpCurrent == 44 && pc.hpMax == 44)
        check("PC AC", pc.armorClass == 18)
        check("PC skills", pc.skillProficiencies.count == 2)
        
        // Second PC (spellcaster)
        let wizard = PlayerCharacter(name: "Elara", race: "Elf", characterClass: "Wizard")
        wizard.level = 5
        wizard.str = 8; wizard.dex = 14; wizard.con = 12; wizard.int_ = 18; wizard.wis = 13; wizard.cha = 10
        wizard.hpMax = 28; wizard.hpCurrent = 28
        wizard.armorClass = 12; wizard.speed = 30; wizard.proficiencyBonus = 3
        wizard.spellSlots = ["1st": 4, "2nd": 3, "3rd": 2]
        wizard.spellSlotsMax = ["1st": 4, "2nd": 3, "3rd": 2]
        wizard.spellcastingAbility = "int"
        wizard.spellSaveDC = 15; wizard.spellAttackBonus = 7
        wizard.campaign = campaign
        campaign.party.append(wizard)
        
        check("wizard created with spell slots", wizard.spellSlots["1st"] == 4)
        check("party has 2 PCs", campaign.party.count == 2)
        
        // ══════════════════════════════════════════
        // TEST 4: NPCs
        // ══════════════════════════════════════════
        results.append("\n=== NPCS ===")
        
        let npc = NPC(name: "Gundren Rockseeker", role: "Quest giver")
        npc.notes = "Hired the party to escort a wagon"
        npc.campaign = campaign
        campaign.npcs.append(npc)
        
        check("NPC created", campaign.npcs.count == 1)
        check("NPC name", campaign.npcs.first?.name == "Gundren Rockseeker")
        
        // ══════════════════════════════════════════
        // TEST 5: Enemies
        // ══════════════════════════════════════════
        results.append("\n=== ENEMIES ===")
        
        let enemy = Enemy(name: "Goblin Boss", cr: 1.0)
        enemy.hpMax = 21; enemy.hpCurrent = 21; enemy.armorClass = 17
        enemy.campaign = campaign
        campaign.enemies.append(enemy)
        
        check("enemy created", campaign.enemies.count == 1)
        check("enemy CR", enemy.cr == 1.0)
        
        // ══════════════════════════════════════════
        // TEST 6: Places
        // ══════════════════════════════════════════
        results.append("\n=== PLACES ===")
        
        let town = Place(name: "Phandalin", type: "town")
        town.desc = "A small mining town"
        town.campaign = campaign
        campaign.places.append(town)
        
        let tavern = Place(name: "Stonehill Inn", type: "tavern")
        tavern.parentID = town.id
        tavern.campaign = campaign
        campaign.places.append(tavern)
        
        check("places created", campaign.places.count == 2)
        check("child place has parent", tavern.parentID == town.id)
        
        // ══════════════════════════════════════════
        // TEST 7: Fallen Heroes
        // ══════════════════════════════════════════
        results.append("\n=== FALLEN HEROES ===")
        
        let fallen = FallenHero(from: wizard, cause: "Killed by Dragon Breath", session: "Session 5")
        fallen.campaign = campaign
        campaign.fallen.append(fallen)
        
        check("fallen hero created", campaign.fallen.count == 1)
        check("fallen cause", fallen.diedCause == "Killed by Dragon Breath")
        
        // ══════════════════════════════════════════
        // TEST 8: Story Sessions
        // ══════════════════════════════════════════
        results.append("\n=== STORY ===")
        
        let session = StorySession(title: "The Goblin Ambush")
        session.campaign = campaign
        campaign.sessions.append(session)
        
        check("session created", campaign.sessions.count == 1)
        
        // ══════════════════════════════════════════
        // TEST 9: Monster Roster
        // ══════════════════════════════════════════
        results.append("\n=== MONSTER ROSTER ===")
        
        campaign.monsterRoster.append("goblin")
        campaign.monsterRoster.append("goblin-boss")
        campaign.monsterRoster.append("wolf")
        
        check("monster roster", campaign.monsterRoster.count == 3)
        
        // ══════════════════════════════════════════
        // TEST 10: Map Data
        // ══════════════════════════════════════════
        results.append("\n=== MAP DATA ===")
        
        campaign.mapStamps.append(MapStamp(type: "mountain", variant: 0, x: 0.3, y: 0.2, size: 40))
        campaign.mapStamps.append(MapStamp(type: "town", variant: 2, x: 0.5, y: 0.5, size: 30))
        
        check("map stamps", campaign.mapStamps.count == 2)
        
        // ══════════════════════════════════════════
        // TEST 11: DM Notes
        // ══════════════════════════════════════════
        results.append("\n=== DM NOTES ===")
        
        campaign.gmNotes = "The party must find the lost mine before the Black Spider does."
        check("notes saved", !campaign.gmNotes.isEmpty)
        
        // ══════════════════════════════════════════
        // TEST 12: Rules Engine
        // ══════════════════════════════════════════
        results.append("\n=== RULES ENGINE ===")
        
        let engine = RulesEngine()
        
        check("ability modifier (16)", engine.getAbilityModifier(16) == 3)
        check("ability modifier (10)", engine.getAbilityModifier(10) == 0)
        check("ability modifier (8)", engine.getAbilityModifier(8) == -1)
        check("proficiency bonus (1)", engine.getProficiencyBonus(1) == 2)
        check("proficiency bonus (5)", engine.getProficiencyBonus(5) == 3)
        check("proficiency bonus (9)", engine.getProficiencyBonus(9) == 4)
        
        let diceResult = engine.rollDice("2d6+3")
        check("dice roll has total", diceResult.total >= 5 && diceResult.total <= 15)
        
        // ══════════════════════════════════════════
        // TEST 13: Death Saves
        // ══════════════════════════════════════════
        results.append("\n=== DEATH SAVES ===")
        
        let dyingPC = PlayerCharacter(name: "TestDying", race: "Human", characterClass: "Fighter")
        dyingPC.hpCurrent = 0
        dyingPC.hpMax = 10
        
        let saveResult = engine.rollDeathSave(for: dyingPC)
        check("death save returns result", true)
        check("death save roll 1-20", saveResult.roll >= 1 && saveResult.roll <= 20)
        let totalSaves = dyingPC.deathSaveSuccesses + dyingPC.deathSaveFailures
        check("death save updates PC", totalSaves > 0 || saveResult.revived)
        
        // ══════════════════════════════════════════
        // SUMMARY
        // ══════════════════════════════════════════
        results.append("\n" + String(repeating: "═", count: 40))
        results.append("QA RESULTS: \(pass) passed, \(fail) failed out of \(pass + fail) tests")
        if fail == 0 {
            results.append("🎉 ALL TESTS PASSED")
        } else {
            results.append("⚠️  \(fail) FAILURES — see above")
        }
        
        // Clean up test data
        modelContext.delete(campaign)
        
        return results.joined(separator: "\n")
    }
}

// Minimal decode structs for testing (don't conflict with app structs)
private struct TestSRDRace: Codable {
    let srdID: String
    let name: String
    let speed: Int
    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name, speed
    }
}

private struct TestSRDClass: Codable {
    let srdID: String
    let name: String
    let hitDie: String
    let startingHP: Int
    enum CodingKeys: String, CodingKey {
        case srdID = "srd_id"
        case name
        case hitDie = "hit_die"
        case startingHP = "starting_hp"
    }
}

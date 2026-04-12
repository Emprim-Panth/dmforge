import Foundation
import SwiftData

@Model
final class Place {
    var id: UUID
    var name: String
    var type: String  // town, city, dungeon, building, wilderness, tavern, temple, etc.
    var parentID: UUID?
    var desc: String
    var notes: String

    var campaign: Campaign?

    init(name: String, type: String = "town") {
        self.id = UUID()
        self.name = name
        self.type = type
        self.desc = ""
        self.notes = ""
    }

    var typeIcon: String {
        switch type.lowercased() {
        case "town": return "🏘"
        case "city": return "🏙"
        case "village": return "🏡"
        case "dungeon": return "⚔️"
        case "building": return "🏠"
        case "wilderness": return "🌲"
        case "tavern": return "🍺"
        case "shop": return "🛒"
        case "temple": return "⛪"
        case "camp": return "⛺"
        default: return "📍"
        }
    }
}

@Model
final class StorySession {
    var id: UUID
    var title: String
    var date: Date
    var status: String  // planned, active, completed
    var recap: String
    var notes: String

    var campaign: Campaign?

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.date = .now
        self.status = "planned"
        self.recap = ""
        self.notes = ""
    }
}

@Model
final class EncounterZone {
    var id: UUID
    var name: String
    var positionX: Double
    var positionY: Double
    var radius: Double
    var monsterSRDIDs: [String]  // ["goblin", "goblin-boss"]
    var monsterCounts: [Int]     // [3, 1]
    var triggerType: String      // "enter" or "camp"
    var persistent: Bool
    var active: Bool
    var triggeredSession: String?

    var campaign: Campaign?

    var position: CGPoint {
        CGPoint(x: positionX, y: positionY)
    }

    init(name: String, position: CGPoint, radius: Double) {
        self.id = UUID()
        self.name = name
        self.positionX = position.x
        self.positionY = position.y
        self.radius = radius
        self.monsterSRDIDs = []
        self.monsterCounts = []
        self.triggerType = "enter"
        self.persistent = false
        self.active = true
    }
}

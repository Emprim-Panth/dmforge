import Foundation
import SwiftData

@Model
final class Campaign {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var gmNotes: String

    // Relationships
    @Relationship(deleteRule: .cascade) var party: [PlayerCharacter]
    @Relationship(deleteRule: .cascade) var npcs: [NPC]
    @Relationship(deleteRule: .cascade) var enemies: [Enemy]
    @Relationship(deleteRule: .cascade) var fallen: [FallenHero]
    @Relationship(deleteRule: .cascade) var places: [Place]
    @Relationship(deleteRule: .cascade) var sessions: [StorySession]
    @Relationship(deleteRule: .cascade) var encounterZones: [EncounterZone]

    // Map image (stored as raw Data)
    @Attribute(.externalStorage) var mapImageData: Data?

    // SRD bookmarks (stored as srd_id strings)
    var monsterRoster: [String]
    var spellList: [String]
    var itemVault: [String]

    // Travel path
    var travelStops: [TravelStop]
    var travelSegments: [TravelSegment]

    // Map stamps and text labels
    var mapStamps: [MapStamp]
    var mapTextLabels: [MapTextLabel]
    var mapBorders: [MapBorder]
    var mapDrawings: [MapDrawing]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.updatedAt = .now
        self.gmNotes = ""
        self.party = []
        self.npcs = []
        self.enemies = []
        self.fallen = []
        self.places = []
        self.sessions = []
        self.encounterZones = []
        self.monsterRoster = []
        self.spellList = []
        self.itemVault = []
        self.travelStops = []
        self.travelSegments = []
        self.mapStamps = []
        self.mapTextLabels = []
        self.mapBorders = []
        self.mapDrawings = []
    }
}

// MARK: - Travel Path (codable structs stored as JSON in Campaign)

struct TravelStop: Codable, Identifiable {
    var id: UUID = UUID()
    var position: CGPoint
    var name: String
    var session: String
    var date: String
    var placeID: UUID?
}

struct TravelSegment: Codable, Identifiable {
    var id: UUID = UUID()
    var fromStopIndex: Int
    var toStopIndex: Int
    var waypoints: [CGPoint]
    var session: String
}

// MARK: - Map Stamps

struct MapStamp: Codable, Identifiable {
    var id: UUID = UUID()
    var type: String       // "mountain", "forest", "water", "settlement", "castle", "hills", "swamp", "desert", "plains", "landmark"
    var variant: Int = 0   // variant index within type
    var x: Double          // normalized 0...1
    var y: Double          // normalized 0...1
    var size: Double = 40  // base size in points (scales with zoom)
    var label: String?
    var rotation: Double = 0  // radians
}

// MARK: - Map Borders

struct MapBorder: Codable, Identifiable {
    var id: UUID = UUID()
    var points: [CGPoint]  // normalized 0...1
    var color: String = "border"  // border, river, road
    var style: String = "dashed"  // solid, dashed, dotted
}

// MARK: - Map Freehand Drawings

struct MapDrawing: Codable, Identifiable {
    var id: UUID = UUID()
    var points: [CGPoint]  // normalized 0...1
    var lineWidth: Double = 2.0
    var color: String = "ink"  // ink, blue, green, red
}

// MARK: - Map Text Labels

struct MapTextLabel: Codable, Identifiable {
    var id: UUID = UUID()
    var text: String
    var x: Double  // normalized 0...1
    var y: Double  // normalized 0...1
}

extension CGPoint: @retroactive Codable {
    // Already codable in Foundation
}

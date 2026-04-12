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

    // SRD bookmarks (stored as srd_id strings)
    var monsterRoster: [String]
    var spellList: [String]
    var itemVault: [String]

    // Travel path
    var travelStops: [TravelStop]
    var travelSegments: [TravelSegment]

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

extension CGPoint: @retroactive Codable {
    // Already codable in Foundation
}

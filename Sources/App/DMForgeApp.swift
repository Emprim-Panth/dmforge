import SwiftUI
import SwiftData

@main
struct DMForgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Campaign.self,
            PlayerCharacter.self,
            NPC.self,
            Enemy.self,
            Place.self,
            FallenHero.self,
            StorySession.self,
            EncounterZone.self,
        ])
    }
}

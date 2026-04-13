import SwiftUI
import Observation

/// Coordinates navigation between Dashboard tabs (Places <-> Map bidirectional linking)
@Observable
final class NavigationCoordinator {
    /// Place to highlight/zoom to on the map when switching from Places -> Map
    var showPlaceOnMap: Place?

    /// Place to filter in Places tab when switching from Map -> Places
    var showPlaceInList: Place?

    /// Request to switch to a specific tab
    var requestedTab: DashboardTab?

    /// Place being created that needs immediate map pinning
    var placeNeedingPin: Place?
}

/// Dashboard tab enum shared across views
enum DashboardTab: String, CaseIterable {
    case encounter = "Encounter"
    case people = "People"
    case places = "Places"
    case story = "Story"
    case bestiary = "Bestiary"
    case map = "Map"
    case notes = "Notes"
    case reference = "Reference"
    case ai = "AI"

    var icon: String {
        switch self {
        case .encounter: return "shield.fill"
        case .people: return "person.3.fill"
        case .places: return "map.fill"
        case .story: return "book.fill"
        case .bestiary: return "pawprint.fill"
        case .map: return "globe.americas.fill"
        case .notes: return "note.text"
        case .reference: return "books.vertical.fill"
        case .ai: return "sparkles"
        }
    }
}

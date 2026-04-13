import SwiftUI
import SwiftData

// MARK: - PlacesView

struct PlacesView: View {
    let campaign: Campaign
    @Environment(\.modelContext) private var modelContext

    @State private var showNewPlace = false
    @State private var editingPlace: Place?

    private var topLevelPlaces: [Place] {
        campaign.places
            .filter { $0.parentID == nil }
            .sorted { $0.name < $1.name }
    }

    private var childrenMap: [UUID: [Place]] {
        var map: [UUID: [Place]] = [:]
        for place in campaign.places {
            if let parentID = place.parentID {
                map[parentID, default: []].append(place)
            }
        }
        // Sort children alphabetically
        for key in map.keys {
            map[key]?.sort { $0.name < $1.name }
        }
        return map
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Places")
                    .font(.title2.bold())
                    .foregroundStyle(DMTheme.accent)
                Spacer()
                Text("\(campaign.places.count) locations")
                    .font(.caption)
                    .foregroundStyle(DMTheme.textDim)
                Button {
                    showNewPlace = true
                } label: {
                    Label("New Place", systemImage: "plus")
                        .font(.subheadline.bold())
                }
                .buttonStyle(DMSmallButtonStyle(color: DMTheme.accentGreen.opacity(0.3)))
                .frame(minHeight: 44)
            }
            .padding(DMTheme.contentPadding)

            ScrollView {
                if campaign.places.isEmpty {
                    DMEmptyStateView(
                        icon: "map",
                        title: "No Locations Yet",
                        message: "Add towns, dungeons, and buildings to track where NPCs and enemies are.",
                        buttonTitle: "New Place",
                        buttonAction: { showNewPlace = true }
                    )
                } else {
                    VStack(spacing: DMTheme.cardSpacing) {
                        ForEach(topLevelPlaces) { place in
                            placeTree(place: place, depth: 0)
                        }
                    }
                    .padding(.horizontal, DMTheme.contentPadding)
                    .padding(.bottom, 20)
                }
            }
        }
        .background(DMTheme.background)
        .sheet(isPresented: $showNewPlace) {
            PlaceFormSheet(campaign: campaign, editingPlace: nil)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingPlace) { place in
            PlaceFormSheet(campaign: campaign, editingPlace: place)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Recursive Tree

    @ViewBuilder
    private func placeTree(place: Place, depth: Int) -> some View {
        placeCard(place: place, depth: depth)

        let children = childrenMap[place.id]
        if let children {
            ForEach(children) { child in
                AnyView(placeTree(place: child, depth: depth + 1))
            }
        }
    }

    // MARK: - Place Card

    private func placeCard(place: Place, depth: Int) -> some View {
        HStack(spacing: 0) {
            if depth > 0 {
                Rectangle()
                    .fill(DMTheme.accent.opacity(0.2))
                    .frame(width: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
            }

            VStack(alignment: .leading, spacing: 8) {
                // Name + type
                HStack {
                    Text("\(place.typeIcon) \(place.name)")
                        .font(.headline)
                        .foregroundStyle(DMTheme.textPrimary)
                    Spacer()
                    Text(place.type.capitalized)
                        .font(.caption)
                        .foregroundStyle(DMTheme.textDim)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DMTheme.detail)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Description
                if !place.desc.isEmpty {
                    Text(place.desc)
                        .font(.subheadline)
                        .foregroundStyle(DMTheme.textSecondary)
                        .lineLimit(3)
                }

                // People here
                let peopleHere = peopleAtPlace(place)
                if !peopleHere.isEmpty {
                    HStack(spacing: 4) {
                        Text("People here:")
                            .font(.caption)
                            .foregroundStyle(DMTheme.textDim)
                        ForEach(peopleHere, id: \.name) { person in
                            Text(person.name)
                                .font(.caption)
                                .foregroundStyle(person.isNPC ? DMTheme.accentBlue : DMTheme.accentRed)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    (person.isNPC ? DMTheme.accentBlue : DMTheme.accentRed).opacity(0.15)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                // Notes
                if !place.notes.isEmpty {
                    Text(String(place.notes.prefix(100)) + (place.notes.count > 100 ? "..." : ""))
                        .font(.caption)
                        .foregroundStyle(DMTheme.textDim)
                        .lineLimit(2)
                }

                // Buttons
                HStack(spacing: 8) {
                    Button("Edit") {
                        editingPlace = place
                    }
                    .buttonStyle(DMSmallButtonStyle(color: DMTheme.card))
                    .frame(minHeight: 44)

                    Button("Remove") {
                        modelContext.delete(place)
                    }
                    .buttonStyle(DMDestructiveButtonStyle())
                }
            }
            .padding(DMTheme.cardPadding)
        }
        .background(DMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DMTheme.cardCornerRadius)
                .stroke(DMTheme.border, lineWidth: 1)
        )
        .shadow(color: DMTheme.cardShadow, radius: 4, y: 2)
        .padding(.leading, CGFloat(depth) * 20)
    }

    // MARK: - People at Place

    private struct PersonAtPlace: Sendable {
        let name: String
        let isNPC: Bool
    }

    private func peopleAtPlace(_ place: Place) -> [PersonAtPlace] {
        var people: [PersonAtPlace] = []
        for npc in campaign.npcs where npc.locationID == place.id {
            people.append(PersonAtPlace(name: npc.name, isNPC: true))
        }
        for enemy in campaign.enemies where enemy.locationID == place.id {
            people.append(PersonAtPlace(name: enemy.name, isNPC: false))
        }
        return people
    }
}

// MARK: - Place Form Sheet (New + Edit)

struct PlaceFormSheet: View {
    let campaign: Campaign
    let editingPlace: Place?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var placeType = "Town"
    @State private var parentID: UUID?
    @State private var desc = ""
    @State private var notes = ""

    private let placeTypes = ["Town", "City", "Village", "Dungeon", "Building", "Wilderness", "Tavern", "Temple"]

    private var isEditing: Bool { editingPlace != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $placeType) {
                        ForEach(placeTypes, id: \.self) { Text($0) }
                    }
                    Picker("Inside", selection: $parentID) {
                        Text("(top level)").tag(nil as UUID?)
                        ForEach(campaign.places.sorted(by: { $0.name < $1.name })) { place in
                            if place.id != editingPlace?.id {
                                Text(place.name).tag(place.id as UUID?)
                            }
                        }
                    }
                }

                Section("Description") {
                    TextField("Short description", text: $desc, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DMTheme.background)
            .navigationTitle(isEditing ? "Edit Place" : "New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        savePlace()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let place = editingPlace {
                    name = place.name
                    placeType = place.type.capitalized
                    parentID = place.parentID
                    desc = place.desc
                    notes = place.notes
                }
            }
        }
    }

    private func savePlace() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let place = editingPlace {
            place.name = trimmed
            place.type = placeType.lowercased()
            place.parentID = parentID
            place.desc = desc
            place.notes = notes
        } else {
            let place = Place(name: trimmed, type: placeType.lowercased())
            place.parentID = parentID
            place.desc = desc
            place.notes = notes
            place.campaign = campaign
            modelContext.insert(place)
        }
    }
}

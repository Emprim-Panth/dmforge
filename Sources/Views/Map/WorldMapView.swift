import SwiftUI
import SwiftData
import PhotosUI

struct WorldMapView: View {
    @Bindable var campaign: Campaign
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var isDMView = true
    @State private var isAddingPin = false
    @State private var pendingPinPosition: CGPoint?
    @State private var showPlacePicker = false
    @State private var selectedPinPlace: Place?
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            DMTheme.background.ignoresSafeArea()

            if campaign.mapImageData != nil {
                mapContentView
            } else {
                emptyStateView
            }
        }
        .toolbar {
            if campaign.mapImageData != nil {
                toolbarItems
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onChange(of: selectedPhoto) { _, newValue in
            Task { await loadPhoto(newValue) }
        }
        .sheet(isPresented: $showPlacePicker) {
            placePickerSheet
        }
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContentView: some View {
        GeometryReader { geo in
            let mapImage = UIImage(data: campaign.mapImageData!)!
            let imageSize = mapImage.size

            ZStack {
                Image(uiImage: mapImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        GeometryReader { imageGeo in
                            ZStack {
                                // Travel path
                                travelPathOverlay(in: imageGeo.size)

                                // Encounter zones (DM view only)
                                if isDMView {
                                    encounterZoneOverlay(in: imageGeo.size)
                                }

                                // Location pins
                                pinOverlay(in: imageGeo.size)

                                // Pending pin placement
                                if isAddingPin, let pos = pendingPinPosition {
                                    pinMarker(emoji: "📍", label: "New Pin")
                                        .position(x: pos.x * imageGeo.size.width,
                                                  y: pos.y * imageGeo.size.height)
                                }
                            }
                        }
                    }
                    .onTapGesture { location in
                        // Only used during pin placement — handled via coordinateSpace below
                    }
            }
            .scaleEffect(zoom)
            .offset(offset)
            .gesture(dragGesture)
            .gesture(magnificationGesture)
            .overlay {
                // Invisible tap target for pin placement
                if isAddingPin {
                    GeometryReader { tapGeo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let normalized = CGPoint(
                                    x: location.x / tapGeo.size.width,
                                    y: location.y / tapGeo.size.height
                                )
                                pendingPinPosition = normalized
                                showPlacePicker = true
                            }
                    }
                }
            }
        }
    }

    // MARK: - Overlays

    @ViewBuilder
    private func pinOverlay(in size: CGSize) -> some View {
        ForEach(campaign.places.filter { $0.mapX != nil && $0.mapY != nil }) { place in
            pinMarker(emoji: place.typeIcon, label: place.name)
                .position(
                    x: (place.mapX ?? 0) * size.width,
                    y: (place.mapY ?? 0) * size.height
                )
                .onTapGesture {
                    selectedPinPlace = (selectedPinPlace?.id == place.id) ? nil : place
                }
                .overlay {
                    if selectedPinPlace?.id == place.id {
                        pinPopover(for: place)
                            .position(
                                x: (place.mapX ?? 0) * size.width,
                                y: (place.mapY ?? 0) * size.height - 50
                            )
                    }
                }
        }
    }

    @ViewBuilder
    private func encounterZoneOverlay(in size: CGSize) -> some View {
        ForEach(campaign.encounterZones.filter { $0.active }) { zone in
            Circle()
                .fill(DMTheme.accentRed.opacity(0.2))
                .stroke(DMTheme.accentRed.opacity(0.5), lineWidth: 2)
                .frame(
                    width: zone.radius * 2 * size.width / 1000,
                    height: zone.radius * 2 * size.width / 1000
                )
                .position(
                    x: zone.positionX * size.width,
                    y: zone.positionY * size.height
                )
        }
    }

    @ViewBuilder
    private func travelPathOverlay(in size: CGSize) -> some View {
        if !campaign.travelStops.isEmpty {
            Canvas { context, canvasSize in
                let stops = campaign.travelStops
                guard stops.count > 1 else { return }

                var path = Path()
                let first = stops[0].position
                path.move(to: CGPoint(
                    x: first.x * canvasSize.width,
                    y: first.y * canvasSize.height
                ))

                for i in 1..<stops.count {
                    let stop = stops[i].position
                    path.addLine(to: CGPoint(
                        x: stop.x * canvasSize.width,
                        y: stop.y * canvasSize.height
                    ))
                }

                context.stroke(
                    path,
                    with: .color(DMTheme.accent.opacity(0.7)),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Pin Components

    private func pinMarker(emoji: String, label: String) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(DMTheme.accent)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                Text(emoji)
                    .font(.system(size: 18))
            }
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(DMTheme.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(DMTheme.card.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .lineLimit(1)
        }
    }

    private func pinPopover(for place: Place) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name)
                .font(.subheadline.bold())
                .foregroundStyle(DMTheme.accent)
            Text(place.type.capitalized)
                .font(.caption)
                .foregroundStyle(DMTheme.textSecondary)
            if !place.desc.isEmpty {
                Text(place.desc)
                    .font(.caption2)
                    .foregroundStyle(DMTheme.textPrimary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(DMTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(DMTheme.border, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
        .frame(width: 180)
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoom = lastZoom * value.magnification
            }
            .onEnded { value in
                lastZoom = zoom
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 64))
                .foregroundStyle(DMTheme.accent.opacity(0.4))

            Text("World Map")
                .font(.title.bold())
                .foregroundStyle(DMTheme.textPrimary)

            Text("Import your world map from Wonderdraft, Inkarnate, or any image")
                .font(.subheadline)
                .foregroundStyle(DMTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            HStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose from Photos", systemImage: "photo.on.rectangle")
                        .frame(minHeight: 44)
                }
                .buttonStyle(DMButtonStyle(color: DMTheme.card))

                Button {
                    showFileImporter = true
                } label: {
                    Label("Import from Files", systemImage: "folder")
                        .frame(minHeight: 44)
                }
                .buttonStyle(DMButtonStyle(color: DMTheme.card))
            }

            Button {
                // Simple canvas placeholder — basic for now
                createBlankCanvas()
            } label: {
                Label("Or draw your own", systemImage: "pencil.and.outline")
                    .font(.subheadline)
                    .foregroundStyle(DMTheme.accent)
                    .frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                isDMView.toggle()
            } label: {
                Label(isDMView ? "DM View" : "Player View",
                      systemImage: isDMView ? "eye.fill" : "eye.slash.fill")
                    .frame(minHeight: 44)
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                isAddingPin.toggle()
                if !isAddingPin {
                    pendingPinPosition = nil
                }
            } label: {
                Label(isAddingPin ? "Cancel Pin" : "+ Add Pin",
                      systemImage: isAddingPin ? "xmark" : "mappin.and.ellipse")
                    .frame(minHeight: 44)
            }
            .tint(isAddingPin ? DMTheme.accentRed : DMTheme.accent)
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Replace from Photos", systemImage: "photo")
                }
                Button {
                    showFileImporter = true
                } label: {
                    Label("Replace from Files", systemImage: "folder")
                }
                Divider()
                Button(role: .destructive) {
                    campaign.mapImageData = nil
                    zoom = 1.0
                    lastZoom = 1.0
                    offset = .zero
                    lastOffset = .zero
                } label: {
                    Label("Remove Map", systemImage: "trash")
                }
            } label: {
                Label("Map Options", systemImage: "ellipsis.circle")
                    .frame(minHeight: 44)
            }
        }
    }

    // MARK: - Place Picker Sheet

    private var placePickerSheet: some View {
        NavigationStack {
            List {
                ForEach(campaign.places) { place in
                    Button {
                        if let pos = pendingPinPosition {
                            place.mapX = pos.x
                            place.mapY = pos.y
                        }
                        showPlacePicker = false
                        isAddingPin = false
                        pendingPinPosition = nil
                    } label: {
                        HStack {
                            Text(place.typeIcon)
                                .font(.title3)
                            VStack(alignment: .leading) {
                                Text(place.name)
                                    .foregroundStyle(DMTheme.textPrimary)
                                Text(place.type.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(DMTheme.textSecondary)
                            }
                            Spacer()
                            if place.mapX != nil {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(DMTheme.accent)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("Assign Place to Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showPlacePicker = false
                        pendingPinPosition = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Import Handlers

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            campaign.mapImageData = data
            resetViewState()
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? Data(contentsOf: url) {
            campaign.mapImageData = data
            resetViewState()
        }
    }

    private func createBlankCanvas() {
        let size = CGSize(width: 2048, height: 2048)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(DMTheme.background).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            // Grid lines
            UIColor(DMTheme.border).setStroke()
            let gridSpacing: CGFloat = 64
            for x in stride(from: 0, through: size.width, by: gridSpacing) {
                ctx.cgContext.move(to: CGPoint(x: x, y: 0))
                ctx.cgContext.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0, through: size.height, by: gridSpacing) {
                ctx.cgContext.move(to: CGPoint(x: 0, y: y))
                ctx.cgContext.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.cgContext.strokePath()
        }
        campaign.mapImageData = image.pngData()
        resetViewState()
    }

    private func resetViewState() {
        zoom = 1.0
        lastZoom = 1.0
        offset = .zero
        lastOffset = .zero
        selectedPhoto = nil
    }
}

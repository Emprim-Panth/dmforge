import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Stamp Definition

struct StampType: Identifiable {
    let id: String
    let emoji: String
    let label: String

    static let all: [StampType] = [
        StampType(id: "mountain", emoji: "\u{26F0}", label: "Mountain"),
        StampType(id: "forest", emoji: "\u{1F332}", label: "Forest"),
        StampType(id: "water", emoji: "\u{1F4A7}", label: "Water"),
        StampType(id: "town", emoji: "\u{1F3D8}", label: "Town"),
        StampType(id: "castle", emoji: "\u{1F3F0}", label: "Castle"),
        StampType(id: "cave", emoji: "\u{2694}\u{FE0F}", label: "Cave"),
        StampType(id: "camp", emoji: "\u{26FA}", label: "Camp"),
        StampType(id: "road", emoji: "\u{2014}", label: "Road"),
    ]
}

// MARK: - Map Tool Mode

enum MapToolMode: Equatable {
    case none
    case addPin
    case stamp(StampType)
    case textLabel

    static func == (lhs: MapToolMode, rhs: MapToolMode) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none): return true
        case (.addPin, .addPin): return true
        case (.textLabel, .textLabel): return true
        case (.stamp(let a), .stamp(let b)): return a.id == b.id
        default: return false
        }
    }
}

// MARK: - WorldMapView

struct WorldMapView: View {
    @Bindable var campaign: Campaign
    var coordinator: NavigationCoordinator
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var isDMView = true
    @State private var toolMode: MapToolMode = .none
    @State private var pendingPinPosition: CGPoint?
    @State private var showPlacePicker = false
    @State private var selectedPinPlace: Place?
    @State private var zoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showTextLabelInput = false
    @State private var pendingTextLabelPosition: CGPoint?
    @State private var textLabelInput = ""
    @State private var showStampToolbar = false

    private var hasContent: Bool {
        campaign.mapImageData != nil || !campaign.mapStamps.isEmpty || !campaign.mapTextLabels.isEmpty
    }

    var body: some View {
        ZStack {
            DMTheme.background.ignoresSafeArea()

            if hasContent {
                mapContentView
            } else {
                emptyStateView
            }

            // Stamp toolbar overlay at bottom
            if hasContent {
                VStack {
                    Spacer()
                    stampToolbarView
                }
            }
        }
        .toolbar {
            if hasContent {
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
        .alert("Add Label", isPresented: $showTextLabelInput) {
            TextField("Label text", text: $textLabelInput)
            Button("Add") {
                if let pos = pendingTextLabelPosition, !textLabelInput.trimmingCharacters(in: .whitespaces).isEmpty {
                    let label = MapTextLabel(
                        text: textLabelInput.trimmingCharacters(in: .whitespaces),
                        x: pos.x,
                        y: pos.y
                    )
                    campaign.mapTextLabels.append(label)
                }
                textLabelInput = ""
                pendingTextLabelPosition = nil
            }
            Button("Cancel", role: .cancel) {
                textLabelInput = ""
                pendingTextLabelPosition = nil
            }
        } message: {
            Text("Enter a name for this location")
        }
        .onAppear {
            handleCoordinatorOnAppear()
        }
    }

    // MARK: - Coordinator Handling

    private func handleCoordinatorOnAppear() {
        if let place = coordinator.showPlaceOnMap {
            // Zoom/highlight to this place
            selectedPinPlace = place
            if let mx = place.mapX, let my = place.mapY {
                // Center on the place
                zoom = 2.0
                lastZoom = 2.0
                offset = CGSize(
                    width: -(mx - 0.5) * 400,
                    height: -(my - 0.5) * 400
                )
                lastOffset = offset
            }
            coordinator.showPlaceOnMap = nil
        }

        if let place = coordinator.placeNeedingPin {
            // Switch to add-pin mode, pre-selecting this place
            toolMode = .addPin
            coordinator.placeNeedingPin = nil
            // If no map exists yet, create a blank canvas
            if campaign.mapImageData == nil {
                createParchmentCanvas()
                showStampToolbar = true
            }
        }
    }

    // MARK: - Map Content

    @ViewBuilder
    private var mapContentView: some View {
        GeometryReader { geo in
            ZStack {
                if let data = campaign.mapImageData, let mapImage = UIImage(data: data) {
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

                                    // Map stamps
                                    stampOverlay(in: imageGeo.size)

                                    // Text labels
                                    textLabelOverlay(in: imageGeo.size)

                                    // Location pins
                                    pinOverlay(in: imageGeo.size)

                                    // Pending pin placement
                                    if case .addPin = toolMode, let pos = pendingPinPosition {
                                        pinMarker(emoji: "\u{1F4CD}", label: "New Pin")
                                            .position(x: pos.x * imageGeo.size.width,
                                                      y: pos.y * imageGeo.size.height)
                                    }
                                }
                            }
                        }
                } else {
                    // No image but has stamps/labels — show parchment background
                    parchmentBackground
                        .overlay {
                            GeometryReader { imageGeo in
                                ZStack {
                                    stampOverlay(in: imageGeo.size)
                                    textLabelOverlay(in: imageGeo.size)
                                    pinOverlay(in: imageGeo.size)
                                }
                            }
                        }
                }
            }
            .scaleEffect(zoom)
            .offset(offset)
            .gesture(dragGesture)
            .gesture(magnificationGesture)
            .overlay {
                // Invisible tap target for tool interactions
                if toolMode != .none {
                    GeometryReader { tapGeo in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let normalized = CGPoint(
                                    x: location.x / tapGeo.size.width,
                                    y: location.y / tapGeo.size.height
                                )
                                handleMapTap(at: normalized)
                            }
                    }
                }
            }
        }
    }

    // MARK: - Map Tap Handling

    private func handleMapTap(at normalized: CGPoint) {
        switch toolMode {
        case .addPin:
            pendingPinPosition = normalized
            showPlacePicker = true
        case .stamp(let stampType):
            let stamp = MapStamp(
                type: stampType.id,
                x: normalized.x,
                y: normalized.y
            )
            campaign.mapStamps.append(stamp)
        case .textLabel:
            pendingTextLabelPosition = normalized
            showTextLabelInput = true
        case .none:
            break
        }
    }

    // MARK: - Parchment Background

    private var parchmentBackground: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.85, green: 0.78, blue: 0.65),
                        Color(red: 0.82, green: 0.74, blue: 0.60),
                        Color(red: 0.80, green: 0.72, blue: 0.58),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Subtle texture noise
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.brown.opacity(0.05))
            )
            .padding(8)
    }

    // MARK: - Stamp Toolbar

    private var stampToolbarView: some View {
        VStack(spacing: 0) {
            if showStampToolbar {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Pin tool
                        toolButton(
                            emoji: "\u{1F4CD}",
                            label: "Pin",
                            isActive: toolMode == .addPin
                        ) {
                            toolMode = toolMode == .addPin ? .none : .addPin
                        }

                        Divider()
                            .frame(height: 40)

                        // Stamp tools
                        ForEach(StampType.all) { stamp in
                            toolButton(
                                emoji: stamp.emoji,
                                label: stamp.label,
                                isActive: toolMode == .stamp(stamp)
                            ) {
                                toolMode = toolMode == .stamp(stamp) ? .none : .stamp(stamp)
                            }
                        }

                        Divider()
                            .frame(height: 40)

                        // Text label tool
                        toolButton(
                            emoji: "Aa",
                            label: "Label",
                            isActive: toolMode == .textLabel
                        ) {
                            toolMode = toolMode == .textLabel ? .none : .textLabel
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(
                    DMTheme.card.opacity(0.95)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: -2)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Toggle button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showStampToolbar.toggle()
                    if !showStampToolbar {
                        toolMode = .none
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showStampToolbar ? "chevron.down" : "paintbrush.pointed.fill")
                        .font(.caption)
                    Text(showStampToolbar ? "Hide Tools" : "Build Tools")
                        .font(.caption.bold())
                }
                .foregroundStyle(DMTheme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(DMTheme.card.opacity(0.95))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .padding(.bottom, 12)
        }
    }

    private func toolButton(emoji: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title2)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(isActive ? DMTheme.accent : DMTheme.textDim)
            }
            .frame(width: 52, height: 52)
            .background(isActive ? DMTheme.accent.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? DMTheme.accent : Color.clear, lineWidth: 2)
            )
        }
        .frame(minHeight: 44)
    }

    // MARK: - Overlays

    @ViewBuilder
    private func stampOverlay(in size: CGSize) -> some View {
        ForEach(campaign.mapStamps) { stamp in
            VStack(spacing: 1) {
                Text(stamp.emoji)
                    .font(.system(size: 28 / zoom))
                if let label = stamp.label, !label.isEmpty {
                    Text(label)
                        .font(.system(size: 10 / zoom, weight: .semibold))
                        .foregroundStyle(DMTheme.textPrimary)
                        .padding(.horizontal, 4)
                        .background(DMTheme.card.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
            .position(
                x: stamp.x * size.width,
                y: stamp.y * size.height
            )
            .onLongPressGesture {
                // Remove stamp on long press
                campaign.mapStamps.removeAll { $0.id == stamp.id }
            }
        }
    }

    @ViewBuilder
    private func textLabelOverlay(in size: CGSize) -> some View {
        ForEach(campaign.mapTextLabels) { label in
            Text(label.text)
                .font(.system(size: 16 / zoom, weight: .bold, design: .serif))
                .foregroundStyle(Color(red: 0.3, green: 0.2, blue: 0.1))
                .shadow(color: .white.opacity(0.5), radius: 1, y: 1)
                .position(
                    x: label.x * size.width,
                    y: label.y * size.height
                )
                .onLongPressGesture {
                    campaign.mapTextLabels.removeAll { $0.id == label.id }
                }
        }
    }

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

            Button {
                coordinator.showPlaceInList = place
                coordinator.requestedTab = .places
            } label: {
                Label("View in Places", systemImage: "list.bullet")
                    .font(.caption2.bold())
                    .foregroundStyle(DMTheme.accent)
            }
            .frame(minHeight: 36)
            .padding(.top, 2)
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
        VStack(spacing: 28) {
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 64))
                .foregroundStyle(DMTheme.accent.opacity(0.4))

            Text("World Map")
                .font(.title.bold())
                .foregroundStyle(DMTheme.textPrimary)

            Text("Start building your world")
                .font(.subheadline)
                .foregroundStyle(DMTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            // Two prominent options
            HStack(spacing: 20) {
                // Import a Map
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36))
                        .foregroundStyle(DMTheme.accent)

                    Text("Import a Map")
                        .font(.headline)
                        .foregroundStyle(DMTheme.textPrimary)

                    Text("From Wonderdraft, Inkarnate, or any image")
                        .font(.caption)
                        .foregroundStyle(DMTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 160)

                    VStack(spacing: 8) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Photos", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(DMButtonStyle(color: DMTheme.card))

                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Files", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(DMButtonStyle(color: DMTheme.card))
                    }
                    .frame(width: 160)
                }
                .padding(20)
                .background(DMTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DMTheme.border, lineWidth: 1)
                )

                // Build Your Own
                VStack(spacing: 12) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(DMTheme.accentGreen)

                    Text("Build Your Own")
                        .font(.headline)
                        .foregroundStyle(DMTheme.textPrimary)

                    Text("Parchment canvas with stamps, pins, and labels")
                        .font(.caption)
                        .foregroundStyle(DMTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 160)

                    Button {
                        createParchmentCanvas()
                        showStampToolbar = true
                    } label: {
                        Label("Start Building", systemImage: "hammer.fill")
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(DMButtonStyle(color: DMTheme.accentGreen.opacity(0.3)))
                    .frame(width: 160)
                }
                .padding(20)
                .background(DMTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DMTheme.border, lineWidth: 1)
                )
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
                    campaign.mapStamps = []
                    campaign.mapTextLabels = []
                    zoom = 1.0
                    lastZoom = 1.0
                    offset = .zero
                    lastOffset = .zero
                    showStampToolbar = false
                    toolMode = .none
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
                        toolMode = .none
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

    private func createParchmentCanvas() {
        let size = CGSize(width: 2048, height: 2048)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            // Parchment-colored background
            UIColor(red: 0.85, green: 0.78, blue: 0.65, alpha: 1.0).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            // Subtle aged texture with slightly darker edges
            let edgeColor = UIColor(red: 0.75, green: 0.68, blue: 0.55, alpha: 0.3)
            edgeColor.setFill()
            let borderWidth: CGFloat = 40
            ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: borderWidth))
            ctx.fill(CGRect(x: 0, y: size.height - borderWidth, width: size.width, height: borderWidth))
            ctx.fill(CGRect(x: 0, y: 0, width: borderWidth, height: size.height))
            ctx.fill(CGRect(x: size.width - borderWidth, y: 0, width: borderWidth, height: size.height))
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

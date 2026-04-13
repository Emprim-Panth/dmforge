import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Map Tool Mode

enum MapToolMode: Equatable {
    case select
    case stamp
    case draw
    case border
    case text
    case eraser
    case river
    case waterBody

    static func == (lhs: MapToolMode, rhs: MapToolMode) -> Bool {
        switch (lhs, rhs) {
        case (.select, .select), (.stamp, .stamp), (.draw, .draw),
             (.border, .border), (.text, .text), (.eraser, .eraser),
             (.river, .river), (.waterBody, .waterBody):
            return true
        default:
            return false
        }
    }
}

// MARK: - Undo Action

enum MapUndoAction {
    case addStamp(UUID)
    case addBorder(UUID)
    case addDrawing(UUID)
    case addTextLabel(UUID)
    case removeStamp(MapStamp)
    case removeBorder(MapBorder)
    case removeDrawing(MapDrawing)
    case removeTextLabel(MapTextLabel)
    case addRiver(UUID)
    case addWaterBody(UUID)
    case removeRiver(MapRiver)
    case removeWaterBody(MapWaterBody)
}

// MARK: - WorldMapView

struct WorldMapView: View {
    @Bindable var campaign: Campaign
    var coordinator: NavigationCoordinator
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var isDMView = true
    @State private var toolMode: MapToolMode = .select
    @State private var pendingPinPosition: CGPoint?
    @State private var showPlacePicker = false
    @State private var selectedPinPlace: Place?

    // Zoom and pan
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    // Stamp picker
    @State private var showStampPicker = false
    @State private var selectedStampType: InkStampType?

    // Freehand drawing state
    @State private var currentDrawPoints: [CGPoint] = []
    @State private var drawLineWidth: Double = 2.0
    @State private var drawColor: String = "ink"

    // Border drawing state
    @State private var currentBorderPoints: [CGPoint] = []
    @State private var borderColor: String = "border"
    @State private var borderStyle: String = "dashed"

    // Text label
    @State private var showTextLabelInput = false
    @State private var pendingTextLabelPosition: CGPoint?
    @State private var textLabelInput = ""

    // Selected stamp for editing
    @State private var selectedStampID: UUID?

    // River drawing state
    @State private var currentRiverPoints: [CGPoint] = []
    @State private var riverPreset: String = "river"  // creek, stream, river, major

    // Water body drawing state
    @State private var currentWaterBodyPoints: [CGPoint] = []

    // Undo stack
    @State private var undoStack: [MapUndoAction] = []

    // Map dimensions for canvas
    private let mapWidth: CGFloat = 2048
    private let mapHeight: CGFloat = 2048

    private var hasContent: Bool {
        campaign.mapImageData != nil || !campaign.mapStamps.isEmpty ||
        !campaign.mapTextLabels.isEmpty || !campaign.mapBorders.isEmpty ||
        !campaign.mapDrawings.isEmpty || !campaign.mapRivers.isEmpty ||
        !campaign.mapWaterBodies.isEmpty
    }

    var body: some View {
        ZStack {
            DMTheme.background.ignoresSafeArea()

            if hasContent {
                mapCanvasView
            } else {
                emptyStateView
            }

            // Bottom toolbar
            if hasContent {
                VStack {
                    Spacer()
                    bottomToolbar
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
        .sheet(isPresented: $showStampPicker) {
            stampPickerSheet
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
                    undoStack.append(.addTextLabel(label.id))
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
            selectedPinPlace = place
            if let mx = place.mapX, let my = place.mapY {
                zoomScale = 2.0
                lastZoomScale = 2.0
                panOffset = CGSize(
                    width: -(mx - 0.5) * 400,
                    height: -(my - 0.5) * 400
                )
                lastPanOffset = panOffset
            }
            coordinator.showPlaceOnMap = nil
        }

        if coordinator.placeNeedingPin != nil {
            toolMode = .select
            coordinator.placeNeedingPin = nil
            if campaign.mapImageData == nil && !hasContent {
                createParchmentCanvas()
            }
        }
    }

    // MARK: - Canvas-Based Map View

    @ViewBuilder
    private var mapCanvasView: some View {
        GeometryReader { geo in
            let canvasSize = geo.size

            Canvas { context, size in
                // Apply zoom + pan transform
                let tx = panOffset.width + size.width / 2 * (1 - zoomScale)
                let ty = panOffset.height + size.height / 2 * (1 - zoomScale)

                context.translateBy(x: tx, y: ty)
                context.scaleBy(x: zoomScale, y: zoomScale)

                // Draw parchment background (always, as base layer)
                if campaign.mapImageData == nil {
                    MapRenderer.drawParchmentBackground(context: &context, size: size)
                }

                // Draw imported map image if present
                if let data = campaign.mapImageData, let uiImage = UIImage(data: data) {
                    let image = context.resolve(Image(uiImage: uiImage))
                    context.draw(image, in: CGRect(origin: .zero, size: size))
                }

                // Layer 2: Water bodies (drawn first so everything else is on top)
                for water in campaign.mapWaterBodies {
                    MapRenderer.drawWaterBody(
                        context: &context,
                        water: water,
                        mapSize: size,
                        wobbleSeed: water.id.hashValue
                    )
                }

                // Current water body in progress
                if !currentWaterBodyPoints.isEmpty {
                    let preview = MapWaterBody(coastline: currentWaterBodyPoints)
                    MapRenderer.drawWaterBody(
                        context: &context,
                        water: preview,
                        mapSize: size,
                        wobbleSeed: 999
                    )
                }

                // Draw encounter zones (DM view only)
                if isDMView {
                    drawEncounterZones(context: &context, size: size)
                }

                // Layer 3: Terrain stamps (mountains, hills, forests)
                for stamp in campaign.mapStamps {
                    let mapPoint = CGPoint(x: stamp.x * size.width, y: stamp.y * size.height)
                    let stampSize = stamp.size

                    MapRenderer.draw(
                        stamp.type,
                        variant: stamp.variant,
                        context: &context,
                        at: mapPoint,
                        size: stampSize,
                        seed: stamp.id
                    )

                    // Draw label if present
                    if let label = stamp.label, !label.isEmpty {
                        let labelPoint = CGPoint(x: mapPoint.x, y: mapPoint.y + stampSize * 0.5 + 12)
                        let resolved = context.resolve(
                            Text(label)
                                .font(.system(size: 11, weight: .semibold, design: .serif))
                                .foregroundColor(InkStyle.inkColor)
                        )
                        context.draw(resolved, at: labelPoint, anchor: .top)
                    }

                    // Selection highlight
                    if selectedStampID == stamp.id {
                        var selRect = Path()
                        selRect.addRect(CGRect(
                            x: mapPoint.x - stampSize * 0.5 - 4,
                            y: mapPoint.y - stampSize * 0.5 - 4,
                            width: stampSize + 8,
                            height: stampSize + 8
                        ))
                        context.stroke(selRect, with: .color(DMTheme.accent), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }

                // Layer 4: Rivers (over terrain)
                for river in campaign.mapRivers {
                    MapRenderer.drawRiver(
                        context: &context,
                        river: river,
                        mapSize: size,
                        wobbleSeed: river.id.hashValue
                    )
                }

                // Current river in progress
                if !currentRiverPoints.isEmpty {
                    let (sw, ew) = riverWidths(for: riverPreset)
                    let preview = MapRiver(points: currentRiverPoints, startWidth: sw, endWidth: ew)
                    MapRenderer.drawRiver(
                        context: &context,
                        river: preview,
                        mapSize: size,
                        wobbleSeed: 998
                    )
                }

                // Layer 5: Freehand drawings
                for drawing in campaign.mapDrawings {
                    MapRenderer.drawFreehand(
                        context: &context,
                        points: drawing.points,
                        mapSize: size,
                        lineWidth: drawing.lineWidth * zoomScale,
                        color: drawing.color
                    )
                }

                // Layer 6: Borders
                for border in campaign.mapBorders {
                    MapRenderer.drawBorder(
                        context: &context,
                        points: border.points,
                        mapSize: size,
                        style: border.style,
                        color: border.color,
                        lineWidth: max(1, 2 * zoomScale)
                    )
                }

                // Layer 7: Text labels
                for label in campaign.mapTextLabels {
                    MapRenderer.drawTextLabel(
                        context: &context,
                        text: label.text,
                        at: CGPoint(x: label.x, y: label.y),
                        mapSize: size,
                        fontSize: 16
                    )
                }

                // Layer 8: Location pins
                drawPins(context: &context, size: size)

                // Layer 9: Travel path
                drawTravelPath(context: &context, size: size)

                // Draw current drawing in progress
                if !currentDrawPoints.isEmpty {
                    MapRenderer.drawFreehand(
                        context: &context,
                        points: currentDrawPoints,
                        mapSize: size,
                        lineWidth: drawLineWidth * zoomScale,
                        color: drawColor
                    )
                }

                // Draw current border in progress
                if !currentBorderPoints.isEmpty {
                    MapRenderer.drawBorder(
                        context: &context,
                        points: currentBorderPoints,
                        mapSize: size,
                        style: borderStyle,
                        color: borderColor,
                        lineWidth: max(1, 2 * zoomScale)
                    )
                }
            }
            .gesture(canvasGesture(in: canvasSize))
            .simultaneousGesture(magnificationGesture)
        }
    }

    // MARK: - Canvas Gesture Handling

    private func canvasGesture(in canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let location = value.location
                let normalized = screenToNormalized(location, canvasSize: canvasSize)

                switch toolMode {
                case .select:
                    // Pan the map
                    panOffset = CGSize(
                        width: lastPanOffset.width + value.translation.width,
                        height: lastPanOffset.height + value.translation.height
                    )
                case .stamp:
                    break // handled on tap (onEnded with no translation)
                case .draw:
                    currentDrawPoints.append(normalized)
                case .border:
                    currentBorderPoints.append(normalized)
                case .river:
                    currentRiverPoints.append(normalized)
                case .waterBody:
                    currentWaterBodyPoints.append(normalized)
                case .text:
                    break
                case .eraser:
                    break
                }
            }
            .onEnded { value in
                let location = value.location
                let normalized = screenToNormalized(location, canvasSize: canvasSize)
                let dragDistance = hypot(value.translation.width, value.translation.height)

                switch toolMode {
                case .select:
                    lastPanOffset = panOffset
                    // If it was a tap (minimal drag), check for stamp selection
                    if dragDistance < 10 {
                        handleSelectTap(at: normalized)
                    }
                case .stamp:
                    if dragDistance < 10, let stampType = selectedStampType {
                        let stamp = MapStamp(
                            type: stampType.id,
                            variant: stampType.variant,
                            x: normalized.x,
                            y: normalized.y,
                            size: 40
                        )
                        campaign.mapStamps.append(stamp)
                        undoStack.append(.addStamp(stamp.id))
                    }
                case .draw:
                    if currentDrawPoints.count >= 2 {
                        let simplified = PathSimplifier.simplify(currentDrawPoints, epsilon: 0.003)
                        let drawing = MapDrawing(
                            points: simplified,
                            lineWidth: drawLineWidth,
                            color: drawColor
                        )
                        campaign.mapDrawings.append(drawing)
                        undoStack.append(.addDrawing(drawing.id))
                    }
                    currentDrawPoints = []
                case .border:
                    if currentBorderPoints.count >= 2 {
                        let simplified = PathSimplifier.simplify(currentBorderPoints, epsilon: 0.005)
                        let border = MapBorder(
                            points: simplified,
                            color: borderColor,
                            style: borderStyle
                        )
                        campaign.mapBorders.append(border)
                        undoStack.append(.addBorder(border.id))
                    }
                    currentBorderPoints = []
                case .river:
                    if currentRiverPoints.count >= 2 {
                        let simplified = PathSimplifier.simplify(currentRiverPoints, epsilon: 0.003)
                        let (sw, ew) = riverWidths(for: riverPreset)
                        let river = MapRiver(
                            points: simplified,
                            startWidth: sw,
                            endWidth: ew
                        )
                        campaign.mapRivers.append(river)
                        undoStack.append(.addRiver(river.id))
                    }
                    currentRiverPoints = []
                case .waterBody:
                    if currentWaterBodyPoints.count >= 3 {
                        var simplified = PathSimplifier.simplify(currentWaterBodyPoints, epsilon: 0.003)
                        // Auto-close if start and end are close enough
                        if let first = simplified.first, let last = simplified.last {
                            let dist = hypot(first.x - last.x, first.y - last.y)
                            if dist < 0.05 {
                                simplified[simplified.count - 1] = first
                            } else {
                                simplified.append(first)
                            }
                        }
                        let water = MapWaterBody(coastline: simplified)
                        campaign.mapWaterBodies.append(water)
                        undoStack.append(.addWaterBody(water.id))
                    }
                    currentWaterBodyPoints = []
                case .text:
                    if dragDistance < 10 {
                        pendingTextLabelPosition = normalized
                        showTextLabelInput = true
                    }
                case .eraser:
                    if dragDistance < 10 {
                        handleEraserTap(at: normalized)
                    }
                }
            }
    }

    /// Convert screen coordinates to normalized map coordinates (0...1)
    private func screenToNormalized(_ screenPoint: CGPoint, canvasSize: CGSize) -> CGPoint {
        let tx = panOffset.width + canvasSize.width / 2 * (1 - zoomScale)
        let ty = panOffset.height + canvasSize.height / 2 * (1 - zoomScale)

        let mapX = (screenPoint.x - tx) / (canvasSize.width * zoomScale)
        let mapY = (screenPoint.y - ty) / (canvasSize.height * zoomScale)

        return CGPoint(x: mapX, y: mapY)
    }

    private func handleSelectTap(at normalized: CGPoint) {
        // Find nearest stamp
        let hitRadius: CGFloat = 0.03
        var bestStamp: MapStamp?
        var bestDist: CGFloat = .infinity

        for stamp in campaign.mapStamps {
            let dist = hypot(stamp.x - normalized.x, stamp.y - normalized.y)
            if dist < hitRadius && dist < bestDist {
                bestDist = dist
                bestStamp = stamp
            }
        }

        if let stamp = bestStamp {
            selectedStampID = (selectedStampID == stamp.id) ? nil : stamp.id
        } else {
            selectedStampID = nil
            // Check for pin tap
            for place in campaign.places where place.mapX != nil && place.mapY != nil {
                let dist = hypot((place.mapX ?? 0) - normalized.x, (place.mapY ?? 0) - normalized.y)
                if dist < hitRadius {
                    selectedPinPlace = (selectedPinPlace?.id == place.id) ? nil : place
                    return
                }
            }
            selectedPinPlace = nil
        }
    }

    private func handleEraserTap(at normalized: CGPoint) {
        let hitRadius: CGFloat = 0.03

        // Check stamps
        if let index = campaign.mapStamps.firstIndex(where: { hypot($0.x - normalized.x, $0.y - normalized.y) < hitRadius }) {
            let stamp = campaign.mapStamps.remove(at: index)
            undoStack.append(.removeStamp(stamp))
            return
        }

        // Check text labels
        if let index = campaign.mapTextLabels.firstIndex(where: { hypot($0.x - normalized.x, $0.y - normalized.y) < hitRadius }) {
            let label = campaign.mapTextLabels.remove(at: index)
            undoStack.append(.removeTextLabel(label))
            return
        }

        // Check borders (find nearest point)
        for (bi, border) in campaign.mapBorders.enumerated() {
            for point in border.points {
                if hypot(point.x - normalized.x, point.y - normalized.y) < hitRadius * 1.5 {
                    let removed = campaign.mapBorders.remove(at: bi)
                    undoStack.append(.removeBorder(removed))
                    return
                }
            }
        }

        // Check drawings
        for (di, drawing) in campaign.mapDrawings.enumerated() {
            for point in drawing.points {
                if hypot(point.x - normalized.x, point.y - normalized.y) < hitRadius * 1.5 {
                    let removed = campaign.mapDrawings.remove(at: di)
                    undoStack.append(.removeDrawing(removed))
                    return
                }
            }
        }

        // Check rivers
        for (ri, river) in campaign.mapRivers.enumerated() {
            for point in river.points {
                if hypot(point.x - normalized.x, point.y - normalized.y) < hitRadius * 1.5 {
                    let removed = campaign.mapRivers.remove(at: ri)
                    undoStack.append(.removeRiver(removed))
                    return
                }
            }
        }

        // Check water bodies
        for (wi, water) in campaign.mapWaterBodies.enumerated() {
            for point in water.coastline {
                if hypot(point.x - normalized.x, point.y - normalized.y) < hitRadius * 1.5 {
                    let removed = campaign.mapWaterBodies.remove(at: wi)
                    undoStack.append(.removeWaterBody(removed))
                    return
                }
            }
        }
    }

    // MARK: - Canvas Drawing Helpers

    private func drawTravelPath(context: inout GraphicsContext, size: CGSize) {
        let stops = campaign.travelStops
        guard stops.count > 1 else { return }

        var path = Path()
        let first = stops[0].position
        path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))

        for i in 1..<stops.count {
            let stop = stops[i].position
            path.addLine(to: CGPoint(x: stop.x * size.width, y: stop.y * size.height))
        }

        context.stroke(
            path,
            with: .color(DMTheme.accent.opacity(0.7)),
            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawEncounterZones(context: inout GraphicsContext, size: CGSize) {
        for zone in campaign.encounterZones where zone.active {
            let center = CGPoint(x: zone.positionX * size.width, y: zone.positionY * size.height)
            let radius = zone.radius * size.width / 1000

            var circle = Path()
            circle.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            context.fill(circle, with: .color(DMTheme.accentRed.opacity(0.15)))
            context.stroke(circle, with: .color(DMTheme.accentRed.opacity(0.4)), lineWidth: 2)
        }
    }

    private func drawPins(context: inout GraphicsContext, size: CGSize) {
        for place in campaign.places where place.mapX != nil && place.mapY != nil {
            let center = CGPoint(x: (place.mapX ?? 0) * size.width, y: (place.mapY ?? 0) * size.height)

            // Pin circle
            var pinPath = Path()
            pinPath.addEllipse(in: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24))
            context.fill(pinPath, with: .color(DMTheme.accent))

            // Pin icon text
            let icon = context.resolve(
                Text(place.typeIcon).font(.system(size: 14))
            )
            context.draw(icon, at: center, anchor: .center)

            // Pin label
            let label = context.resolve(
                Text(place.name)
                    .font(.system(size: 10, weight: .bold, design: .serif))
                    .foregroundColor(InkStyle.inkColor)
            )
            context.draw(label, at: CGPoint(x: center.x, y: center.y + 18), anchor: .top)
        }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                zoomScale = lastZoomScale * value.magnification
            }
            .onEnded { _ in
                lastZoomScale = zoomScale
            }
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        VStack(spacing: 8) {
            // Tool-specific options
            if toolMode == .draw {
                drawOptionsBar
            } else if toolMode == .border {
                borderOptionsBar
            } else if toolMode == .river {
                riverOptionsBar
            } else if toolMode == .waterBody {
                waterBodyHintBar
            }

            // Main tool buttons
            HStack(spacing: 4) {
                toolButton(icon: "arrow.up.left.and.arrow.down.right", label: "Select", tool: .select)
                toolButton(icon: "mountain.2", label: "Stamp", tool: .stamp)
                toolButton(icon: "pencil.tip", label: "Draw", tool: .draw)
                toolButton(icon: "line.diagonal", label: "Border", tool: .border)
                toolButton(icon: "water.waves", label: "River", tool: .river)
                toolButton(icon: "drop.fill", label: "Water", tool: .waterBody)
                toolButton(icon: "textformat", label: "Text", tool: .text)
                toolButton(icon: "eraser", label: "Eraser", tool: .eraser)

                Divider()
                    .frame(height: 36)
                    .padding(.horizontal, 4)

                // Pin tool
                Button {
                    pendingPinPosition = nil
                    showPlacePicker = false
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "mappin")
                            .font(.system(size: 18))
                        Text("Pin")
                            .font(.caption2)
                    }
                    .frame(width: 52, height: 52)
                    .foregroundStyle(DMTheme.textDim)
                }
                .frame(minWidth: 44, minHeight: 44)

                Divider()
                    .frame(height: 36)
                    .padding(.horizontal, 4)

                // Undo button
                Button {
                    performUndo()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 18))
                        Text("Undo")
                            .font(.caption2)
                    }
                    .frame(width: 52, height: 52)
                    .foregroundStyle(undoStack.isEmpty ? DMTheme.textDim.opacity(0.3) : DMTheme.textDim)
                }
                .disabled(undoStack.isEmpty)
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                DMTheme.card.opacity(0.95)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: -2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private func toolButton(icon: String, label: String, tool: MapToolMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if toolMode == tool && tool == .stamp {
                    showStampPicker = true
                } else {
                    toolMode = tool
                    if tool == .stamp {
                        showStampPicker = true
                    }
                }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.caption2)
            }
            .frame(width: 52, height: 52)
            .foregroundStyle(toolMode == tool ? DMTheme.accent : DMTheme.textDim)
            .background(toolMode == tool ? DMTheme.accent.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(toolMode == tool ? DMTheme.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .frame(minWidth: 44, minHeight: 44)
    }

    // MARK: - Draw Options Bar

    private var drawOptionsBar: some View {
        HStack(spacing: 12) {
            Text("Width:")
                .font(.caption)
                .foregroundStyle(DMTheme.textSecondary)

            ForEach([1.5, 2.5, 4.0], id: \.self) { width in
                Button {
                    drawLineWidth = width
                } label: {
                    Circle()
                        .fill(drawLineWidth == width ? DMTheme.accent : DMTheme.textDim)
                        .frame(width: CGFloat(width * 4 + 8), height: CGFloat(width * 4 + 8))
                }
                .frame(minWidth: 44, minHeight: 44)
            }

            Divider().frame(height: 24)

            Text("Color:")
                .font(.caption)
                .foregroundStyle(DMTheme.textSecondary)

            ForEach(["ink", "blue", "green", "red"], id: \.self) { color in
                let displayColor: Color = switch color {
                case "blue": InkStyle.borderBlue
                case "green": InkStyle.drawGreen
                case "red": InkStyle.borderRed
                default: InkStyle.inkColor
                }
                Button {
                    drawColor = color
                } label: {
                    Circle()
                        .fill(displayColor)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(drawColor == color ? DMTheme.accent : Color.clear, lineWidth: 2)
                                .padding(-3)
                        )
                }
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(DMTheme.card.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }

    // MARK: - Border Options Bar

    private var borderOptionsBar: some View {
        HStack(spacing: 12) {
            Text("Style:")
                .font(.caption)
                .foregroundStyle(DMTheme.textSecondary)

            ForEach(["dashed", "solid", "dotted"], id: \.self) { style in
                Button {
                    borderStyle = style
                } label: {
                    Text(style.capitalized)
                        .font(.caption.bold())
                        .foregroundStyle(borderStyle == style ? DMTheme.accent : DMTheme.textDim)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(borderStyle == style ? DMTheme.accent.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(minHeight: 44)
            }

            Divider().frame(height: 24)

            Text("Type:")
                .font(.caption)
                .foregroundStyle(DMTheme.textSecondary)

            ForEach(["border", "river", "road"], id: \.self) { color in
                Button {
                    borderColor = color
                } label: {
                    Text(color.capitalized)
                        .font(.caption.bold())
                        .foregroundStyle(borderColor == color ? DMTheme.accent : DMTheme.textDim)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(borderColor == color ? DMTheme.accent.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(DMTheme.card.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }

    // MARK: - River Options Bar

    private var riverOptionsBar: some View {
        HStack(spacing: 12) {
            Text("Width:")
                .font(.caption)
                .foregroundStyle(DMTheme.textSecondary)

            ForEach(["creek", "stream", "river", "major"], id: \.self) { preset in
                Button {
                    riverPreset = preset
                } label: {
                    Text(preset.capitalized)
                        .font(.caption.bold())
                        .foregroundStyle(riverPreset == preset ? DMTheme.accent : DMTheme.textDim)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(riverPreset == preset ? DMTheme.accent.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(DMTheme.card.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }

    // MARK: - Water Body Hint Bar

    private var waterBodyHintBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(DMTheme.accent)
            Text("Draw a closed coastline shape")
                .font(.caption)
                .foregroundStyle(DMTheme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(DMTheme.card.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }

    // MARK: - River Width Presets

    private func riverWidths(for preset: String) -> (Double, Double) {
        switch preset {
        case "creek": return (1.0, 3.0)
        case "stream": return (2.0, 5.0)
        case "major": return (5.0, 15.0)
        default: return (3.0, 10.0)  // "river"
        }
    }

    // MARK: - Stamp Picker Sheet

    private var stampPickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(StampCategory.allCases) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Label(category.rawValue, systemImage: category.icon)
                                .font(.headline)
                                .foregroundStyle(DMTheme.textPrimary)
                                .padding(.horizontal, 16)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80, maximum: 100))], spacing: 12) {
                                ForEach(InkStampType.stampsFor(category: category), id: \.uniqueID) { stampType in
                                    Button {
                                        selectedStampType = stampType
                                        toolMode = .stamp
                                        showStampPicker = false
                                    } label: {
                                        VStack(spacing: 4) {
                                            // Preview canvas
                                            Canvas { context, size in
                                                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                                                MapRenderer.drawPreview(
                                                    stampType.id,
                                                    variant: stampType.variant,
                                                    context: &context,
                                                    at: center,
                                                    size: min(size.width, size.height) * 0.7
                                                )
                                            }
                                            .frame(width: 60, height: 60)
                                            .background(InkStyle.parchment)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(
                                                        selectedStampType?.uniqueID == stampType.uniqueID ? DMTheme.accent : DMTheme.border,
                                                        lineWidth: selectedStampType?.uniqueID == stampType.uniqueID ? 2 : 1
                                                    )
                                            )

                                            Text(stampType.variantLabel)
                                                .font(.caption2)
                                                .foregroundStyle(DMTheme.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(DMTheme.background)
            .navigationTitle("Map Stamps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showStampPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Undo

    private func performUndo() {
        guard let action = undoStack.popLast() else { return }
        switch action {
        case .addStamp(let id):
            campaign.mapStamps.removeAll { $0.id == id }
        case .addBorder(let id):
            campaign.mapBorders.removeAll { $0.id == id }
        case .addDrawing(let id):
            campaign.mapDrawings.removeAll { $0.id == id }
        case .addTextLabel(let id):
            campaign.mapTextLabels.removeAll { $0.id == id }
        case .removeStamp(let stamp):
            campaign.mapStamps.append(stamp)
        case .removeBorder(let border):
            campaign.mapBorders.append(border)
        case .removeDrawing(let drawing):
            campaign.mapDrawings.append(drawing)
        case .removeTextLabel(let label):
            campaign.mapTextLabels.append(label)
        case .addRiver(let id):
            campaign.mapRivers.removeAll { $0.id == id }
        case .addWaterBody(let id):
            campaign.mapWaterBodies.removeAll { $0.id == id }
        case .removeRiver(let river):
            campaign.mapRivers.append(river)
        case .removeWaterBody(let water):
            campaign.mapWaterBodies.append(water)
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

                    Text("Parchment canvas with ink stamps, borders, and labels")
                        .font(.caption)
                        .foregroundStyle(DMTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 160)

                    Button {
                        createParchmentCanvas()
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

    // MARK: - Navigation Toolbar

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
                    campaign.mapBorders = []
                    campaign.mapDrawings = []
                    campaign.mapRivers = []
                    campaign.mapWaterBodies = []
                    zoomScale = 1.0
                    lastZoomScale = 1.0
                    panOffset = .zero
                    lastPanOffset = .zero
                    toolMode = .select
                    undoStack = []
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
                        toolMode = .select
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
        // No image data needed — Canvas draws parchment directly
        // But we need at least one stamp/label to trigger hasContent
        // Use a nil mapImageData and just set the flag by adding nothing — hasContent checks mapImageData
        // Actually, let's keep the image approach for backward compat but with the proper parchment color
        let size = CGSize(width: 2048, height: 2048)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            UIColor(red: 0.957, green: 0.894, blue: 0.757, alpha: 1.0).setFill()  // #f4e4c1
            ctx.fill(CGRect(origin: .zero, size: size))

            // Vignette edges
            let edgeColor = UIColor(red: 0.6, green: 0.5, blue: 0.35, alpha: 0.15)
            edgeColor.setFill()
            let borderWidth: CGFloat = 60
            ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: borderWidth))
            ctx.fill(CGRect(x: 0, y: size.height - borderWidth, width: size.width, height: borderWidth))
            ctx.fill(CGRect(x: 0, y: 0, width: borderWidth, height: size.height))
            ctx.fill(CGRect(x: size.width - borderWidth, y: 0, width: borderWidth, height: size.height))
        }
        campaign.mapImageData = image.pngData()
        resetViewState()
    }

    private func resetViewState() {
        zoomScale = 1.0
        lastZoomScale = 1.0
        panOffset = .zero
        lastPanOffset = .zero
        selectedPhoto = nil
    }
}

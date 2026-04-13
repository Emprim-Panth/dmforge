import SwiftUI

// MARK: - Ink Style Constants

enum InkStyle {
    static let inkColor = Color(hex: "3d2b1f")
    static let lightInk = Color(hex: "5a4030")
    static let parchment = Color(hex: "f4e4c1")
    static let parchmentDark = Color(hex: "d4c4a1")
    static let borderBlue = Color(hex: "3a5a8a")
    static let borderRed = Color(hex: "8a3a3a")
    static let drawGreen = Color(hex: "3a6a3a")

    // Shading aliases (use inkColor/lightInk directly)
}

// MARK: - Seeded Random

/// Deterministic random based on stamp ID so wobble is consistent
struct SeededRandom {
    private var state: UInt64

    init(seed: UUID) {
        let bytes = withUnsafeBytes(of: seed.uuid) { Array($0) }
        state = bytes.withUnsafeBytes { $0.load(as: UInt64.self) }
        if state == 0 { state = 1 }
    }

    mutating func next() -> Double {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 10000) / 10000.0
    }

    /// Random offset for wobble, range +-amount
    mutating func wobble(_ amount: CGFloat = 1.5) -> CGFloat {
        CGFloat(next() * 2 - 1) * amount
    }
}

// MARK: - Stamp Category + Type Definitions

enum StampCategory: String, CaseIterable, Identifiable {
    case terrain = "Terrain"
    case settlements = "Settlements"
    case nature = "Nature"
    case water = "Water"
    case landmarks = "Landmarks"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .terrain: return "mountain.2"
        case .settlements: return "building.2"
        case .nature: return "leaf"
        case .water: return "drop"
        case .landmarks: return "mappin"
        }
    }
}

struct InkStampType: Identifiable, Equatable {
    let id: String
    let label: String
    let category: StampCategory
    let variant: Int
    let variantLabel: String

    static func == (lhs: InkStampType, rhs: InkStampType) -> Bool {
        lhs.id == rhs.id && lhs.variant == rhs.variant
    }

    static let all: [InkStampType] = {
        var stamps: [InkStampType] = []

        // Mountains (4 variants)
        stamps.append(InkStampType(id: "mountain", label: "Mountain", category: .terrain, variant: 0, variantLabel: "Single Peak"))
        stamps.append(InkStampType(id: "mountain", label: "Mountain", category: .terrain, variant: 1, variantLabel: "Double Peak"))
        stamps.append(InkStampType(id: "mountain", label: "Mountain", category: .terrain, variant: 2, variantLabel: "Range"))
        stamps.append(InkStampType(id: "mountain", label: "Mountain", category: .terrain, variant: 3, variantLabel: "Snow-capped"))

        // Hills (4 variants)
        stamps.append(InkStampType(id: "hills", label: "Hills", category: .terrain, variant: 0, variantLabel: "Rolling"))
        stamps.append(InkStampType(id: "hills", label: "Hills", category: .terrain, variant: 1, variantLabel: "Steep"))
        stamps.append(InkStampType(id: "hills", label: "Hills", category: .terrain, variant: 2, variantLabel: "Terraced"))
        stamps.append(InkStampType(id: "hills", label: "Hills", category: .terrain, variant: 3, variantLabel: "Barren"))

        // Swamp
        stamps.append(InkStampType(id: "swamp", label: "Swamp", category: .terrain, variant: 0, variantLabel: "Marsh"))

        // Desert
        stamps.append(InkStampType(id: "desert", label: "Desert", category: .terrain, variant: 0, variantLabel: "Dunes"))

        // Plains
        stamps.append(InkStampType(id: "plains", label: "Plains", category: .terrain, variant: 0, variantLabel: "Grassland"))

        // Trees/Forest (5 variants)
        stamps.append(InkStampType(id: "forest", label: "Forest", category: .nature, variant: 0, variantLabel: "Deciduous"))
        stamps.append(InkStampType(id: "forest", label: "Forest", category: .nature, variant: 1, variantLabel: "Conifer"))
        stamps.append(InkStampType(id: "forest", label: "Forest", category: .nature, variant: 2, variantLabel: "Forest Cluster"))
        stamps.append(InkStampType(id: "forest", label: "Forest", category: .nature, variant: 3, variantLabel: "Dead Tree"))
        stamps.append(InkStampType(id: "forest", label: "Forest", category: .nature, variant: 4, variantLabel: "Palm"))

        // Settlements (6 variants)
        stamps.append(InkStampType(id: "settlement", label: "Settlement", category: .settlements, variant: 0, variantLabel: "Camp"))
        stamps.append(InkStampType(id: "settlement", label: "Settlement", category: .settlements, variant: 1, variantLabel: "Village"))
        stamps.append(InkStampType(id: "settlement", label: "Settlement", category: .settlements, variant: 2, variantLabel: "Small Town"))
        stamps.append(InkStampType(id: "settlement", label: "Settlement", category: .settlements, variant: 3, variantLabel: "Large Town"))
        stamps.append(InkStampType(id: "settlement", label: "Settlement", category: .settlements, variant: 4, variantLabel: "City"))
        stamps.append(InkStampType(id: "settlement", label: "Settlement", category: .settlements, variant: 5, variantLabel: "Ruins"))

        // Castles (4 variants)
        stamps.append(InkStampType(id: "castle", label: "Castle", category: .settlements, variant: 0, variantLabel: "Tower"))
        stamps.append(InkStampType(id: "castle", label: "Castle", category: .settlements, variant: 1, variantLabel: "Keep"))
        stamps.append(InkStampType(id: "castle", label: "Castle", category: .settlements, variant: 2, variantLabel: "Fortress"))
        stamps.append(InkStampType(id: "castle", label: "Castle", category: .settlements, variant: 3, variantLabel: "Ruined Castle"))

        // Water (3 variants)
        stamps.append(InkStampType(id: "water", label: "Water", category: .water, variant: 0, variantLabel: "Lake"))
        stamps.append(InkStampType(id: "water", label: "Water", category: .water, variant: 1, variantLabel: "River"))
        stamps.append(InkStampType(id: "water", label: "Water", category: .water, variant: 2, variantLabel: "Coast"))

        // Landmarks (4 variants)
        stamps.append(InkStampType(id: "landmark", label: "Landmark", category: .landmarks, variant: 0, variantLabel: "Bridge"))
        stamps.append(InkStampType(id: "landmark", label: "Landmark", category: .landmarks, variant: 1, variantLabel: "Shrine"))
        stamps.append(InkStampType(id: "landmark", label: "Landmark", category: .landmarks, variant: 2, variantLabel: "Mine"))
        stamps.append(InkStampType(id: "landmark", label: "Landmark", category: .landmarks, variant: 3, variantLabel: "Cave"))

        return stamps
    }()

    static func stampsFor(category: StampCategory) -> [InkStampType] {
        all.filter { $0.category == category }
    }

    /// Unique key for picker identification
    var uniqueID: String { "\(id)_\(variant)" }
}

// MARK: - MapRenderer

/// Draws all ink-style map stamps using SwiftUI Canvas paths.
/// Every drawing function uses seeded randomness so wobble is deterministic per stamp.
enum MapRenderer {

    // MARK: - Main Entry Point

    static func draw(
        _ type: String,
        variant: Int,
        context: inout GraphicsContext,
        at point: CGPoint,
        size: CGFloat,
        seed: UUID
    ) {
        var rng = SeededRandom(seed: seed)
        let lw = max(1.0, size * 0.04)

        switch type {
        case "mountain":
            drawMountain(context: &context, at: point, size: size, variant: variant, lineWidth: lw, rng: &rng)
        case "hills":
            drawHills(context: &context, at: point, size: size, variant: variant, lineWidth: lw, rng: &rng)
        case "swamp":
            drawSwamp(context: &context, at: point, size: size, lineWidth: lw, rng: &rng)
        case "desert":
            drawDesert(context: &context, at: point, size: size, lineWidth: lw, rng: &rng)
        case "plains":
            drawPlains(context: &context, at: point, size: size, lineWidth: lw, rng: &rng)
        case "forest":
            drawForest(context: &context, at: point, size: size, variant: variant, lineWidth: lw, rng: &rng)
        case "settlement":
            drawSettlement(context: &context, at: point, size: size, variant: variant, lineWidth: lw, rng: &rng)
        case "castle":
            drawCastle(context: &context, at: point, size: size, variant: variant, lineWidth: lw, rng: &rng)
        case "water":
            drawWater(context: &context, at: point, size: size, variant: variant, lineWidth: lw, rng: &rng)
        case "landmark":
            drawLandmark(context: &context, at: point, size: size, variant: variant, lineWidth: lw, rng: &rng)
        default:
            drawFallbackDot(context: &context, at: point, size: size, lineWidth: lw)
        }
    }

    /// Draw a small preview for the stamp picker (no seed needed, uses fixed rng)
    static func drawPreview(
        _ type: String,
        variant: Int,
        context: inout GraphicsContext,
        at point: CGPoint,
        size: CGFloat
    ) {
        let fixedSeed = UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
        draw(type, variant: variant, context: &context, at: point, size: size, seed: fixedSeed)
    }

    // MARK: - Wobble Line Helper

    /// Draw a line between two points with hand-drawn wobble
    private static func wobbleLine(
        from p1: CGPoint,
        to p2: CGPoint,
        rng: inout SeededRandom,
        wobbleAmount: CGFloat = 1.5
    ) -> Path {
        var path = Path()
        let steps = max(3, Int(hypot(p2.x - p1.x, p2.y - p1.y) / 4))
        path.move(to: CGPoint(x: p1.x + rng.wobble(wobbleAmount * 0.3), y: p1.y + rng.wobble(wobbleAmount * 0.3)))
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = p1.x + (p2.x - p1.x) * t + rng.wobble(wobbleAmount)
            let y = p1.y + (p2.y - p1.y) * t + rng.wobble(wobbleAmount)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }

    /// Draw cross-hatching in a triangular region for shadow
    private static func drawCrossHatch(
        context: inout GraphicsContext,
        from topLeft: CGPoint,
        to bottomRight: CGPoint,
        lineWidth: CGFloat,
        rng: inout SeededRandom,
        density: Int = 4
    ) {
        let dx = bottomRight.x - topLeft.x
        let dy = bottomRight.y - topLeft.y
        for i in 0..<density {
            let t = CGFloat(i + 1) / CGFloat(density + 1)
            let startX = topLeft.x + dx * t + rng.wobble(1)
            let startY = topLeft.y + rng.wobble(1)
            let endX = startX + dx * 0.15 + rng.wobble(1)
            let endY = topLeft.y + dy * t + rng.wobble(1)
            let line = wobbleLine(from: CGPoint(x: startX, y: startY), to: CGPoint(x: endX, y: endY), rng: &rng, wobbleAmount: 0.5)
            context.stroke(line, with: .color(InkStyle.lightInk), lineWidth: lineWidth * 0.5)
        }
    }

    // MARK: - Mountain Variants

    private static func drawMountain(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, variant: Int, lineWidth: CGFloat, rng: inout SeededRandom) {
        switch variant {
        case 1: drawDoublePeak(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 2: drawMountainRange(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 3: drawSnowCapped(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        default: drawSinglePeak(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        }
    }

    private static func drawSinglePeak(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        let peak = CGPoint(x: p.x + rng.wobble(1), y: p.y - size * 0.45)
        let left = CGPoint(x: p.x - size * 0.35 + rng.wobble(1.5), y: p.y + size * 0.2)
        let right = CGPoint(x: p.x + size * 0.35 + rng.wobble(1.5), y: p.y + size * 0.2)

        let leftSlope = wobbleLine(from: peak, to: left, rng: &rng)
        let rightSlope = wobbleLine(from: peak, to: right, rng: &rng)

        context.stroke(leftSlope, with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        context.stroke(rightSlope, with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Cross-hatch on left (shadow) side
        drawCrossHatch(context: &context, from: CGPoint(x: p.x - size * 0.15, y: p.y - size * 0.25), to: CGPoint(x: p.x - size * 0.3, y: p.y + size * 0.15), lineWidth: lineWidth, rng: &rng, density: 3)
    }

    private static func drawDoublePeak(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Left peak (taller)
        let peak1 = CGPoint(x: p.x - size * 0.15 + rng.wobble(1), y: p.y - size * 0.45)
        let left1 = CGPoint(x: p.x - size * 0.45 + rng.wobble(1), y: p.y + size * 0.2)
        let saddle = CGPoint(x: p.x + rng.wobble(1), y: p.y - size * 0.15)

        context.stroke(wobbleLine(from: peak1, to: left1, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        context.stroke(wobbleLine(from: peak1, to: saddle, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Right peak (shorter)
        let peak2 = CGPoint(x: p.x + size * 0.2 + rng.wobble(1), y: p.y - size * 0.3)
        let right2 = CGPoint(x: p.x + size * 0.45 + rng.wobble(1), y: p.y + size * 0.2)

        context.stroke(wobbleLine(from: saddle, to: peak2, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        context.stroke(wobbleLine(from: peak2, to: right2, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        drawCrossHatch(context: &context, from: CGPoint(x: p.x - size * 0.2, y: p.y - size * 0.25), to: CGPoint(x: p.x - size * 0.4, y: p.y + size * 0.15), lineWidth: lineWidth, rng: &rng, density: 4)
    }

    private static func drawMountainRange(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Three peaks in a row
        let offsets: [(dx: CGFloat, dy: CGFloat, h: CGFloat)] = [
            (-0.3, 0, 0.35), (0, -0.05, 0.45), (0.3, 0.02, 0.3)
        ]
        for off in offsets {
            let base = CGPoint(x: p.x + size * off.dx, y: p.y + size * 0.2 + size * off.dy)
            let peak = CGPoint(x: base.x + rng.wobble(1), y: base.y - size * off.h)
            let left = CGPoint(x: base.x - size * 0.18 + rng.wobble(1), y: base.y)
            let right = CGPoint(x: base.x + size * 0.18 + rng.wobble(1), y: base.y)
            context.stroke(wobbleLine(from: peak, to: left, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
            context.stroke(wobbleLine(from: peak, to: right, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        }
        drawCrossHatch(context: &context, from: CGPoint(x: p.x - size * 0.05, y: p.y - size * 0.2), to: CGPoint(x: p.x - size * 0.15, y: p.y + size * 0.15), lineWidth: lineWidth, rng: &rng, density: 3)
    }

    private static func drawSnowCapped(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Draw normal peak first
        drawSinglePeak(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)

        // Snow cap: white fill at top
        var snowPath = Path()
        let peak = CGPoint(x: p.x, y: p.y - size * 0.45)
        let snowLeft = CGPoint(x: p.x - size * 0.12, y: p.y - size * 0.25)
        let snowRight = CGPoint(x: p.x + size * 0.12, y: p.y - size * 0.25)
        snowPath.move(to: peak)
        snowPath.addLine(to: snowLeft)
        // Jagged snow line
        snowPath.addLine(to: CGPoint(x: p.x - size * 0.06 + rng.wobble(1), y: p.y - size * 0.28))
        snowPath.addLine(to: CGPoint(x: p.x + rng.wobble(1), y: p.y - size * 0.23))
        snowPath.addLine(to: CGPoint(x: p.x + size * 0.06 + rng.wobble(1), y: p.y - size * 0.27))
        snowPath.addLine(to: snowRight)
        snowPath.closeSubpath()
        context.fill(snowPath, with: .color(InkStyle.parchment))
        context.stroke(snowPath, with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.6)
    }

    // MARK: - Hills

    private static func drawHills(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, variant: Int, lineWidth: CGFloat, rng: inout SeededRandom) {
        let count = variant == 1 ? 2 : 3
        let baseY = p.y + size * 0.15
        for i in 0..<count {
            let cx = p.x + CGFloat(i - count / 2) * size * 0.28 + rng.wobble(2)
            let h = size * (0.2 + rng.next() * 0.1) * (variant == 1 ? 1.3 : 1.0)
            var path = Path()
            path.move(to: CGPoint(x: cx - size * 0.18, y: baseY))
            path.addQuadCurve(
                to: CGPoint(x: cx + size * 0.18, y: baseY),
                control: CGPoint(x: cx + rng.wobble(2), y: baseY - h)
            )
            context.stroke(path, with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        }
        // Hatching on variant 3 (terraced)
        if variant == 2 {
            for i in 0..<3 {
                let y = baseY - size * CGFloat(i + 1) * 0.06
                let line = wobbleLine(
                    from: CGPoint(x: p.x - size * 0.12, y: y),
                    to: CGPoint(x: p.x + size * 0.12, y: y),
                    rng: &rng, wobbleAmount: 0.8
                )
                context.stroke(line, with: .color(InkStyle.lightInk), lineWidth: lineWidth * 0.4)
            }
        }
    }

    // MARK: - Swamp

    private static func drawSwamp(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Wavy water lines
        for i in 0..<3 {
            let y = p.y + CGFloat(i - 1) * size * 0.12
            var path = Path()
            path.move(to: CGPoint(x: p.x - size * 0.3, y: y))
            for j in 0..<6 {
                let x = p.x - size * 0.3 + CGFloat(j) * size * 0.12
                let dy = (j % 2 == 0 ? -1.0 : 1.0) * size * 0.04
                path.addLine(to: CGPoint(x: x + rng.wobble(1), y: y + dy + rng.wobble(0.5)))
            }
            context.stroke(path, with: .color(InkStyle.lightInk), lineWidth: lineWidth * 0.5)
        }
        // Reeds
        for _ in 0..<4 {
            let rx = p.x + rng.wobble(size * 0.25)
            let ry = p.y + rng.wobble(size * 0.15)
            let reed = wobbleLine(from: CGPoint(x: rx, y: ry), to: CGPoint(x: rx + rng.wobble(2), y: ry - size * 0.15), rng: &rng, wobbleAmount: 0.5)
            context.stroke(reed, with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.7)
            // Cattail top
            var dot = Path()
            dot.addEllipse(in: CGRect(x: rx - size * 0.02, y: ry - size * 0.17, width: size * 0.04, height: size * 0.06))
            context.fill(dot, with: .color(InkStyle.inkColor))
        }
    }

    // MARK: - Desert

    private static func drawDesert(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Dune curves
        for i in 0..<2 {
            let y = p.y + CGFloat(i) * size * 0.15
            var path = Path()
            let startX = p.x - size * 0.35
            path.move(to: CGPoint(x: startX, y: y))
            path.addQuadCurve(
                to: CGPoint(x: p.x + size * 0.35, y: y + size * 0.05),
                control: CGPoint(x: p.x + rng.wobble(size * 0.1), y: y - size * 0.15)
            )
            context.stroke(path, with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.8)
        }
        // Stipple dots
        for _ in 0..<8 {
            let dx = rng.wobble(size * 0.3)
            let dy = rng.wobble(size * 0.15)
            var dot = Path()
            dot.addEllipse(in: CGRect(x: p.x + dx, y: p.y + dy, width: lineWidth, height: lineWidth))
            context.fill(dot, with: .color(InkStyle.lightInk))
        }
    }

    // MARK: - Plains

    private static func drawPlains(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Grass tufts
        for _ in 0..<5 {
            let bx = p.x + rng.wobble(size * 0.3)
            let by = p.y + rng.wobble(size * 0.15) + size * 0.1
            for j in 0..<3 {
                let angle = CGFloat(j - 1) * 0.3 + rng.wobble(0.1) * .pi
                let tipX = bx + cos(angle - .pi / 2) * size * 0.1
                let tipY = by - sin(angle + .pi / 2) * size * 0.12
                let blade = wobbleLine(from: CGPoint(x: bx, y: by), to: CGPoint(x: tipX, y: tipY), rng: &rng, wobbleAmount: 0.5)
                context.stroke(blade, with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.5)
            }
        }
    }

    // MARK: - Forest Variants

    private static func drawForest(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, variant: Int, lineWidth: CGFloat, rng: inout SeededRandom) {
        switch variant {
        case 1: drawConifer(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 2: drawForestCluster(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 3: drawDeadTree(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 4: drawPalm(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        default: drawDeciduousTree(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        }
    }

    private static func drawDeciduousTree(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Trunk
        let trunkBottom = CGPoint(x: p.x, y: p.y + size * 0.2)
        let trunkTop = CGPoint(x: p.x + rng.wobble(1), y: p.y - size * 0.05)
        context.stroke(wobbleLine(from: trunkBottom, to: trunkTop, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 1.2)

        // Canopy — lumpy circle
        let canopyCenter = CGPoint(x: p.x, y: p.y - size * 0.2)
        let r = size * 0.22
        var canopy = Path()
        let segments = 8
        for i in 0...segments {
            let angle = CGFloat(i) / CGFloat(segments) * .pi * 2
            let rad = r + rng.wobble(r * 0.25)
            let cx = canopyCenter.x + cos(angle) * rad
            let cy = canopyCenter.y + sin(angle) * rad
            if i == 0 { canopy.move(to: CGPoint(x: cx, y: cy)) }
            else { canopy.addLine(to: CGPoint(x: cx, y: cy)) }
        }
        canopy.closeSubpath()
        context.stroke(canopy, with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        // Light fill for texture
        drawCrossHatch(context: &context, from: CGPoint(x: canopyCenter.x - r * 0.5, y: canopyCenter.y - r * 0.5), to: CGPoint(x: canopyCenter.x + r * 0.3, y: canopyCenter.y + r * 0.5), lineWidth: lineWidth, rng: &rng, density: 3)
    }

    private static func drawConifer(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        let trunkBottom = CGPoint(x: p.x, y: p.y + size * 0.2)
        let trunkTop = CGPoint(x: p.x, y: p.y + size * 0.05)
        context.stroke(wobbleLine(from: trunkBottom, to: trunkTop, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Three triangular layers
        let layers: [(yOff: CGFloat, w: CGFloat)] = [
            (0.0, 0.25), (-0.12, 0.2), (-0.24, 0.14)
        ]
        for layer in layers {
            let tip = CGPoint(x: p.x + rng.wobble(1), y: p.y + size * (layer.yOff - 0.12))
            let left = CGPoint(x: p.x - size * layer.w + rng.wobble(1), y: p.y + size * (layer.yOff + 0.05))
            let right = CGPoint(x: p.x + size * layer.w + rng.wobble(1), y: p.y + size * (layer.yOff + 0.05))
            context.stroke(wobbleLine(from: tip, to: left, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
            context.stroke(wobbleLine(from: tip, to: right, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
            context.stroke(wobbleLine(from: left, to: right, rng: &rng, wobbleAmount: 0.8), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.6)
        }
    }

    private static func drawForestCluster(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        let positions: [(dx: CGFloat, dy: CGFloat, s: CGFloat)] = [
            (-0.2, 0.05, 0.6), (0.15, 0.0, 0.7), (0.0, -0.1, 0.8),
            (-0.12, -0.05, 0.5), (0.22, 0.08, 0.55)
        ]
        for pos in positions {
            let tp = CGPoint(x: p.x + size * pos.dx, y: p.y + size * pos.dy)
            drawDeciduousTree(context: &context, at: tp, size: size * pos.s, lineWidth: lineWidth * 0.7, rng: &rng)
        }
    }

    private static func drawDeadTree(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        let trunkBottom = CGPoint(x: p.x, y: p.y + size * 0.2)
        let trunkTop = CGPoint(x: p.x + rng.wobble(2), y: p.y - size * 0.25)
        context.stroke(wobbleLine(from: trunkBottom, to: trunkTop, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 1.3)

        // Bare branches
        let branches: [(angle: CGFloat, len: CGFloat)] = [
            (-0.8, 0.2), (0.6, 0.18), (-1.2, 0.15), (1.0, 0.12)
        ]
        for (i, branch) in branches.enumerated() {
            let startT = 0.3 + CGFloat(i) * 0.15
            let start = CGPoint(
                x: trunkBottom.x + (trunkTop.x - trunkBottom.x) * startT,
                y: trunkBottom.y + (trunkTop.y - trunkBottom.y) * startT
            )
            let end = CGPoint(
                x: start.x + cos(branch.angle) * size * branch.len + rng.wobble(2),
                y: start.y + sin(branch.angle) * size * branch.len + rng.wobble(2)
            )
            context.stroke(wobbleLine(from: start, to: end, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.7)
        }
    }

    private static func drawPalm(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Curved trunk
        let trunkBottom = CGPoint(x: p.x, y: p.y + size * 0.2)
        let trunkTop = CGPoint(x: p.x + size * 0.08, y: p.y - size * 0.25)
        var trunk = Path()
        trunk.move(to: trunkBottom)
        trunk.addQuadCurve(to: trunkTop, control: CGPoint(x: p.x + size * 0.15, y: p.y))
        context.stroke(trunk, with: .color(InkStyle.inkColor), lineWidth: lineWidth * 1.1)

        // Fronds
        let frondCount = 5
        for i in 0..<frondCount {
            let angle = CGFloat(i) / CGFloat(frondCount) * .pi * 1.6 - .pi * 0.3
            let endX = trunkTop.x + cos(angle) * size * 0.25
            let endY = trunkTop.y + sin(angle) * size * 0.2 + size * 0.05
            var frond = Path()
            frond.move(to: trunkTop)
            frond.addQuadCurve(to: CGPoint(x: endX, y: endY), control: CGPoint(x: trunkTop.x + cos(angle) * size * 0.15 + rng.wobble(2), y: trunkTop.y - size * 0.08))
            context.stroke(frond, with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.7)
        }
    }

    // MARK: - Settlement Variants

    private static func drawSettlement(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, variant: Int, lineWidth: CGFloat, rng: inout SeededRandom) {
        switch variant {
        case 0: drawCamp(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 1: drawVillage(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 2: drawSmallTown(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 3: drawLargeTown(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 4: drawCity(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 5: drawRuins(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        default: drawVillage(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        }
    }

    private static func drawHouse(context: inout GraphicsContext, at p: CGPoint, w: CGFloat, h: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Simple house: rectangle + triangle roof
        let left = p.x - w / 2
        let right = p.x + w / 2
        let top = p.y - h / 2
        let bottom = p.y + h / 2
        let roofPeak = CGPoint(x: p.x + rng.wobble(1), y: top - h * 0.4)

        // Walls
        let bl = CGPoint(x: left + rng.wobble(0.5), y: bottom + rng.wobble(0.5))
        let br = CGPoint(x: right + rng.wobble(0.5), y: bottom + rng.wobble(0.5))
        let tl = CGPoint(x: left + rng.wobble(0.5), y: top + rng.wobble(0.5))
        let tr = CGPoint(x: right + rng.wobble(0.5), y: top + rng.wobble(0.5))

        context.stroke(wobbleLine(from: bl, to: br, rng: &rng, wobbleAmount: 0.5), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        context.stroke(wobbleLine(from: bl, to: tl, rng: &rng, wobbleAmount: 0.5), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        context.stroke(wobbleLine(from: br, to: tr, rng: &rng, wobbleAmount: 0.5), with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Roof
        context.stroke(wobbleLine(from: tl, to: roofPeak, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        context.stroke(wobbleLine(from: tr, to: roofPeak, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
    }

    private static func drawCamp(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Tent triangle
        let tentPeak = CGPoint(x: p.x + rng.wobble(1), y: p.y - size * 0.2)
        let tentLeft = CGPoint(x: p.x - size * 0.15, y: p.y + size * 0.1)
        let tentRight = CGPoint(x: p.x + size * 0.15, y: p.y + size * 0.1)
        context.stroke(wobbleLine(from: tentPeak, to: tentLeft, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        context.stroke(wobbleLine(from: tentPeak, to: tentRight, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        context.stroke(wobbleLine(from: tentLeft, to: tentRight, rng: &rng, wobbleAmount: 0.8), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.7)

        // Campfire (small circle + flame lines)
        let fireCenter = CGPoint(x: p.x + size * 0.25, y: p.y + size * 0.05)
        var fireCircle = Path()
        fireCircle.addEllipse(in: CGRect(x: fireCenter.x - size * 0.04, y: fireCenter.y - size * 0.02, width: size * 0.08, height: size * 0.04))
        context.stroke(fireCircle, with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.5)
        // Flame wisps
        for i in 0..<3 {
            let fx = fireCenter.x + CGFloat(i - 1) * size * 0.02
            let line = wobbleLine(from: CGPoint(x: fx, y: fireCenter.y - size * 0.02), to: CGPoint(x: fx + rng.wobble(1), y: fireCenter.y - size * 0.08), rng: &rng, wobbleAmount: 0.8)
            context.stroke(line, with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.4)
        }
    }

    private static func drawVillage(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        let positions: [(dx: CGFloat, dy: CGFloat)] = [(-0.12, 0), (0.12, 0.02), (0, -0.08)]
        for pos in positions {
            let hp = CGPoint(x: p.x + size * pos.dx + rng.wobble(1), y: p.y + size * pos.dy)
            drawHouse(context: &context, at: hp, w: size * 0.12, h: size * 0.1, lineWidth: lineWidth * 0.8, rng: &rng)
        }
    }

    private static func drawSmallTown(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Houses
        let positions: [(dx: CGFloat, dy: CGFloat)] = [(-0.15, 0.05), (0.15, 0.03), (-0.05, -0.05), (0.08, -0.08)]
        for pos in positions {
            let hp = CGPoint(x: p.x + size * pos.dx + rng.wobble(1), y: p.y + size * pos.dy)
            drawHouse(context: &context, at: hp, w: size * 0.1, h: size * 0.08, lineWidth: lineWidth * 0.7, rng: &rng)
        }
        // Simple wall (partial circle)
        var wall = Path()
        wall.addArc(center: p, radius: size * 0.28, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        context.stroke(wall, with: .color(InkStyle.lightInk), style: StrokeStyle(lineWidth: lineWidth * 0.6, dash: [3, 3]))
    }

    private static func drawLargeTown(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Many houses
        let positions: [(dx: CGFloat, dy: CGFloat)] = [
            (-0.18, 0.05), (0.18, 0.03), (-0.08, -0.05), (0.1, -0.08),
            (0, 0.08), (-0.2, -0.05), (0.15, -0.02)
        ]
        for pos in positions {
            let hp = CGPoint(x: p.x + size * pos.dx + rng.wobble(1), y: p.y + size * pos.dy)
            drawHouse(context: &context, at: hp, w: size * 0.08, h: size * 0.06, lineWidth: lineWidth * 0.6, rng: &rng)
        }
        // Tower
        let towerPos = CGPoint(x: p.x + rng.wobble(2), y: p.y - size * 0.12)
        drawTower(context: &context, at: towerPos, size: size * 0.5, lineWidth: lineWidth * 0.7, rng: &rng)
        // Wall
        var wall = Path()
        wall.addArc(center: p, radius: size * 0.32, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        context.stroke(wall, with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.6)
    }

    private static func drawCity(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Full wall circle
        var wall = Path()
        let wallR = size * 0.38
        let segments = 12
        for i in 0...segments {
            let angle = CGFloat(i) / CGFloat(segments) * .pi * 2
            let r = wallR + rng.wobble(2)
            let wp = CGPoint(x: p.x + cos(angle) * r, y: p.y + sin(angle) * r)
            if i == 0 { wall.move(to: wp) } else { wall.addLine(to: wp) }
        }
        wall.closeSubpath()
        context.stroke(wall, with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Many houses inside
        for _ in 0..<8 {
            let hp = CGPoint(x: p.x + rng.wobble(size * 0.22), y: p.y + rng.wobble(size * 0.22))
            drawHouse(context: &context, at: hp, w: size * 0.07, h: size * 0.05, lineWidth: lineWidth * 0.5, rng: &rng)
        }

        // Cathedral (tall house)
        let catPos = CGPoint(x: p.x + rng.wobble(3), y: p.y - size * 0.05)
        drawHouse(context: &context, at: catPos, w: size * 0.1, h: size * 0.12, lineWidth: lineWidth * 0.8, rng: &rng)

        // Corner towers
        let corners: [CGFloat] = [0, .pi / 2, .pi, .pi * 1.5]
        for angle in corners {
            let tx = p.x + cos(angle) * wallR
            let ty = p.y + sin(angle) * wallR
            var tower = Path()
            tower.addEllipse(in: CGRect(x: tx - size * 0.03, y: ty - size * 0.03, width: size * 0.06, height: size * 0.06))
            context.fill(tower, with: .color(InkStyle.inkColor))
        }
    }

    private static func drawRuins(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Broken wall segments
        for _ in 0..<4 {
            let sx = p.x + rng.wobble(size * 0.25)
            let sy = p.y + rng.wobble(size * 0.15)
            let len = size * (0.08 + rng.next() * 0.1)
            let angle = rng.next() * .pi
            let end = CGPoint(x: sx + cos(angle) * len, y: sy + sin(angle) * len)
            context.stroke(wobbleLine(from: CGPoint(x: sx, y: sy), to: end, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.8)
        }
        // Rubble dots
        for _ in 0..<6 {
            let rx = p.x + rng.wobble(size * 0.2)
            let ry = p.y + rng.wobble(size * 0.12)
            var dot = Path()
            let dotSize = lineWidth * (0.5 + rng.next() * 1.0)
            dot.addEllipse(in: CGRect(x: rx, y: ry, width: dotSize, height: dotSize))
            context.fill(dot, with: .color(InkStyle.lightInk))
        }
        // One broken column
        let colX = p.x + rng.wobble(size * 0.1)
        context.stroke(wobbleLine(from: CGPoint(x: colX, y: p.y + size * 0.1), to: CGPoint(x: colX + rng.wobble(2), y: p.y - size * 0.12), rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
    }

    // MARK: - Castle Variants

    private static func drawCastle(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, variant: Int, lineWidth: CGFloat, rng: inout SeededRandom) {
        switch variant {
        case 0: drawTower(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 1: drawKeep(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 2: drawFortress(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 3: drawRuinedCastle(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        default: drawKeep(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        }
    }

    private static func drawTower(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        let w = size * 0.12
        let h = size * 0.35
        let top = p.y - h / 2
        let bottom = p.y + h / 2

        // Walls
        let tl = CGPoint(x: p.x - w + rng.wobble(0.5), y: top)
        let tr = CGPoint(x: p.x + w + rng.wobble(0.5), y: top)
        let bl = CGPoint(x: p.x - w + rng.wobble(0.5), y: bottom)
        let br = CGPoint(x: p.x + w + rng.wobble(0.5), y: bottom)

        context.stroke(wobbleLine(from: bl, to: tl, rng: &rng, wobbleAmount: 0.5), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        context.stroke(wobbleLine(from: br, to: tr, rng: &rng, wobbleAmount: 0.5), with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Crenellations
        let crenCount = 3
        let crenW = w * 2 / CGFloat(crenCount * 2 + 1)
        for i in 0..<crenCount {
            let cx = p.x - w + CGFloat(i * 2 + 1) * crenW
            let rect = CGRect(x: cx, y: top - crenW, width: crenW, height: crenW)
            var cren = Path()
            cren.addRect(rect)
            context.stroke(cren, with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.6)
        }
        // Top wall line
        context.stroke(wobbleLine(from: tl, to: tr, rng: &rng, wobbleAmount: 0.3), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.7)
    }

    private static func drawKeep(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Main building
        drawHouse(context: &context, at: CGPoint(x: p.x, y: p.y + size * 0.05), w: size * 0.2, h: size * 0.15, lineWidth: lineWidth, rng: &rng)
        // Two flanking towers
        drawTower(context: &context, at: CGPoint(x: p.x - size * 0.18, y: p.y), size: size * 0.6, lineWidth: lineWidth * 0.7, rng: &rng)
        drawTower(context: &context, at: CGPoint(x: p.x + size * 0.18, y: p.y), size: size * 0.55, lineWidth: lineWidth * 0.7, rng: &rng)
    }

    private static func drawFortress(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Outer wall (irregular rectangle)
        let hw = size * 0.35
        let hh = size * 0.25
        let corners = [
            CGPoint(x: p.x - hw + rng.wobble(2), y: p.y - hh + rng.wobble(2)),
            CGPoint(x: p.x + hw + rng.wobble(2), y: p.y - hh + rng.wobble(2)),
            CGPoint(x: p.x + hw + rng.wobble(2), y: p.y + hh + rng.wobble(2)),
            CGPoint(x: p.x - hw + rng.wobble(2), y: p.y + hh + rng.wobble(2)),
        ]
        for i in 0..<4 {
            context.stroke(wobbleLine(from: corners[i], to: corners[(i + 1) % 4], rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        }
        // Corner towers
        for corner in corners {
            var dot = Path()
            dot.addEllipse(in: CGRect(x: corner.x - size * 0.04, y: corner.y - size * 0.04, width: size * 0.08, height: size * 0.08))
            context.fill(dot, with: .color(InkStyle.inkColor))
        }
        // Inner keep
        drawHouse(context: &context, at: p, w: size * 0.14, h: size * 0.12, lineWidth: lineWidth * 0.7, rng: &rng)
        // Gate (gap in bottom wall + portcullis lines)
        let gateW = size * 0.06
        let gateY = p.y + hh
        for i in 0..<3 {
            let gx = p.x - gateW + CGFloat(i) * gateW
            context.stroke(wobbleLine(from: CGPoint(x: gx, y: gateY - size * 0.06), to: CGPoint(x: gx, y: gateY + size * 0.02), rng: &rng, wobbleAmount: 0.3), with: .color(InkStyle.lightInk), lineWidth: lineWidth * 0.4)
        }
    }

    private static func drawRuinedCastle(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Broken tower left
        let tl = CGPoint(x: p.x - size * 0.15, y: p.y)
        context.stroke(wobbleLine(from: CGPoint(x: tl.x, y: tl.y + size * 0.15), to: CGPoint(x: tl.x + rng.wobble(2), y: tl.y - size * 0.15), rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        // Broken top (jagged)
        let breakPts = [
            CGPoint(x: tl.x - size * 0.04, y: tl.y - size * 0.12),
            CGPoint(x: tl.x + rng.wobble(2), y: tl.y - size * 0.15),
            CGPoint(x: tl.x + size * 0.04, y: tl.y - size * 0.1),
        ]
        for i in 0..<(breakPts.count - 1) {
            context.stroke(wobbleLine(from: breakPts[i], to: breakPts[i + 1], rng: &rng, wobbleAmount: 0.8), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.7)
        }

        // Right wall fragment
        context.stroke(wobbleLine(from: CGPoint(x: p.x + size * 0.15, y: p.y + size * 0.15), to: CGPoint(x: p.x + size * 0.15, y: p.y - size * 0.05), rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Rubble
        for _ in 0..<5 {
            let rx = p.x + rng.wobble(size * 0.18)
            let ry = p.y + size * 0.1 + rng.wobble(size * 0.05)
            var dot = Path()
            dot.addEllipse(in: CGRect(x: rx, y: ry, width: lineWidth * 1.2, height: lineWidth * 0.8))
            context.fill(dot, with: .color(InkStyle.lightInk))
        }

        // Connecting broken wall
        context.stroke(wobbleLine(from: CGPoint(x: p.x - size * 0.15, y: p.y + size * 0.15), to: CGPoint(x: p.x + size * 0.15, y: p.y + size * 0.15), rng: &rng), with: .color(InkStyle.lightInk), style: StrokeStyle(lineWidth: lineWidth * 0.5, dash: [4, 3]))
    }

    // MARK: - Water Variants

    private static func drawWater(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, variant: Int, lineWidth: CGFloat, rng: inout SeededRandom) {
        switch variant {
        case 1: drawRiver(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 2: drawCoast(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        default: drawLake(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        }
    }

    private static func drawLake(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Irregular oval shore
        var shore = Path()
        let segments = 10
        for i in 0...segments {
            let angle = CGFloat(i) / CGFloat(segments) * .pi * 2
            let rx = size * 0.3 + rng.wobble(size * 0.05)
            let ry = size * 0.2 + rng.wobble(size * 0.04)
            let sx = p.x + cos(angle) * rx
            let sy = p.y + sin(angle) * ry
            if i == 0 { shore.move(to: CGPoint(x: sx, y: sy)) }
            else { shore.addLine(to: CGPoint(x: sx, y: sy)) }
        }
        shore.closeSubpath()
        context.stroke(shore, with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Interior wave lines
        for i in 0..<3 {
            let wy = p.y + CGFloat(i - 1) * size * 0.08
            var wave = Path()
            wave.move(to: CGPoint(x: p.x - size * 0.15, y: wy))
            for j in 0..<4 {
                let wx = p.x - size * 0.15 + CGFloat(j) * size * 0.1
                let dy = (j % 2 == 0 ? -1.0 : 1.0) * size * 0.02
                wave.addLine(to: CGPoint(x: wx, y: wy + dy))
            }
            context.stroke(wave, with: .color(InkStyle.lightInk), lineWidth: lineWidth * 0.4)
        }
    }

    private static func drawRiver(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Double wavy lines (river banks)
        for side in [-1.0, 1.0] as [CGFloat] {
            var bank = Path()
            let startY = p.y - size * 0.35
            bank.move(to: CGPoint(x: p.x + side * size * 0.06, y: startY))
            for i in 1...8 {
                let y = startY + CGFloat(i) * size * 0.09
                let x = p.x + side * size * 0.06 + rng.wobble(size * 0.04) + sin(CGFloat(i) * 0.8) * size * 0.04
                bank.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(bank, with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.8)
        }
        // Flow lines in center
        for _ in 0..<3 {
            let fy = p.y + rng.wobble(size * 0.15)
            var flow = Path()
            flow.move(to: CGPoint(x: p.x - size * 0.03, y: fy))
            flow.addLine(to: CGPoint(x: p.x + size * 0.03 + rng.wobble(1), y: fy + rng.wobble(2)))
            context.stroke(flow, with: .color(InkStyle.lightInk), lineWidth: lineWidth * 0.3)
        }
    }

    private static func drawCoast(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Shore line (main coast)
        var coast = Path()
        let startX = p.x - size * 0.4
        coast.move(to: CGPoint(x: startX, y: p.y))
        for i in 1...10 {
            let x = startX + CGFloat(i) * size * 0.08
            let y = p.y + rng.wobble(size * 0.06)
            coast.addLine(to: CGPoint(x: x, y: y))
        }
        context.stroke(coast, with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Parallel shore lines (water side)
        for offset in [size * 0.06, size * 0.1] {
            var shoreLine = Path()
            shoreLine.move(to: CGPoint(x: startX + size * 0.05, y: p.y + offset))
            for i in 1...8 {
                let x = startX + size * 0.05 + CGFloat(i) * size * 0.08
                let y = p.y + offset + rng.wobble(size * 0.03)
                shoreLine.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(shoreLine, with: .color(InkStyle.lightInk), lineWidth: lineWidth * 0.4)
        }
    }

    // MARK: - Landmark Variants

    private static func drawLandmark(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, variant: Int, lineWidth: CGFloat, rng: inout SeededRandom) {
        switch variant {
        case 0: drawBridge(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 1: drawShrine(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 2: drawMine(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        case 3: drawCaveMouth(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        default: drawShrine(context: &context, at: p, size: size, lineWidth: lineWidth, rng: &rng)
        }
    }

    private static func drawBridge(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Arch
        var arch = Path()
        arch.move(to: CGPoint(x: p.x - size * 0.25, y: p.y + size * 0.1))
        arch.addQuadCurve(to: CGPoint(x: p.x + size * 0.25, y: p.y + size * 0.1), control: CGPoint(x: p.x, y: p.y - size * 0.15))
        context.stroke(arch, with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Road surface
        let roadLeft = CGPoint(x: p.x - size * 0.3, y: p.y)
        let roadRight = CGPoint(x: p.x + size * 0.3, y: p.y)
        context.stroke(wobbleLine(from: roadLeft, to: roadRight, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.8)

        // Railings
        for side in [-1.0, 1.0] as [CGFloat] {
            let ry = p.y - size * 0.04 * side
            context.stroke(wobbleLine(from: CGPoint(x: p.x - size * 0.2, y: ry), to: CGPoint(x: p.x + size * 0.2, y: ry), rng: &rng, wobbleAmount: 0.5), with: .color(InkStyle.lightInk), lineWidth: lineWidth * 0.4)
        }
    }

    private static func drawShrine(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Pillars
        let pillarSpacing = size * 0.12
        for side in [-1.0, 1.0] as [CGFloat] {
            let px = p.x + side * pillarSpacing
            context.stroke(wobbleLine(from: CGPoint(x: px, y: p.y + size * 0.15), to: CGPoint(x: px, y: p.y - size * 0.15), rng: &rng, wobbleAmount: 0.5), with: .color(InkStyle.inkColor), lineWidth: lineWidth)
        }
        // Triangular pediment
        let pedLeft = CGPoint(x: p.x - pillarSpacing - size * 0.03, y: p.y - size * 0.15)
        let pedRight = CGPoint(x: p.x + pillarSpacing + size * 0.03, y: p.y - size * 0.15)
        let pedTop = CGPoint(x: p.x + rng.wobble(1), y: p.y - size * 0.28)
        context.stroke(wobbleLine(from: pedLeft, to: pedTop, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.8)
        context.stroke(wobbleLine(from: pedTop, to: pedRight, rng: &rng), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.8)
        context.stroke(wobbleLine(from: pedLeft, to: pedRight, rng: &rng, wobbleAmount: 0.5), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.7)
        // Steps
        context.stroke(wobbleLine(from: CGPoint(x: p.x - pillarSpacing, y: p.y + size * 0.15), to: CGPoint(x: p.x + pillarSpacing, y: p.y + size * 0.15), rng: &rng, wobbleAmount: 0.5), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.6)
    }

    private static func drawMine(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Mine entrance — dark arch in hillside
        var hillside = Path()
        hillside.move(to: CGPoint(x: p.x - size * 0.3, y: p.y + size * 0.1))
        hillside.addQuadCurve(to: CGPoint(x: p.x + size * 0.3, y: p.y + size * 0.1), control: CGPoint(x: p.x, y: p.y - size * 0.2))
        context.stroke(hillside, with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Dark entrance arch
        var entrance = Path()
        entrance.move(to: CGPoint(x: p.x - size * 0.08, y: p.y + size * 0.1))
        entrance.addQuadCurve(to: CGPoint(x: p.x + size * 0.08, y: p.y + size * 0.1), control: CGPoint(x: p.x, y: p.y - size * 0.02))
        // Fill dark
        var entranceFill = Path()
        entranceFill.move(to: CGPoint(x: p.x - size * 0.08, y: p.y + size * 0.1))
        entranceFill.addQuadCurve(to: CGPoint(x: p.x + size * 0.08, y: p.y + size * 0.1), control: CGPoint(x: p.x, y: p.y - size * 0.02))
        entranceFill.addLine(to: CGPoint(x: p.x + size * 0.08, y: p.y + size * 0.12))
        entranceFill.addLine(to: CGPoint(x: p.x - size * 0.08, y: p.y + size * 0.12))
        entranceFill.closeSubpath()
        context.fill(entranceFill, with: .color(InkStyle.inkColor))

        // Pickaxe cross
        let axeCenter = CGPoint(x: p.x + size * 0.2, y: p.y - size * 0.05)
        context.stroke(wobbleLine(from: CGPoint(x: axeCenter.x - size * 0.06, y: axeCenter.y - size * 0.06), to: CGPoint(x: axeCenter.x + size * 0.06, y: axeCenter.y + size * 0.06), rng: &rng, wobbleAmount: 0.5), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.6)
        context.stroke(wobbleLine(from: CGPoint(x: axeCenter.x + size * 0.06, y: axeCenter.y - size * 0.06), to: CGPoint(x: axeCenter.x - size * 0.06, y: axeCenter.y + size * 0.06), rng: &rng, wobbleAmount: 0.5), with: .color(InkStyle.inkColor), lineWidth: lineWidth * 0.6)
    }

    private static func drawCaveMouth(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat, rng: inout SeededRandom) {
        // Jagged cave opening
        var cave = Path()
        let openingWidth = size * 0.25
        let openingHeight = size * 0.2
        cave.move(to: CGPoint(x: p.x - openingWidth, y: p.y + openingHeight * 0.5))
        // Top of opening (jagged)
        cave.addLine(to: CGPoint(x: p.x - openingWidth * 0.7 + rng.wobble(2), y: p.y - openingHeight * 0.3 + rng.wobble(2)))
        cave.addLine(to: CGPoint(x: p.x - openingWidth * 0.3 + rng.wobble(2), y: p.y - openingHeight * 0.5 + rng.wobble(2)))
        cave.addLine(to: CGPoint(x: p.x + rng.wobble(2), y: p.y - openingHeight * 0.6 + rng.wobble(2)))
        cave.addLine(to: CGPoint(x: p.x + openingWidth * 0.4 + rng.wobble(2), y: p.y - openingHeight * 0.4 + rng.wobble(2)))
        cave.addLine(to: CGPoint(x: p.x + openingWidth * 0.8 + rng.wobble(2), y: p.y - openingHeight * 0.2 + rng.wobble(2)))
        cave.addLine(to: CGPoint(x: p.x + openingWidth, y: p.y + openingHeight * 0.5))
        context.stroke(cave, with: .color(InkStyle.inkColor), lineWidth: lineWidth)

        // Dark interior fill
        cave.addLine(to: CGPoint(x: p.x - openingWidth, y: p.y + openingHeight * 0.5))
        cave.closeSubpath()
        context.fill(cave, with: .color(InkStyle.inkColor.opacity(0.6)))

        // Stalactites (small hanging lines from top)
        for _ in 0..<3 {
            let sx = p.x + rng.wobble(openingWidth * 0.5)
            let sy = p.y - openingHeight * 0.3 + rng.wobble(openingHeight * 0.1)
            context.stroke(wobbleLine(from: CGPoint(x: sx, y: sy), to: CGPoint(x: sx + rng.wobble(1), y: sy + size * 0.06), rng: &rng, wobbleAmount: 0.3), with: .color(InkStyle.lightInk), lineWidth: lineWidth * 0.5)
        }
    }

    // MARK: - Fallback

    private static func drawFallbackDot(context: inout GraphicsContext, at p: CGPoint, size: CGFloat, lineWidth: CGFloat) {
        var dot = Path()
        dot.addEllipse(in: CGRect(x: p.x - size * 0.1, y: p.y - size * 0.1, width: size * 0.2, height: size * 0.2))
        context.stroke(dot, with: .color(InkStyle.inkColor), lineWidth: lineWidth)
    }

    // MARK: - Border Drawing

    /// Draw a kingdom border with jagged ink line + cross marks
    static func drawBorder(
        context: inout GraphicsContext,
        points: [CGPoint],
        mapSize: CGSize,
        style: String,
        color: String,
        lineWidth: CGFloat
    ) {
        guard points.count >= 2 else { return }

        let resolvedColor: Color = switch color {
        case "river": InkStyle.borderBlue
        case "road": InkStyle.lightInk
        default: InkStyle.inkColor
        }

        // Convert normalized points to canvas coords
        let canvasPoints = points.map { CGPoint(x: $0.x * mapSize.width, y: $0.y * mapSize.height) }

        var path = Path()
        path.move(to: canvasPoints[0])

        // Add wobble for hand-drawn look
        var rng = SeededRandom(seed: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA") ?? UUID())
        for i in 1..<canvasPoints.count {
            let prev = canvasPoints[i - 1]
            let curr = canvasPoints[i]
            let dist = hypot(curr.x - prev.x, curr.y - prev.y)
            let steps = max(2, Int(dist / 8))
            for s in 1...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let x = prev.x + (curr.x - prev.x) * t + rng.wobble(1.5)
                let y = prev.y + (curr.y - prev.y) * t + rng.wobble(1.5)
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        let strokeStyle: StrokeStyle = switch style {
        case "dashed": StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [8, 4])
        case "dotted": StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [2, 4])
        default: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
        }

        context.stroke(path, with: .color(resolvedColor), style: strokeStyle)

        // Cross marks at intervals for border style
        if style == "dashed" || color == "border" {
            let interval: CGFloat = 40
            var accumulated: CGFloat = 0
            for i in 1..<canvasPoints.count {
                let dx = canvasPoints[i].x - canvasPoints[i - 1].x
                let dy = canvasPoints[i].y - canvasPoints[i - 1].y
                let segLen = hypot(dx, dy)
                accumulated += segLen
                if accumulated >= interval {
                    accumulated = 0
                    let mid = canvasPoints[i]
                    // Small X mark
                    let cs = lineWidth * 2
                    var cross = Path()
                    cross.move(to: CGPoint(x: mid.x - cs, y: mid.y - cs))
                    cross.addLine(to: CGPoint(x: mid.x + cs, y: mid.y + cs))
                    cross.move(to: CGPoint(x: mid.x + cs, y: mid.y - cs))
                    cross.addLine(to: CGPoint(x: mid.x - cs, y: mid.y + cs))
                    context.stroke(cross, with: .color(resolvedColor.opacity(0.6)), lineWidth: lineWidth * 0.5)
                }
            }
        }
    }

    // MARK: - Freehand Drawing

    /// Draw a freehand ink line with calligraphy-style width variation
    static func drawFreehand(
        context: inout GraphicsContext,
        points: [CGPoint],
        mapSize: CGSize,
        lineWidth: Double,
        color: String
    ) {
        guard points.count >= 2 else { return }

        let resolvedColor: Color = switch color {
        case "blue": InkStyle.borderBlue
        case "green": InkStyle.drawGreen
        case "red": InkStyle.borderRed
        default: InkStyle.inkColor
        }

        let canvasPoints = points.map { CGPoint(x: $0.x * mapSize.width, y: $0.y * mapSize.height) }

        // Simple path with variable width approximation
        var path = Path()
        path.move(to: canvasPoints[0])
        for i in 1..<canvasPoints.count {
            path.addLine(to: canvasPoints[i])
        }
        context.stroke(path, with: .color(resolvedColor), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }

    // MARK: - Text Label

    static func drawTextLabel(
        context: inout GraphicsContext,
        text: String,
        at point: CGPoint,
        mapSize: CGSize,
        fontSize: CGFloat
    ) {
        let canvasPoint = CGPoint(x: point.x * mapSize.width, y: point.y * mapSize.height)
        let resolved = context.resolve(Text(text).font(.system(size: fontSize, weight: .bold, design: .serif)).foregroundColor(InkStyle.inkColor))
        context.draw(resolved, at: canvasPoint, anchor: .center)
    }

    // MARK: - Parchment Background

    static func drawParchmentBackground(context: inout GraphicsContext, size: CGSize) {
        // Base parchment fill
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(InkStyle.parchment))

        // Vignette (darken edges)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxDim = max(size.width, size.height)
        context.drawLayer { layerContext in
            let gradient = Gradient(stops: [
                .init(color: .clear, location: 0.5),
                .init(color: Color.brown.opacity(0.12), location: 0.85),
                .init(color: Color.brown.opacity(0.2), location: 1.0),
            ])
            layerContext.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: maxDim * 0.6)
            )
        }

        // Subtle grain — horizontal lines for aged paper texture
        var rng = SeededRandom(seed: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB") ?? UUID())
        for _ in 0..<20 {
            let y = rng.next() * size.height
            let x1 = rng.next() * size.width * 0.3
            let x2 = x1 + rng.next() * size.width * 0.4
            var line = Path()
            line.move(to: CGPoint(x: x1, y: y))
            line.addLine(to: CGPoint(x: x2, y: y + rng.wobble(0.5)))
            context.stroke(line, with: .color(Color.brown.opacity(0.03)), lineWidth: 0.5)
        }
    }
}

// MARK: - Path Simplification (Ramer-Douglas-Peucker)

enum PathSimplifier {
    static func simplify(_ points: [CGPoint], epsilon: CGFloat = 2.0) -> [CGPoint] {
        guard points.count > 2 else { return points }

        var maxDist: CGFloat = 0
        var maxIndex = 0

        let start = points.first!
        let end = points.last!

        for i in 1..<(points.count - 1) {
            let d = perpendicularDistance(point: points[i], lineStart: start, lineEnd: end)
            if d > maxDist {
                maxDist = d
                maxIndex = i
            }
        }

        if maxDist > epsilon {
            let left = simplify(Array(points[0...maxIndex]), epsilon: epsilon)
            let right = simplify(Array(points[maxIndex..<points.count]), epsilon: epsilon)
            return Array(left.dropLast()) + right
        } else {
            return [start, end]
        }
    }

    private static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let len = hypot(dx, dy)
        guard len > 0 else { return hypot(point.x - lineStart.x, point.y - lineStart.y) }

        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / (len * len)))
        let projX = lineStart.x + t * dx
        let projY = lineStart.y + t * dy
        return hypot(point.x - projX, point.y - projY)
    }
}

import SwiftUI
import UIKit

// MARK: - Pencil Touch Point

/// A single touch point with optional pressure data from Apple Pencil
struct PencilTouchPoint {
    let location: CGPoint
    let pressure: Double  // 0.0...1.0 (normalized), 0.5 for finger touches
    let isPencil: Bool
}

// MARK: - PencilCanvasView

/// UIViewRepresentable that captures Apple Pencil touch events with pressure data.
/// Overlays the SwiftUI Canvas to intercept pencil/finger drawing input and pass
/// normalized touch points + pressures back to SwiftUI for rendering.
struct PencilCanvasView: UIViewRepresentable {
    /// Current tool mode — only captures touches in draw/river modes
    let toolMode: MapToolMode

    /// Zoom and pan state for coordinate conversion
    let zoomScale: CGFloat
    let panOffset: CGSize

    /// Called for each new touch point during a stroke
    var onTouchPoint: (PencilTouchPoint) -> Void

    /// Called when the stroke ends
    var onTouchEnded: () -> Void

    /// Called when Pencil double-tap toggles eraser
    var onPencilDoubleTap: (() -> Void)?

    func makeUIView(context: Context) -> PencilTouchView {
        let view = PencilTouchView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        view.delegate = context.coordinator

        // Register for Apple Pencil double-tap interaction
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        view.addInteraction(pencilInteraction)

        return view
    }

    func updateUIView(_ uiView: PencilTouchView, context: Context) {
        context.coordinator.toolMode = toolMode
        context.coordinator.zoomScale = zoomScale
        context.coordinator.panOffset = panOffset
        context.coordinator.onTouchPoint = onTouchPoint
        context.coordinator.onTouchEnded = onTouchEnded
        context.coordinator.onPencilDoubleTap = onPencilDoubleTap

        // Only intercept touches in drawing modes
        let shouldCapture = (toolMode == .draw || toolMode == .river)
        uiView.isUserInteractionEnabled = shouldCapture
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            toolMode: toolMode,
            zoomScale: zoomScale,
            panOffset: panOffset,
            onTouchPoint: onTouchPoint,
            onTouchEnded: onTouchEnded,
            onPencilDoubleTap: onPencilDoubleTap
        )
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, PencilTouchViewDelegate, UIPencilInteractionDelegate {
        var toolMode: MapToolMode
        var zoomScale: CGFloat
        var panOffset: CGSize
        var onTouchPoint: (PencilTouchPoint) -> Void
        var onTouchEnded: () -> Void
        var onPencilDoubleTap: (() -> Void)?
        private var isTracking = false

        init(
            toolMode: MapToolMode,
            zoomScale: CGFloat,
            panOffset: CGSize,
            onTouchPoint: @escaping (PencilTouchPoint) -> Void,
            onTouchEnded: @escaping () -> Void,
            onPencilDoubleTap: (() -> Void)?
        ) {
            self.toolMode = toolMode
            self.zoomScale = zoomScale
            self.panOffset = panOffset
            self.onTouchPoint = onTouchPoint
            self.onTouchEnded = onTouchEnded
            self.onPencilDoubleTap = onPencilDoubleTap
        }

        func touchBegan(_ touch: UITouch, in view: UIView) {
            guard toolMode == .draw || toolMode == .river else { return }
            isTracking = true
            handleTouch(touch, in: view)
        }

        func touchMoved(_ touch: UITouch, in view: UIView) {
            guard isTracking else { return }
            handleTouch(touch, in: view)
        }

        func touchEnded(_ touch: UITouch, in view: UIView) {
            guard isTracking else { return }
            isTracking = false
            onTouchEnded()
        }

        func touchCancelled(_ touch: UITouch, in view: UIView) {
            guard isTracking else { return }
            isTracking = false
            onTouchEnded()
        }

        private func handleTouch(_ touch: UITouch, in view: UIView) {
            let location = touch.location(in: view)
            let isPencil = touch.type == .pencil
            let pressure: Double

            if isPencil {
                // Normalize pressure: Apple Pencil force range is 0...maximumPossibleForce
                let maxForce = touch.maximumPossibleForce > 0 ? touch.maximumPossibleForce : 4.0
                pressure = min(1.0, Double(touch.force / maxForce))
            } else {
                pressure = 0.5  // uniform width for finger input
            }

            // Convert screen point to normalized map coordinates
            let viewSize = view.bounds.size
            let tx = panOffset.width + viewSize.width / 2 * (1 - zoomScale)
            let ty = panOffset.height + viewSize.height / 2 * (1 - zoomScale)
            let mapX = (location.x - tx) / (viewSize.width * zoomScale)
            let mapY = (location.y - ty) / (viewSize.height * zoomScale)

            let point = PencilTouchPoint(
                location: CGPoint(x: mapX, y: mapY),
                pressure: pressure,
                isPencil: isPencil
            )
            onTouchPoint(point)
        }

        // MARK: - UIPencilInteractionDelegate

        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            onPencilDoubleTap?()
        }
    }
}

// MARK: - PencilTouchView

@MainActor
protocol PencilTouchViewDelegate: AnyObject {
    func touchBegan(_ touch: UITouch, in view: UIView)
    func touchMoved(_ touch: UITouch, in view: UIView)
    func touchEnded(_ touch: UITouch, in view: UIView)
    func touchCancelled(_ touch: UITouch, in view: UIView)
}

/// Raw UIView that captures touch events and forwards them to the coordinator
class PencilTouchView: UIView {
    weak var delegate: PencilTouchViewDelegate?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        delegate?.touchBegan(touch, in: self)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // Use coalesced touches for smoother Apple Pencil input
        if let coalesced = event?.coalescedTouches(for: touch) {
            for coalescedTouch in coalesced {
                delegate?.touchMoved(coalescedTouch, in: self)
            }
        } else {
            delegate?.touchMoved(touch, in: self)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        delegate?.touchEnded(touch, in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        delegate?.touchCancelled(touch, in: self)
    }
}

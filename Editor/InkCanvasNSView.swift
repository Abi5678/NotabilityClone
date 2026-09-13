//
//  InkCanvasNSView.swift
//  NotabilityClone
//
//  Custom NSView: NSEvent → PKStrokePoint → PKStroke → PKDrawing
//

import AppKit
import PencilKit

enum InkTool: String {
    case pen
    case marker
    case eraser
}

protocol InkCanvasDelegate: AnyObject {
    func inkCanvas(_ canvas: InkCanvasNSView, didCompleteStrokeAtIndex index: Int, timeOffset: TimeInterval?)
    func inkCanvas(_ canvas: InkCanvasNSView, didSelectStrokeAtIndex index: Int)
    func inkCanvas(_ canvas: InkCanvasNSView, didUpdateDrawing drawing: PKDrawing)
    func inkCanvas(_ canvas: InkCanvasNSView, didRemoveStrokesAtIndices indices: [Int])
}

class InkCanvasNSView: NSView {
    weak var delegate: InkCanvasDelegate?

    private(set) var drawing = PKDrawing()
    private var currentPoints: [PKStrokePoint] = []
    private var currentTool: InkTool = .pen
    private var currentColor: NSColor = .black
    private var currentWidth: CGFloat = 4.0
    private var isDrawing = false
    private var strokeStartTime: Date?

    var recordingStartTime: Date?
    private var highlightedStrokeIndices: Set<Int> = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    var isActivelyDrawing: Bool { isDrawing }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.white.setFill()
        dirtyRect.fill()

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        for (index, stroke) in drawing.strokes.enumerated() {
            let highlighted = highlightedStrokeIndices.contains(index)
            renderPKStroke(stroke, in: context, highlighted: highlighted)
        }

        if isDrawing, currentPoints.count >= 1 {
            renderPreviewPoints(currentPoints, in: context)
        }
    }

    private func renderPKStroke(_ stroke: PKStroke, in context: CGContext, highlighted: Bool) {
        let path = stroke.path
        guard path.count >= 2 else { return }

        context.beginPath()
        for i in 0..<path.count {
            let point = path.interpolatedPoint(at: CGFloat(i)).location
            if i == 0 {
                context.move(to: point)
            } else {
                context.addLine(to: point)
            }
        }

        let color = highlighted ? NSColor.systemYellow : stroke.ink.color
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(highlighted ? currentWidth * 1.5 : strokePathWidth(stroke))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
    }

    private func strokePathWidth(_ stroke: PKStroke) -> CGFloat {
        guard stroke.path.count > 0 else { return currentWidth }
        return stroke.path.interpolatedPoint(at: 0).size.width
    }

    private func renderPreviewPoints(_ points: [PKStrokePoint], in context: CGContext) {
        guard points.count >= 1 else { return }
        context.beginPath()
        for (index, point) in points.enumerated() {
            if index == 0 {
                context.move(to: point.location)
            } else {
                context.addLine(to: point.location)
            }
        }
        context.setStrokeColor(currentColor.withAlphaComponent(currentTool == .marker ? 0.4 : 1.0).cgColor)
        context.setLineWidth(currentWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        if currentTool == .eraser {
            if let index = strokeIndex(at: location) {
                removeStroke(at: index)
            }
            return
        }

        if event.clickCount == 1, !isDrawing, let index = strokeIndex(at: location) {
            delegate?.inkCanvas(self, didSelectStrokeAtIndex: index)
            return
        }

        isDrawing = true
        strokeStartTime = Date()
        currentPoints = [makeStrokePoint(at: location, event: event)]
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDrawing else { return }
        let location = convert(event.locationInWindow, from: nil)
        currentPoints.append(makeStrokePoint(at: location, event: event))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard isDrawing else { return }
        isDrawing = false

        guard currentPoints.count >= 2 else {
            currentPoints = []
            return
        }

        let ink = makeInk()
        let strokePath = PKStrokePath(controlPoints: currentPoints, creationDate: Date())
        let stroke = PKStroke(ink: ink, path: strokePath)

        var updated = drawing
        updated.strokes.append(stroke)
        drawing = updated
        currentPoints = []

        let index = drawing.strokes.count - 1
        let timeOffset: TimeInterval?
        if let startTime = recordingStartTime {
            timeOffset = Date().timeIntervalSince(startTime)
        } else {
            timeOffset = nil
        }

        delegate?.inkCanvas(self, didCompleteStrokeAtIndex: index, timeOffset: timeOffset)
        delegate?.inkCanvas(self, didUpdateDrawing: drawing)
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    // MARK: - Public

    func setDrawing(_ newDrawing: PKDrawing, preserveInProgressStroke: Bool = false) {
        guard !isDrawing || preserveInProgressStroke else {
            drawing = newDrawing
            needsDisplay = true
            return
        }
        if !isDrawing {
            drawing = newDrawing
            needsDisplay = true
        }
    }

    func setTool(_ tool: InkTool, color: NSColor, width: CGFloat) {
        currentTool = tool
        currentColor = color
        currentWidth = width
    }

    func highlightStrokes(indices: Set<Int>) {
        highlightedStrokeIndices = indices
        needsDisplay = true
    }

    func strokeIndex(at point: CGPoint) -> Int? {
        let hitRadius: CGFloat = 12
        for (index, stroke) in drawing.strokes.enumerated().reversed() {
            let bounds = stroke.renderBounds
            let expanded = bounds.insetBy(dx: -hitRadius, dy: -hitRadius)
            if expanded.contains(point) {
                return index
            }
        }
        return nil
    }

    func clearDrawing() {
        drawing = PKDrawing()
        needsDisplay = true
        delegate?.inkCanvas(self, didUpdateDrawing: drawing)
    }

    // MARK: - Private

    private func makeStrokePoint(at location: CGPoint, event: NSEvent) -> PKStrokePoint {
        var force: CGFloat = 1.0
        var altitude: CGFloat = .pi / 2

        if event.subtype == .tabletPoint {
            force = event.pressure > 0 ? CGFloat(event.pressure) : 1.0
            altitude = event.tilt.y > 0 ? CGFloat(event.tilt.y) : .pi / 2
        }

        let size = currentWidth
        return PKStrokePoint(
            location: location,
            timeOffset: 0,
            size: CGSize(width: size, height: size),
            opacity: currentTool == .marker ? 0.4 : 1.0,
            force: force,
            azimuth: 0,
            altitude: altitude
        )
    }

    private func makeInk() -> PKInk {
        switch currentTool {
        case .pen:
            return PKInk(.pen, color: currentColor)
        case .marker:
            return PKInk(.marker, color: currentColor.withAlphaComponent(0.4))
        case .eraser:
            return PKInk(.pen, color: .clear)
        }
    }

    private func removeStroke(at index: Int) {
        guard index >= 0, index < drawing.strokes.count else { return }
        var updated = drawing
        updated.strokes.remove(at: index)
        drawing = updated
        delegate?.inkCanvas(self, didRemoveStrokesAtIndices: [index])
        delegate?.inkCanvas(self, didUpdateDrawing: drawing)
        needsDisplay = true
    }
}

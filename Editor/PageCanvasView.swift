//
//  PageCanvasView.swift
//  NotabilityClone
//
//  NSViewRepresentable wrapper for InkCanvasNSView
//

import SwiftUI
import PencilKit

struct PageCanvasView: NSViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var highlightedStrokeIndices: Set<Int>
    var selectedTool: InkTool
    var strokeColor: Color
    var strokeWidth: CGFloat
    var recordingStartTime: Date?
    var onCompleteStroke: ((Int, TimeInterval?) -> Void)?
    var onSelectStroke: ((Int) -> Void)?
    var onDrawingChanged: ((PKDrawing) -> Void)?

    func makeNSView(context: Context) -> InkCanvasNSView {
        let canvas = InkCanvasNSView(frame: .zero)
        canvas.delegate = context.coordinator
        canvas.recordingStartTime = recordingStartTime
        canvas.setDrawing(drawing)
        canvas.setTool(selectedTool, color: NSColor(strokeColor), width: strokeWidth)
        return canvas
    }

    func updateNSView(_ nsView: InkCanvasNSView, context: Context) {
        context.coordinator.parent = self
        nsView.recordingStartTime = recordingStartTime
        nsView.setTool(selectedTool, color: NSColor(strokeColor), width: strokeWidth)
        nsView.highlightStrokes(indices: highlightedStrokeIndices)

        if !nsView.isActivelyDrawing {
            nsView.setDrawing(drawing)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, InkCanvasDelegate {
        var parent: PageCanvasView

        init(_ parent: PageCanvasView) {
            self.parent = parent
        }

        func inkCanvas(_ canvas: InkCanvasNSView, didCompleteStrokeAtIndex index: Int, timeOffset: TimeInterval?) {
            parent.onCompleteStroke?(index, timeOffset)
        }

        func inkCanvas(_ canvas: InkCanvasNSView, didSelectStrokeAtIndex index: Int) {
            parent.onSelectStroke?(index)
        }

        func inkCanvas(_ canvas: InkCanvasNSView, didUpdateDrawing drawing: PKDrawing) {
            parent.drawing = drawing
            parent.onDrawingChanged?(drawing)
        }

        func inkCanvas(_ canvas: InkCanvasNSView, didRemoveStrokesAtIndices indices: [Int]) {
            parent.drawing = canvas.drawing
            parent.onDrawingChanged?(canvas.drawing)
        }
    }
}

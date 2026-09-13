//
//  PDFPageHostView.swift
//  NotabilityClone
//
//  PDFView with ink overlay per page
//

import AppKit
import PDFKit
import SwiftUI
import PencilKit

final class PDFInkOverlayProvider: NSObject, PDFPageOverlayViewProvider {
    var makeOverlayView: ((PDFPage) -> InkCanvasNSView)?
    var configureOverlay: ((InkCanvasNSView, PDFPage) -> Void)?

    func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> NSView? {
        let canvas = makeOverlayView?(page) ?? InkCanvasNSView(frame: .zero)
        configureOverlay?(canvas, page)
        return canvas
    }
}

struct PDFPageHostView: NSViewRepresentable {
    let pdfURL: URL
    @Binding var pageDrawings: [Int: PKDrawing]
    var selectedTool: InkTool
    var strokeColor: Color
    var strokeWidth: CGFloat
    var recordingStartTime: Date?
    var onDrawingChanged: ((Int, PKDrawing) -> Void)?

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView(frame: .zero)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        if let document = PDFDocument(url: pdfURL) {
            pdfView.document = document
        }

        let provider = PDFInkOverlayProvider()
        provider.makeOverlayView = { _ in InkCanvasNSView(frame: .zero) }
        provider.configureOverlay = { canvas, page in
            let index = page.document?.index(for: page) ?? 0
            context.coordinator.attach(canvas: canvas, pageIndex: index, parent: self)
        }
        pdfView.pageOverlayViewProvider = provider
        context.coordinator.pdfView = pdfView

        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refreshOverlays()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, InkCanvasDelegate {
        var parent: PDFPageHostView?
        weak var pdfView: PDFView?
        private var canvases: [Int: InkCanvasNSView] = [:]

        func attach(canvas: InkCanvasNSView, pageIndex: Int, parent: PDFPageHostView) {
            self.parent = parent
            canvas.delegate = self
            canvas.recordingStartTime = parent.recordingStartTime
            canvas.setTool(parent.selectedTool, color: NSColor(parent.strokeColor), width: parent.strokeWidth)
            if let drawing = parent.pageDrawings[pageIndex] {
                canvas.setDrawing(drawing)
            }
            canvases[pageIndex] = canvas
        }

        func refreshOverlays() {
            guard let parent else { return }
            for (index, canvas) in canvases {
                canvas.recordingStartTime = parent.recordingStartTime
                canvas.setTool(parent.selectedTool, color: NSColor(parent.strokeColor), width: parent.strokeWidth)
                if !canvas.isActivelyDrawing, let drawing = parent.pageDrawings[index] {
                    canvas.setDrawing(drawing)
                }
            }
        }

        func inkCanvas(_ canvas: InkCanvasNSView, didCompleteStrokeAtIndex index: Int, timeOffset: TimeInterval?) {
            guard let pageIndex = canvases.first(where: { $0.value === canvas })?.key else { return }
            parent?.onDrawingChanged?(pageIndex, canvas.drawing)
        }

        func inkCanvas(_ canvas: InkCanvasNSView, didSelectStrokeAtIndex index: Int) {}

        func inkCanvas(_ canvas: InkCanvasNSView, didUpdateDrawing drawing: PKDrawing) {
            guard let pageIndex = canvases.first(where: { $0.value === canvas })?.key else { return }
            parent?.pageDrawings[pageIndex] = drawing
            parent?.onDrawingChanged?(pageIndex, drawing)
        }

        func inkCanvas(_ canvas: InkCanvasNSView, didRemoveStrokesAtIndices indices: [Int]) {
            guard let pageIndex = canvases.first(where: { $0.value === canvas })?.key else { return }
            parent?.pageDrawings[pageIndex] = canvas.drawing
            parent?.onDrawingChanged?(pageIndex, canvas.drawing)
        }
    }
}

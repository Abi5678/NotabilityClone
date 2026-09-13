//
//  Page.swift
//  NotabilityClone
//
//  Page model - contains drawing data, text runs, and timed marks
//

import Foundation
import SwiftData
import PencilKit

@Model
final class Page {
    var pageNumber: Int
    var pdfPageIndex: Int?
    var drawingData: Data?
    var note: Note?
    @Relationship(deleteRule: .cascade, inverse: \TimedMark.page) var marks: [TimedMark] = []
    @Relationship(deleteRule: .cascade, inverse: \TextRun.page) var textRuns: [TextRun] = []

    init(pageNumber: Int, pdfPageIndex: Int? = nil) {
        self.pageNumber = pageNumber
        self.pdfPageIndex = pdfPageIndex
    }

    func getDrawing() -> PKDrawing {
        guard let data = drawingData else { return PKDrawing() }
        return (try? PKDrawing(data: data)) ?? PKDrawing()
    }

    func setDrawing(_ drawing: PKDrawing) {
        drawingData = drawing.dataRepresentation()
    }
}

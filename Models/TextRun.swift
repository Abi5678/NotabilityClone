//
//  TextRun.swift
//  NotabilityClone
//
//  TextRun - a block of typed text with optional time sync
//

import Foundation
import SwiftData

@Model
final class TextRun {
    var text: String
    var xPosition: CGFloat
    var yPosition: CGFloat
    var fontSize: CGFloat
    var fontName: String
    var recordingTimeOffset: TimeInterval?
    var page: Page?

    init(text: String, xPosition: CGFloat, yPosition: CGFloat, fontSize: CGFloat = 14.0, fontName: String = "Helvetica") {
        self.text = text
        self.xPosition = xPosition
        self.yPosition = yPosition
        self.fontSize = fontSize
        self.fontName = fontName
    }
}

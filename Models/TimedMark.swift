//
//  TimedMark.swift
//  NotabilityClone
//
//  TimedMark - links a stroke to a time offset in a recording
//

import Foundation
import SwiftData

@Model
final class TimedMark {
    var id: UUID
    var recordingID: UUID
    var timeOffset: TimeInterval
    var strokeIndexStart: Int
    var strokeIndexEnd: Int
    var page: Page?
    var recording: Recording?

    init(recordingID: UUID, timeOffset: TimeInterval, strokeIndexStart: Int, strokeIndexEnd: Int) {
        self.id = UUID()
        self.recordingID = recordingID
        self.timeOffset = timeOffset
        self.strokeIndexStart = strokeIndexStart
        self.strokeIndexEnd = strokeIndexEnd
    }
}

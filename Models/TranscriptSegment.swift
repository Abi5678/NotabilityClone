//
//  TranscriptSegment.swift
//  NotabilityClone
//

import Foundation
import SwiftData

@Model
final class TranscriptSegment {
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var artifact: MeetingArtifact?

    init(startTime: TimeInterval, endTime: TimeInterval, text: String) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
    }
}

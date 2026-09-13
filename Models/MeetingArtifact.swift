//
//  MeetingArtifact.swift
//  NotabilityClone
//

import Foundation
import SwiftData

@Model
final class MeetingArtifact {
    var id: UUID
    var status: String
    var errorMessage: String?
    var fullTranscript: String
    var summary: String
    var highlightsJSON: Data?
    var pdfRelativePath: String?
    var processedAt: Date?
    var recording: Recording?
    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.artifact) var segments: [TranscriptSegment] = []
    @Relationship(deleteRule: .cascade, inverse: \MeetingChatMessage.artifact) var chatMessages: [MeetingChatMessage] = []

    init(recording: Recording? = nil) {
        self.id = UUID()
        self.status = MeetingProcessingStatus.pending.rawValue
        self.fullTranscript = ""
        self.summary = ""
        self.recording = recording
    }
}

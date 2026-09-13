//
//  Recording.swift
//  NotabilityClone
//
//  Recording model - audio file metadata
//

import Foundation
import SwiftData

@Model
final class Recording {
    var id: UUID
    var name: String
    var fileRelativePath: String
    var startedAt: Date
    var duration: TimeInterval
    var note: Note?
    @Relationship(deleteRule: .cascade, inverse: \TimedMark.recording) var marks: [TimedMark] = []
    @Relationship(deleteRule: .cascade, inverse: \MeetingArtifact.recording) var meetingArtifact: MeetingArtifact?

    init(name: String, fileRelativePath: String, startedAt: Date) {
        self.id = UUID()
        self.name = name
        self.fileRelativePath = fileRelativePath
        self.startedAt = startedAt
        self.duration = 0
    }
}

extension Recording: Identifiable {}

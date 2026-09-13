//
//  MeetingChatMessage.swift
//  NotabilityClone
//

import Foundation
import SwiftData

@Model
final class MeetingChatMessage {
    var role: String
    var content: String
    var createdAt: Date
    var artifact: MeetingArtifact?

    init(role: String, content: String) {
        self.role = role
        self.content = content
        self.createdAt = Date()
    }
}

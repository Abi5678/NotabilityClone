//
//  Subject.swift
//  NotabilityClone
//
//  Subject model - top-level organization container
//

import Foundation
import SwiftData

@Model
final class Subject {
    var name: String
    var color: String // Hex color code
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \Notebook.subject) var notebooks: [Notebook] = []

    init(name: String, color: String = "#007AFF") {
        self.name = name
        self.color = color
        self.createdAt = Date()
    }
}

//
//  Notebook.swift
//  NotabilityClone
//
//  Notebook model - contains notes within a subject
//

import Foundation
import SwiftData

@Model
final class Notebook {
    var name: String
    var createdAt: Date
    var subject: Subject?
    @Relationship(deleteRule: .cascade, inverse: \Note.notebook) var notes: [Note] = []

    init(name: String, subject: Subject? = nil) {
        self.name = name
        self.createdAt = Date()
        self.subject = subject
    }
}

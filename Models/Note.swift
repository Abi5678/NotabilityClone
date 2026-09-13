//
//  Note.swift
//  NotabilityClone
//
//  Note model - contains pages and recordings
//

import Foundation
import SwiftData

@Model
final class Note {
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var notebook: Notebook?
    @Relationship(deleteRule: .cascade, inverse: \Page.note) var pages: [Page] = []
    @Relationship(deleteRule: .cascade, inverse: \Recording.note) var recordings: [Recording] = []
    var sourcePDFRelativePath: String?

    init(title: String, notebook: Notebook? = nil) {
        self.title = title
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.notebook = notebook
    }

    func touch() {
        modifiedAt = Date()
    }
}

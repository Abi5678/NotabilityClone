//
//  NotebookStore.swift
//  NotabilityClone
//
//  Helpers for subject → notebook hierarchy
//

import Foundation
import SwiftData

enum NotebookStore {
    static let defaultNotebookName = "Notes"

    /// Returns the default notebook for a subject, creating one if needed.
    @discardableResult
    static func defaultNotebook(for subject: Subject, in context: ModelContext) -> Notebook {
        if let existing = subject.notebooks.first(where: { $0.name == defaultNotebookName }) {
            return existing
        }
        let notebook = Notebook(name: defaultNotebookName, subject: subject)
        context.insert(notebook)
        subject.notebooks.append(notebook)
        return notebook
    }

    /// Notebook to use when creating a note for the given subject selection.
    static func notebookForNewNote(subject: Subject?, in context: ModelContext) -> Notebook? {
        guard let subject else { return nil }
        return defaultNotebook(for: subject, in: context)
    }
}

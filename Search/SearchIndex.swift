//
//  SearchIndex.swift
//  NotabilityClone
//

import Foundation
import SwiftData

struct SearchIndex {
    static func search(query: String, in context: ModelContext) -> [Note] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let titleDescriptor = FetchDescriptor<Note>(
            predicate: #Predicate { note in
                note.title.localizedStandardContains(trimmed)
            },
            sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]
        )

        let textDescriptor = FetchDescriptor<TextRun>(
            predicate: #Predicate { run in
                run.text.localizedStandardContains(trimmed)
            }
        )

        let transcriptDescriptor = FetchDescriptor<MeetingArtifact>(
            predicate: #Predicate { artifact in
                artifact.fullTranscript.localizedStandardContains(trimmed) ||
                artifact.summary.localizedStandardContains(trimmed)
            }
        )

        var results: [Note] = []
        var seen = Set<PersistentIdentifier>()

        func append(_ note: Note) {
            guard !seen.contains(note.persistentModelID) else { return }
            seen.insert(note.persistentModelID)
            results.append(note)
        }

        if let titleMatches = try? context.fetch(titleDescriptor) {
            titleMatches.forEach(append)
        }

        if let textMatches = try? context.fetch(textDescriptor) {
            for run in textMatches {
                if let note = run.page?.note { append(note) }
            }
        }

        if let transcriptMatches = try? context.fetch(transcriptDescriptor) {
            for artifact in transcriptMatches {
                if let note = artifact.recording?.note { append(note) }
            }
        }

        return results
    }
}

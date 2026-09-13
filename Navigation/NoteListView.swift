//
//  NoteListView.swift
//  NotabilityClone
//
//  Redesigned in Minimalist Monochrome style
//

import SwiftUI
import SwiftData

struct NoteListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]
    @Binding var selectedNote: Note?
    var selectedSubject: Subject?
    var overrideNotes: [Note]?

    @State private var showingNewNote = false
    @State private var newNoteTitle = ""
    @State private var noteToRename: Note?
    @State private var renameNoteTitle = ""

    var filteredNotes: [Note] {
        if let overrideNotes {
            return overrideNotes
        }
        if let subject = selectedSubject {
            return notes.filter { $0.notebook?.subject?.persistentModelID == subject.persistentModelID }
        }
        return notes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                MonochromeLabel(title: selectedSubject?.name ?? "All Notes")
                Spacer()
                Button(action: { showingNewNote = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(MonochromeTypography.sm())
                        Text("New Note")
                            .font(MonochromeTypography.sm())
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(MonochromeColors.foreground)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            MonochromeDivider(weight: MonochromeBorders.thick)

            if filteredNotes.isEmpty {
                VStack(spacing: 24) {
                    Spacer()
                    MonochromeLabel(title: "No Notes")
                    Text("Create a note to get started")
                        .font(MonochromeTypography.base())
                        .foregroundColor(MonochromeColors.mutedForeground)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .texturedBackground(pattern: .grid)
            } else {
                List(filteredNotes, selection: $selectedNote) { note in
                    NoteListRow(note: note)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .tag(note)
                        .contextMenu {
                            Button("Rename") {
                                noteToRename = note
                                renameNoteTitle = note.title
                            }
                            Button("Delete", role: .destructive) {
                                deleteNote(note)
                            }
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(MonochromeColors.background)
        .texturedBackground(pattern: .horizontalLines)
        .frame(minWidth: 320)
        .sheet(isPresented: $showingNewNote) {
            NewNoteSheet(
                title: $newNoteTitle,
                onSave: createNote,
                onCancel: { newNoteTitle = "" }
            )
        }
        .sheet(item: $noteToRename) { note in
            RenameSheet(
                title: "Rename Note",
                name: $renameNoteTitle,
                onSave: {
                    note.title = renameNoteTitle
                    note.touch()
                    noteToRename = nil
                },
                onCancel: { noteToRename = nil }
            )
        }
    }

    private func createNote() {
        guard !newNoteTitle.isEmpty else { return }
        let notebook = NotebookStore.notebookForNewNote(subject: selectedSubject, in: modelContext)
        let note = Note(title: newNoteTitle, notebook: notebook)
        modelContext.insert(note)
        if let notebook {
            notebook.notes.append(note)
        }
        selectedNote = note
        showingNewNote = false
        newNoteTitle = ""
    }

    private func deleteNote(_ note: Note) {
        if selectedNote?.persistentModelID == note.persistentModelID {
            selectedNote = nil
        }
        modelContext.delete(note)
    }
}

extension Note: Identifiable {}

struct NoteListRow: View {
    let note: Note

    var body: some View {
        MonochromeListItem(showBorder: true) {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.title)
                    .font(MonochromeTypography.lg())
                    .lineLimit(1)

                HStack(spacing: 16) {
                    Text(note.modifiedAt, style: .date)
                        .font(MonochromeTypography.xs())
                        .foregroundColor(MonochromeColors.mutedForeground)

                    if !note.pages.isEmpty {
                        Text("\(note.pages.count) pages")
                            .font(MonochromeTypography.xs())
                            .foregroundColor(MonochromeColors.mutedForeground)
                    }

                    if !note.recordings.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(MonochromeTypography.xs())
                            Text("\(note.recordings.count) recordings")
                                .font(MonochromeTypography.xs())
                        }
                        .foregroundColor(MonochromeColors.mutedForeground)
                    }
                }
            }
        }
    }
}

struct NewNoteSheet: View {
    @Binding var title: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            MonochromeHeading(title: "New Note", level: .h4)

            MonochromeTextField(text: $title, placeholder: "Note title")
                .focused($isFocused)
                .onAppear { isFocused = true }

            HStack {
                MonochromeButton(title: "Cancel", variant: .ghost, action: onCancel)
                Spacer()
                MonochromeButton(title: "Create", variant: .primary, icon: "plus", action: onSave)
                    .disabled(title.isEmpty)
            }
        }
        .padding(40)
        .frame(width: 400)
        .background(MonochromeColors.background)
    }
}

#Preview {
    NoteListView(selectedNote: .constant(nil), selectedSubject: nil)
        .modelContainer(for: [Note.self], inMemory: true)
}

//
//  SubjectSidebarView.swift
//  NotabilityClone
//
//  Redesigned in Minimalist Monochrome style
//

import SwiftUI
import SwiftData

struct SubjectSidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subject.createdAt) private var subjects: [Subject]
    @Binding var selectedSubject: Subject?
    @State private var showingNewSubject = false
    @State private var newSubjectName = ""
    @State private var subjectToRename: Subject?
    @State private var renameSubjectName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                MonochromeLabel(title: "Subjects")
                Spacer()
                Button(action: { showingNewSubject = true }) {
                    Image(systemName: "plus")
                        .font(MonochromeTypography.sm())
                }
                .buttonStyle(.plain)
                .foregroundColor(MonochromeColors.mutedForeground)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)

            MonochromeDivider(weight: MonochromeBorders.thick)

            List(selection: $selectedSubject) {
                Section {
                    Text("All Notes")
                        .font(MonochromeTypography.base())
                        .tag(Optional<Subject>.none)
                }

                Section("Subjects") {
                    ForEach(subjects) { subject in
                        MonochromeListItem(showBorder: false) {
                            HStack(spacing: 16) {
                                Rectangle()
                                    .fill(Color(hex: subject.color))
                                    .frame(width: 12, height: 12)

                                Text(subject.name)
                                    .font(MonochromeTypography.base())
                                    .lineLimit(1)
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .tag(Optional(subject))
                        .contextMenu {
                            Button("Rename") {
                                subjectToRename = subject
                                renameSubjectName = subject.name
                            }
                            Button("Delete", role: .destructive) {
                                deleteSubject(subject)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            if subjects.isEmpty {
                VStack(spacing: 16) {
                    MonochromeLabel(title: "No Subjects")
                    Text("Create your first subject")
                        .font(MonochromeTypography.sm())
                        .foregroundColor(MonochromeColors.mutedForeground)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(MonochromeColors.background)
        .texturedBackground(pattern: .verticalLines)
        .frame(minWidth: 240)
        .sheet(isPresented: $showingNewSubject) {
            NewSubjectSheet(
                name: $newSubjectName,
                onSave: createSubject,
                onCancel: { newSubjectName = "" }
            )
        }
        .sheet(item: $subjectToRename) { subject in
            RenameSheet(
                title: "Rename Subject",
                name: $renameSubjectName,
                onSave: {
                    subject.name = renameSubjectName
                    subjectToRename = nil
                },
                onCancel: { subjectToRename = nil }
            )
        }
    }

    private func createSubject() {
        guard !newSubjectName.isEmpty else { return }
        let subject = Subject(name: newSubjectName, color: "#000000")
        modelContext.insert(subject)
        _ = NotebookStore.defaultNotebook(for: subject, in: modelContext)
        selectedSubject = subject
        showingNewSubject = false
        newSubjectName = ""
    }

    private func deleteSubject(_ subject: Subject) {
        if selectedSubject?.persistentModelID == subject.persistentModelID {
            selectedSubject = nil
        }
        modelContext.delete(subject)
    }
}

extension Subject: Identifiable {}

struct RenameSheet: View {
    let title: String
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            MonochromeHeading(title: title, level: .h4)

            MonochromeTextField(text: $name, placeholder: "Name")
                .focused($isFocused)
                .onAppear { isFocused = true }

            HStack {
                MonochromeButton(title: "Cancel", variant: .ghost, action: onCancel)
                Spacer()
                MonochromeButton(title: "Save", variant: .primary, action: onSave)
                    .disabled(name.isEmpty)
            }
        }
        .padding(40)
        .frame(width: 400)
        .background(MonochromeColors.background)
    }
}

struct NewSubjectSheet: View {
    @Binding var name: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            MonochromeHeading(title: "New Subject", level: .h4)

            MonochromeTextField(text: $name, placeholder: "Subject name")
                .focused($isFocused)
                .onAppear { isFocused = true }

            HStack {
                MonochromeButton(title: "Cancel", variant: .ghost, action: onCancel)
                Spacer()
                MonochromeButton(title: "Create", variant: .primary, icon: "plus", action: onSave)
                    .disabled(name.isEmpty)
            }
        }
        .padding(40)
        .frame(width: 400)
        .background(MonochromeColors.background)
    }
}

#Preview {
    SubjectSidebarView(selectedSubject: .constant(nil))
        .modelContainer(for: [Subject.self], inMemory: true)
}

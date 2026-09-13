import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSubject: Subject?
    @State private var selectedNote: Note?
    @State private var searchQuery = ""
    @State private var searchResults: [Note] = []
    @State private var showingAPIKeySettings = false

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                SubjectSidebarView(selectedSubject: $selectedSubject)
                MonochromeDivider(weight: MonochromeBorders.hairline)
                Button(action: { showingAPIKeySettings = true }) {
                    HStack(spacing: 8) {
                        Image(systemName: "gearshape")
                        Text("Settings")
                    }
                    .font(MonochromeTypography.xs())
                }
                .buttonStyle(.plain)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } content: {
            VStack(spacing: 0) {
                searchBar
                NoteListView(
                    selectedNote: $selectedNote,
                    selectedSubject: selectedSubject,
                    overrideNotes: searchQuery.isEmpty ? nil : searchResults
                )
            }
        } detail: {
            if let note = selectedNote {
                NoteEditorView(note: note)
                    .id(note.persistentModelID)
            } else {
                EmptyStateView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1200, minHeight: 750)
        .background(MonochromeColors.background)
        .sheet(isPresented: $showingAPIKeySettings) {
            APIKeySettingsView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAPIKeySettings)) { _ in
            showingAPIKeySettings = true
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(MonochromeColors.mutedForeground)
            TextField("Search notes", text: $searchQuery)
                .textFieldStyle(.plain)
                .onSubmit { performSearch() }
            if !searchQuery.isEmpty {
                Button("Clear") {
                    searchQuery = ""
                    searchResults = []
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(MonochromeColors.background)
        .onChange(of: searchQuery) { _, newValue in
            if newValue.isEmpty {
                searchResults = []
            } else {
                performSearch()
            }
        }
    }

    private func performSearch() {
        searchResults = SearchIndex.search(query: searchQuery, in: modelContext)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 24) {
                MonochromeLabel(title: "No Note Selected")

                Text("Select a note from the list")
                    .font(MonochromeTypography.xl3())
                    .fontWeight(.medium)
                    .tracking(MonochromeTypography.trackingTight)

                Text("or create a new one to begin")
                    .font(MonochromeTypography.base())
                    .foregroundColor(MonochromeColors.mutedForeground)
            }

            Spacer()

            MonochromeDivider(weight: MonochromeBorders.thick)
                .frame(maxWidth: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MonochromeColors.background)
        .texturedBackground(pattern: .grid)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Subject.self, Notebook.self, Note.self], inMemory: true)
}

//
//  NoteEditorView.swift
//  NotabilityClone
//
//  Page display, toolbar, audio sync
//

import SwiftUI
import SwiftData
import PencilKit
import UniformTypeIdentifiers
import PDFKit

enum NoteWorkspaceTab: String, CaseIterable, Identifiable {
    case learn = "Learn"
    case write = "Write"
    var id: String { rawValue }
}

struct NoteEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var note: Note

    @State private var currentPageIndex = 0
    @State private var drawing = PKDrawing()
    @State private var pdfPageDrawings: [Int: PKDrawing] = [:]
    @State private var selectedTool: InkTool = .pen
    @State private var selectedColor: Color = .black
    @State private var selectedWidth: CGFloat = 4.0
    @State private var highlightedStrokeIndices: Set<Int> = []

    @StateObject private var recordingController = RecordingController()
    @StateObject private var playbackController = PlaybackController()
    @StateObject private var syncEngine = SyncEngine()

    @State private var currentRecording: Recording?
    @State private var selectedRecording: Recording?
    @State private var recordingStartTime: Date?
    @State private var audioErrorMessage: String?
    @State private var pdfDocumentURL: URL?
    @State private var hasAPIKey = NIMConfiguration.hasAPIKey
    @State private var workspaceTab: NoteWorkspaceTab = .learn

    private var sortedPages: [Page] {
        note.pages.sorted { $0.pageNumber < $1.pageNumber }
    }

    private var currentPage: Page? {
        guard currentPageIndex >= 0, currentPageIndex < sortedPages.count else { return nil }
        return sortedPages[currentPageIndex]
    }

    private var isRecording: Bool { recordingController.isRecording }
    private var isPlaying: Bool { playbackController.isPlaying }

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            MonochromeDivider(weight: MonochromeBorders.ultra)
            audioControlBar
            MonochromeDivider(weight: MonochromeBorders.thick)

            Group {
                switch workspaceTab {
                case .learn:
                    LearnWorkspaceView(
                        noteTitle: note.title,
                        note: note,
                        selectedRecording: $selectedRecording,
                        isRecordingActive: isRecording,
                        currentRecordingID: currentRecording?.id,
                        onSeek: { time in seek(to: time) },
                        onProcess: { recording in ensureMeetingProcessing(for: recording) },
                        onRetry: { recording in retryMeetingProcessing(for: recording) }
                    )
                case .write:
                    writeWorkspace
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let audioErrorMessage {
                Text(audioErrorMessage)
                    .font(MonochromeTypography.sm())
                    .foregroundColor(.red)
                    .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MonochromeColors.background)
        .onAppear { loadEditorState() }
        .onDisappear { cleanup() }
        .onChange(of: note.persistentModelID) { _, _ in loadEditorState() }
        .onChange(of: recordingController.error?.localizedDescription) { _, newValue in
            audioErrorMessage = newValue
        }
        .onChange(of: playbackController.error?.localizedDescription) { _, newValue in
            audioErrorMessage = newValue
        }
        .onChange(of: recordingController.recordingTime) { _, _ in
            // trigger time display refresh while recording
        }
        .onChange(of: playbackController.currentTime) { _, newValue in
            currentPlaybackTime = newValue
            updateSyncHighlight(at: newValue)
        }
        .onChange(of: workspaceTab) { _, tab in
            if tab == .write {
                ensureWriteReady()
            }
            rebuildSyncMarks()
        }
        .onChange(of: currentPageIndex) { _, _ in
            loadCurrentPageDrawing()
            rebuildSyncMarks()
        }
        .onChange(of: selectedRecording?.persistentModelID) { _, _ in
            if let recording = selectedRecording {
                ensureMeetingProcessing(for: recording)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .apiKeyDidChange)) { _ in
            hasAPIKey = NIMConfiguration.hasAPIKey
            if let recording = selectedRecording {
                ensureMeetingProcessing(for: recording)
            }
        }
    }

    @State private var currentPlaybackTime: TimeInterval = 0

    // MARK: - Workspace chrome

    private var workspaceHeader: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(MonochromeTypography.xl2())
                    .fontWeight(.bold)
                Text(note.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(MonochromeTypography.xs())
                    .foregroundColor(MonochromeColors.mutedForeground)
            }

            Picker("", selection: $workspaceTab) {
                ForEach(NoteWorkspaceTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 180)

            if isRecording {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Recording")
                        .font(MonochromeTypography.sm())
                        .foregroundColor(.red)
                }
            }

            Spacer()

            if workspaceTab == .write {
                HStack(spacing: 8) {
                    if !sortedPages.isEmpty {
                        Button(action: previousPage) { Image(systemName: "chevron.left") }
                            .disabled(currentPageIndex <= 0)
                        Text("Page \(currentPageIndex + 1)/\(sortedPages.count)")
                            .font(MonochromeTypography.sm())
                        Button(action: nextPage) { Image(systemName: "chevron.right") }
                            .disabled(currentPageIndex >= sortedPages.count - 1)
                    }
                    MonochromeButton(title: sortedPages.isEmpty ? "Add Blank Page" : "Add Page", variant: .outline, icon: "plus") {
                        addPage()
                    }
                    if pdfDocumentURL == nil {
                        MonochromeButton(title: "Import PDF", variant: .ghost) { importPDF() }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(MonochromeColors.background)
    }

    private var audioControlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button(action: toggleRecording) {
                    ZStack {
                        if isRecording {
                            RoundedRectangle(cornerRadius: 0).fill(Color.red).frame(width: 36, height: 36)
                        } else {
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(MonochromeColors.border, lineWidth: MonochromeBorders.thin)
                                .frame(width: 36, height: 36)
                            Circle().fill(Color.red).frame(width: 14, height: 14)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isPlaying)

                Button(action: togglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(isRecording || note.recordings.isEmpty)

                Text(timeDisplay)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(MonochromeColors.mutedForeground)
                    .frame(width: 52, alignment: .leading)

                if !note.recordings.isEmpty {
                    MonochromeVerticalDivider(weight: MonochromeBorders.hairline)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(sortedRecordings, id: \.id) { recording in
                                recordingChip(recording)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)

            if isPlaying || isRecording {
                playbackScrubber
            }
        }
        .background(MonochromeColors.background)
    }

    private var sortedRecordings: [Recording] {
        note.recordings.sorted { $0.startedAt > $1.startedAt }
    }

    private func recordingChip(_ recording: Recording) -> some View {
        let isSelected = selectedRecording?.id == recording.id
        return Button(action: {
            selectedRecording = recording
            rebuildSyncMarks()
            if workspaceTab == .learn {
                ensureMeetingProcessing(for: recording)
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 10))
                Text(recording.name)
                    .font(MonochromeTypography.xs())
                    .lineLimit(1)
                if recording.duration > 0 {
                    Text(formatTime(recording.duration))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(MonochromeColors.mutedForeground)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? MonochromeColors.foreground : MonochromeColors.background)
            .foregroundColor(isSelected ? MonochromeColors.background : MonochromeColors.foreground)
            .overlay(Rectangle().stroke(MonochromeColors.border, lineWidth: MonochromeBorders.hairline))
        }
        .buttonStyle(.plain)
    }

    private var writeWorkspace: some View {
        HStack(spacing: 0) {
            ToolPaletteView(
                selectedTool: $selectedTool,
                selectedColor: $selectedColor,
                selectedWidth: $selectedWidth
            )
            .frame(width: 220)

            MonochromeVerticalDivider(weight: MonochromeBorders.thick)

            canvasArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var canvasArea: some View {
        ZStack {
            Color.white

            if let pdfURL = pdfDocumentURL {
                PDFPageHostView(
                    pdfURL: pdfURL,
                    pageDrawings: $pdfPageDrawings,
                    selectedTool: selectedTool,
                    strokeColor: selectedColor,
                    strokeWidth: selectedWidth,
                    recordingStartTime: recordingStartTime,
                    onDrawingChanged: { pageIndex, newDrawing in
                        savePDFPageDrawing(pageIndex: pageIndex, drawing: newDrawing)
                    }
                )
            } else if let page = currentPage {
                PageCanvasView(
                    drawing: $drawing,
                    highlightedStrokeIndices: $highlightedStrokeIndices,
                    selectedTool: selectedTool,
                    strokeColor: selectedColor,
                    strokeWidth: selectedWidth,
                    recordingStartTime: recordingStartTime,
                    onCompleteStroke: handleStrokeComplete,
                    onSelectStroke: handleStrokeTap,
                    onDrawingChanged: { newDrawing in
                        saveDrawing(newDrawing, page: page)
                    }
                )
                .id(page.persistentModelID)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                TextBoxOverlay(
                    page: page,
                    recordingStartTime: recordingStartTime,
                    highlightedTextRunID: nil,
                    onCommit: { _, _ in
                        note.touch()
                    }
                )
            } else {
                EmptyCanvasState(onAddPage: addPage)
            }
        }
    }

    private var timeDisplay: String {
        let time = isRecording ? recordingController.recordingTime : currentPlaybackTime
        return formatTime(time)
    }

    private var playbackScrubber: some View {
        HStack(spacing: 0) {
            Text(formatTime(currentPlaybackTime))
                .font(MonochromeTypography.xs())
                .foregroundColor(MonochromeColors.mutedForeground)
                .padding(.horizontal, 16)

            Slider(
                value: Binding(
                    get: { currentPlaybackTime },
                    set: { newValue in
                        currentPlaybackTime = newValue
                        seek(to: newValue)
                    }
                ),
                in: 0...(activeRecording?.duration ?? max(currentPlaybackTime, 1))
            ) { editing in
                if !editing {
                    seek(to: currentPlaybackTime)
                }
            }
            .tint(MonochromeColors.foreground)

            Text(formatTime(activeRecording?.duration ?? 0))
                .font(MonochromeTypography.xs())
                .foregroundColor(MonochromeColors.mutedForeground)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(MonochromeColors.background)
    }

    private var activeRecording: Recording? {
        selectedRecording ?? currentRecording ?? sortedRecordings.first
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Drawing / Pages

    private func ensureWriteReady() {
        saveCurrentPageDrawing()
        if pdfDocumentURL == nil && sortedPages.isEmpty {
            addPage()
        } else if currentPage == nil, !sortedPages.isEmpty {
            currentPageIndex = 0
            loadCurrentPageDrawing()
        }
    }

    private func loadEditorState() {
        currentPageIndex = 0
        loadCurrentPageDrawing()
        loadPDFIfNeeded()
        selectedRecording = note.recordings.sorted(by: { $0.startedAt > $1.startedAt }).first
        if !note.recordings.isEmpty {
            workspaceTab = .learn
        } else if sortedPages.isEmpty && pdfDocumentURL == nil {
            workspaceTab = .write
        }
        rebuildSyncMarks()
        if let recording = selectedRecording {
            ensureMeetingProcessing(for: recording)
        }
    }

    private func loadCurrentPageDrawing() {
        drawing = currentPage?.getDrawing() ?? PKDrawing()
    }

    private func loadPDFIfNeeded() {
        guard let relative = note.sourcePDFRelativePath else {
            pdfDocumentURL = nil
            return
        }
        pdfDocumentURL = RecordingFileStore.shared.getPDFURL(for: relative)
        pdfPageDrawings = [:]
        for page in sortedPages {
            if let pdfIndex = page.pdfPageIndex {
                pdfPageDrawings[pdfIndex] = page.getDrawing()
            }
        }
    }

    private func saveDrawing(_ newDrawing: PKDrawing, page: Page) {
        page.setDrawing(newDrawing)
        note.touch()
    }

    private func savePDFPageDrawing(pageIndex: Int, drawing: PKDrawing) {
        if let page = sortedPages.first(where: { $0.pdfPageIndex == pageIndex }) {
            page.setDrawing(drawing)
            note.touch()
        }
    }

    private func addPage() {
        let nextNumber = (sortedPages.map(\.pageNumber).max() ?? -1) + 1
        let page = Page(pageNumber: nextNumber)
        modelContext.insert(page)
        page.note = note
        note.pages.append(page)
        note.touch()
        currentPageIndex = sortedPages.firstIndex(where: { $0.persistentModelID == page.persistentModelID })
            ?? max(0, sortedPages.count - 1)
        drawing = PKDrawing()
    }

    private func previousPage() {
        saveCurrentPageDrawing()
        currentPageIndex = max(0, currentPageIndex - 1)
        loadCurrentPageDrawing()
    }

    private func nextPage() {
        saveCurrentPageDrawing()
        currentPageIndex = min(sortedPages.count - 1, currentPageIndex + 1)
        loadCurrentPageDrawing()
    }

    private func saveCurrentPageDrawing() {
        if let page = currentPage {
            page.setDrawing(drawing)
        }
    }

    private func handleStrokeComplete(index: Int, timeOffset: TimeInterval?) {
        guard let page = currentPage else { return }
        note.touch()

        guard let timeOffset, let recording = currentRecording else { return }

        let mark = TimedMark(
            recordingID: recording.id,
            timeOffset: timeOffset,
            strokeIndexStart: index,
            strokeIndexEnd: index
        )
        mark.page = page
        mark.recording = recording
        modelContext.insert(mark)
        recording.marks.append(mark)
        page.marks.append(mark)
        rebuildSyncMarks()
    }

    private func handleStrokeTap(index: Int) {
        guard let time = syncEngine.timeOffset(forStrokeIndex: index) else { return }
        seek(to: time)
    }

    // MARK: - Audio

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        workspaceTab = .learn
        recordingController.requestPermission { granted in
            guard granted else {
                audioErrorMessage = "Microphone permission denied."
                return
            }

            DispatchQueue.main.async {
                let fileStore = RecordingFileStore.shared
                guard let recordingURL = fileStore.createRecordingFile() else {
                    audioErrorMessage = "Could not create recording file."
                    return
                }

                let filename = recordingURL.deletingPathExtension().lastPathComponent
                let recording = Recording(
                    name: "Recording \(Date().formatted(date: .omitted, time: .shortened))",
                    fileRelativePath: "\(filename).m4a",
                    startedAt: Date()
                )
                modelContext.insert(recording)
                recording.note = note
                note.recordings.append(recording)
                note.touch()

                currentRecording = recording
                selectedRecording = recording
                recordingStartTime = Date()
                recordingController.startRecording(at: recordingURL)
            }
        }
    }

    private func stopRecording() {
        guard let result = recordingController.stopRecording() else {
            audioErrorMessage = "Failed to stop recording."
            return
        }

        let finishedRecording = currentRecording
        if let recording = finishedRecording {
            recording.duration = result.duration
        }

        recordingStartTime = nil
        currentRecording = nil
        note.touch()

        if let recording = finishedRecording {
            selectedRecording = recording
            workspaceTab = .learn
            prepareMeetingArtifact(for: recording)
            startMeetingProcessing(for: recording)
        }
    }

    private func prepareMeetingArtifact(for recording: Recording) {
        if recording.meetingArtifact == nil {
            let artifact = MeetingArtifact(recording: recording)
            modelContext.insert(artifact)
            recording.meetingArtifact = artifact
            try? modelContext.save()
        }
    }

    /// Ensures finished recordings get an artifact and processing is kicked off when needed.
    private func ensureMeetingProcessing(for recording: Recording) {
        guard recording.duration > 0 else { return }
        guard !isRecording || currentRecording?.id != recording.id else { return }

        let artifact = recording.meetingArtifact
        let needsProcessing: Bool
        if artifact == nil {
            needsProcessing = true
        } else if let artifact {
            switch artifact.processingStatus {
            case .ready, .transcribing, .summarizing:
                needsProcessing = false
            case .pending, .failed:
                needsProcessing = true
            }
        } else {
            needsProcessing = true
        }

        guard needsProcessing else { return }
        prepareMeetingArtifact(for: recording)
        startMeetingProcessing(for: recording)
    }

    private func startMeetingProcessing(for recording: Recording) {
        if !NIMConfiguration.hasAPIKey {
            prepareMeetingArtifact(for: recording)
            if let artifact = recording.meetingArtifact {
                artifact.processingStatus = .failed
                artifact.errorMessage = "Add your NVIDIA API key in Settings (sidebar or toolbar) to process meetings."
                try? modelContext.save()
            }
            return
        }
        Task {
            await MeetingPipeline.shared.process(
                recording: recording,
                noteTitle: note.title,
                modelContext: modelContext
            )
        }
    }

    private func retryMeetingProcessing(for recording: Recording) {
        startMeetingProcessing(for: recording)
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard let recording = selectedRecording ?? sortedRecordings.first else { return }

        let fileStore = RecordingFileStore.shared
        guard let recordingURL = fileStore.getRecordingURL(for: recording.fileRelativePath) else {
            audioErrorMessage = "Recording file not found."
            return
        }

        selectedRecording = recording
        rebuildSyncMarks()
        playbackController.load(url: recordingURL)
        playbackController.play()
    }

    private func stopPlayback() {
        playbackController.stop()
        highlightedStrokeIndices = []
        syncEngine.clearMarks()
    }

    private func seek(to time: TimeInterval) {
        currentPlaybackTime = time
        playbackController.seek(to: time)
        updateSyncHighlight(at: time)
    }

    private func rebuildSyncMarks() {
        guard let recording = activeRecording else { return }
        let marks = recording.marks.filter { mark in
            guard let page = mark.page else { return false }
            return page.persistentModelID == currentPage?.persistentModelID
        }
        syncEngine.updateMarks(syncMarks(from: marks))
    }

    private func updateSyncHighlight(at time: TimeInterval) {
        syncEngine.tick(currentTime: time)
        highlightedStrokeIndices = syncEngine.highlightedStrokeIndices
    }

    private func cleanup() {
        if isRecording {
            stopRecording()
        }
        if isPlaying {
            stopPlayback()
        }
        saveCurrentPageDrawing()
    }

    private func importPDF() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
        }

        guard let relativePath = RecordingFileStore.shared.importPDF(from: url) else {
            audioErrorMessage = "Failed to import PDF."
            return
        }

        note.sourcePDFRelativePath = relativePath
        note.touch()

        guard let pdfURL = RecordingFileStore.shared.getPDFURL(for: relativePath),
              let document = PDFDocument(url: pdfURL) else { return }

        note.pages.removeAll { $0.pdfPageIndex != nil }

        for index in 0..<document.pageCount {
            let page = Page(pageNumber: note.pages.count, pdfPageIndex: index)
            modelContext.insert(page)
            page.note = note
            note.pages.append(page)
        }

        pdfDocumentURL = pdfURL
        loadPDFIfNeeded()
    }
}

struct EmptyCanvasState: View {
    let onAddPage: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            MonochromeLabel(title: "No Pages")
            Text("Add a page to start writing")
                .font(MonochromeTypography.lg())
                .foregroundColor(MonochromeColors.mutedForeground)

            MonochromeButton(title: "Add Blank Page", variant: .primary, icon: "plus") {
                onAddPage()
            }
        }
    }
}

#Preview {
    NoteEditorView(note: Note(title: "Preview Note"))
        .modelContainer(for: [Note.self], inMemory: true)
}

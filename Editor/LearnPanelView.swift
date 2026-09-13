//
//  LearnPanelView.swift
//  NotabilityClone
//
//  Full-width Learn workspace: Smart Notes + Transcript + Chat.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

enum LearnMode: String, CaseIterable, Identifiable {
    case smartNotes = "Smart Notes"
    case transcript = "Transcript"
    case chat = "Chat"

    var id: String { rawValue }
}

/// Full-width Learn workspace — not a cramped sidebar.
struct LearnWorkspaceView: View {
    let noteTitle: String
    @Bindable var note: Note
    @Binding var selectedRecording: Recording?
    var isRecordingActive: Bool
    var currentRecordingID: UUID?
    var onSeek: (TimeInterval) -> Void
    var onProcess: (Recording) -> Void
    var onRetry: (Recording) -> Void

    @State private var learnMode: LearnMode = .smartNotes

    private var sortedRecordings: [Recording] {
        note.recordings.sorted { $0.startedAt > $1.startedAt }
    }

    private var activeRecording: Recording? {
        if let selectedRecording { return selectedRecording }
        if isRecordingActive, let id = currentRecordingID {
            return note.recordings.first { $0.id == id }
        }
        return sortedRecordings.first
    }

    var body: some View {
        HStack(spacing: 0) {
            RecordingsSidebarView(
                selectedRecording: $selectedRecording,
                recordings: sortedRecordings,
                onSelect: { recording in
                    triggerProcessingIfNeeded(for: recording)
                }
            )
            .frame(width: 240)

            MonochromeVerticalDivider(weight: MonochromeBorders.thick)

            VStack(spacing: 0) {
                learnControlBar
                MonochromeDivider(weight: MonochromeBorders.hairline)

                HStack(alignment: .top, spacing: 0) {
                    mainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if learnMode == .chat, let recording = activeRecording, let artifact = recording.meetingArtifact {
                        MonochromeVerticalDivider(weight: MonochromeBorders.thick)
                        chatColumn(artifact: artifact)
                            .frame(width: 360)
                            .frame(maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MonochromeColors.background)
        .onAppear { bootstrapSelection() }
        .onChange(of: note.recordings.count) { _, _ in bootstrapSelection() }
    }

    // MARK: - Control bar

    private var learnControlBar: some View {
        HStack(spacing: 16) {
            if let recording = activeRecording {
                statusPill(for: recording)
                Text(recording.name)
                    .font(MonochromeTypography.sm())
                    .fontWeight(.medium)
                    .lineLimit(1)
            }

            Spacer()

            if let recording = activeRecording, needsProcessButton(recording) {
                MonochromeButton(
                    title: NIMConfiguration.hasAPIKey ? "Process" : "Set API Key",
                    variant: .primary
                ) {
                    if NIMConfiguration.hasAPIKey {
                        onProcess(recording)
                    } else {
                        NotificationCenter.default.post(name: .showAPIKeySettings, object: nil)
                    }
                }
            }

            Picker("View", selection: $learnMode) {
                ForEach(LearnMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            MonochromeButton(title: "Copy All", variant: .ghost) { copyAll() }
                .disabled(activeRecording?.meetingArtifact?.processingStatus != .ready)

            MonochromeButton(title: "Export PDF", variant: .outline) { exportPDF() }
                .disabled(activeRecording?.meetingArtifact?.processingStatus != .ready)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        if let recording = activeRecording {
            if let artifact = recording.meetingArtifact {
                switch artifact.processingStatus {
                case .ready:
                    readyContent(artifact: artifact)
                case .pending, .transcribing, .summarizing:
                    processingView(for: artifact)
                case .failed:
                    failedView(recording: recording, artifact: artifact)
                }
            } else {
                unprocessedView(recording: recording)
            }
        } else if isRecordingActive {
            emptyState(title: "Recording in progress", detail: "Smart Notes will appear when you stop.")
        } else {
            emptyState(title: "No recordings yet", detail: "Use the record button above to capture a meeting.")
        }
    }

    @ViewBuilder
    private func readyContent(artifact: MeetingArtifact) -> some View {
        switch learnMode {
        case .smartNotes:
            SmartNotesContentView(artifact: artifact, onSeek: onSeek)
        case .transcript:
            TranscriptContentView(artifact: artifact, onSeek: onSeek)
        case .chat:
            if artifact.fullTranscript.isEmpty && artifact.summary.isEmpty {
                emptyState(title: "Nothing to chat about yet", detail: "Process the recording first.")
            } else {
                SmartNotesContentView(artifact: artifact, onSeek: onSeek)
            }
        }
    }

    private func chatColumn(artifact: MeetingArtifact) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chat")
                    .font(MonochromeTypography.base())
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(16)
            MonochromeDivider(weight: MonochromeBorders.hairline)
            TranscriptChatView(artifact: artifact, onSeek: onSeek)
        }
        .background(MonochromeColors.muted.opacity(0.3))
    }

    private func processingView(for artifact: MeetingArtifact) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().controlSize(.large)
            Text(artifact.processingStatus == .summarizing ? "Summarizing your meeting…" : "Transcribing audio…")
                .font(MonochromeTypography.lg())
                .fontWeight(.medium)
            Text("Usually 1–2 minutes for a short recording.")
                .font(MonochromeTypography.sm())
                .foregroundColor(MonochromeColors.mutedForeground)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedView(recording: Recording, artifact: MeetingArtifact) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Processing failed")
                .font(MonochromeTypography.xl2())
                .fontWeight(.semibold)
            Text(artifact.errorMessage ?? "Unknown error")
                .font(MonochromeTypography.sm())
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .textSelection(.enabled)
            if NIMConfiguration.hasAPIKey {
                MonochromeButton(title: "Retry", variant: .primary) { onRetry(recording) }
            } else {
                Button("Open API Key Settings…") {
                    NotificationCenter.default.post(name: .showAPIKeySettings, object: nil)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private func unprocessedView(recording: Recording) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Ready to process")
                .font(MonochromeTypography.xl2())
                .fontWeight(.semibold)
            Text(NIMConfiguration.hasAPIKey
                 ? "Tap Process to generate Smart Notes and transcript."
                 : "Add your NVIDIA API key in Settings first.")
                .font(MonochromeTypography.sm())
                .foregroundColor(MonochromeColors.mutedForeground)
                .multilineTextAlignment(.center)
            if NIMConfiguration.hasAPIKey {
                MonochromeButton(title: "Process Recording", variant: .primary) { onProcess(recording) }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { triggerProcessingIfNeeded(for: recording) }
    }

    private func emptyState(title: String, detail: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text(title).font(MonochromeTypography.lg()).fontWeight(.semibold)
            Text(detail)
                .font(MonochromeTypography.sm())
                .foregroundColor(MonochromeColors.mutedForeground)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func needsProcessButton(_ recording: Recording) -> Bool {
        guard recording.duration > 0 else { return false }
        guard let artifact = recording.meetingArtifact else { return true }
        return artifact.processingStatus == .failed
    }

    private func bootstrapSelection() {
        if selectedRecording == nil { selectedRecording = sortedRecordings.first }
        if let recording = activeRecording { triggerProcessingIfNeeded(for: recording) }
    }

    private func triggerProcessingIfNeeded(for recording: Recording) {
        guard recording.duration > 0, !isRecordingActive || currentRecordingID != recording.id else { return }
        guard recording.meetingArtifact == nil ||
              recording.meetingArtifact?.processingStatus == .pending ||
              recording.meetingArtifact?.processingStatus == .failed else { return }
        onProcess(recording)
    }

    @ViewBuilder
    private func statusPill(for recording: Recording) -> some View {
        if let artifact = recording.meetingArtifact {
            let label: String = switch artifact.processingStatus {
            case .ready: "Ready"
            case .failed: "Failed"
            default: "Processing"
            }
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(artifact.processingStatus == .failed ? Color.red.opacity(0.12) : MonochromeColors.muted)
                .foregroundColor(artifact.processingStatus == .failed ? .red : MonochromeColors.foreground)
        }
    }

    private func copyAll() {
        guard let artifact = activeRecording?.meetingArtifact else { return }
        var text = artifact.summary
        if !artifact.highlights.isEmpty {
            text += "\n\nKey Moments\n"
            text += artifact.highlights.map { "[\(formatDuration($0.startTime))] \($0.title): \($0.detail)" }.joined(separator: "\n")
        }
        if !artifact.fullTranscript.isEmpty { text += "\n\nTranscript\n\(artifact.fullTranscript)" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func exportPDF() {
        guard let recording = activeRecording,
              let artifact = recording.meetingArtifact,
              artifact.processingStatus == .ready else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(recording.name)-meeting-report.pdf"
        if panel.runModal() == .OK, let url = panel.url {
            if let source = artifact.pdfRelativePath.flatMap({ RecordingFileStore.shared.getMeetingExportURL(for: $0) }) {
                try? FileManager.default.copyItem(at: source, to: url)
            } else if let generated = try? MeetingPDFExporter.export(noteTitle: noteTitle, recording: recording, artifact: artifact) {
                try? FileManager.default.copyItem(at: generated, to: url)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Smart Notes

private struct SmartNotesContentView: View {
    @Bindable var artifact: MeetingArtifact
    var onSeek: (TimeInterval) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if !artifact.summary.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        MonochromeLabel(title: "Summary")
                        if let rendered = try? AttributedString(markdown: artifact.summary) {
                            Text(rendered)
                                .font(MonochromeTypography.base())
                                .lineSpacing(4)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text(artifact.summary)
                                .font(MonochromeTypography.base())
                                .lineSpacing(4)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                if !artifact.highlights.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        MonochromeLabel(title: "Key Moments")
                        ForEach(artifact.highlights) { highlight in
                            Button(action: { onSeek(highlight.startTime) }) {
                                HStack(alignment: .top, spacing: 16) {
                                    Text(formatTime(highlight.startTime))
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(MonochromeColors.mutedForeground)
                                        .frame(width: 48, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(highlight.title)
                                            .font(MonochromeTypography.base())
                                            .fontWeight(.semibold)
                                        Text(highlight.detail)
                                            .font(MonochromeTypography.sm())
                                            .foregroundColor(MonochromeColors.mutedForeground)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            MonochromeDivider(weight: MonochromeBorders.hairline)
                        }
                    }
                }

                if artifact.summary.isEmpty && artifact.highlights.isEmpty {
                    Text("No Smart Notes yet.")
                        .font(MonochromeTypography.base())
                        .foregroundColor(MonochromeColors.mutedForeground)
                }
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60)
    }
}

// MARK: - Transcript

private struct TranscriptContentView: View {
    @Bindable var artifact: MeetingArtifact
    var onSeek: (TimeInterval) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                let segments = artifact.segments.sorted { $0.startTime < $1.startTime }
                if segments.isEmpty {
                    Text(artifact.fullTranscript.isEmpty ? "No transcript yet." : artifact.fullTranscript)
                        .font(MonochromeTypography.base())
                        .lineSpacing(4)
                        .textSelection(.enabled)
                        .padding(32)
                        .frame(maxWidth: 720, alignment: .leading)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(segments, id: \.persistentModelID) { segment in
                        Button(action: { onSeek(segment.startTime) }) {
                            HStack(alignment: .top, spacing: 16) {
                                Text(formatTime(segment.startTime))
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(MonochromeColors.mutedForeground)
                                    .frame(width: 48, alignment: .leading)
                                Text(segment.text)
                                    .font(MonochromeTypography.base())
                                    .lineSpacing(4)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 32)
                        }
                        .buttonStyle(.plain)
                        MonochromeDivider(weight: MonochromeBorders.hairline)
                    }
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(time) / 60, Int(time) % 60)
    }
}

// Legacy alias for any remaining references
typealias LearnPanelView = LearnWorkspaceView

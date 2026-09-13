//
//  RecordingsSidebarView.swift
//  NotabilityClone
//

import SwiftUI
import SwiftData

struct RecordingsSidebarView: View {
    @Binding var selectedRecording: Recording?
    let recordings: [Recording]
    var onSelect: (Recording) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonochromeLabel(title: "Recordings")
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            MonochromeDivider(weight: MonochromeBorders.thick)

            if recordings.isEmpty {
                Text("No recordings yet.\nUse the record button above.")
                    .font(MonochromeTypography.sm())
                    .foregroundColor(MonochromeColors.mutedForeground)
                    .multilineTextAlignment(.leading)
                    .padding(16)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(recordings, id: \.id) { recording in
                            recordingRow(recording)
                            MonochromeDivider(weight: MonochromeBorders.hairline)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(MonochromeColors.muted.opacity(0.25))
    }

    private func recordingRow(_ recording: Recording) -> some View {
        let isSelected = selectedRecording?.id == recording.id

        return Button(action: {
            selectedRecording = recording
            onSelect(recording)
        }) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSelected ? "waveform.circle.fill" : "waveform.circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? MonochromeColors.foreground : MonochromeColors.mutedForeground)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.name)
                        .font(MonochromeTypography.sm())
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(MonochromeColors.foreground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Text(formatDuration(recording.duration))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(MonochromeColors.mutedForeground)

                        if let status = statusLabel(for: recording) {
                            Text(status)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(statusBackground(for: recording))
                                .foregroundColor(statusForeground(for: recording))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? MonochromeColors.background : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func statusLabel(for recording: Recording) -> String? {
        guard let artifact = recording.meetingArtifact else { return nil }
        switch artifact.processingStatus {
        case .ready: return "Ready"
        case .failed: return "Failed"
        case .transcribing, .summarizing, .pending: return "Processing"
        }
    }

    private func statusBackground(for recording: Recording) -> Color {
        guard let artifact = recording.meetingArtifact else { return MonochromeColors.muted }
        switch artifact.processingStatus {
        case .failed: return Color.red.opacity(0.12)
        case .ready: return MonochromeColors.muted
        default: return MonochromeColors.muted
        }
    }

    private func statusForeground(for recording: Recording) -> Color {
        recording.meetingArtifact?.processingStatus == .failed ? .red : MonochromeColors.foreground
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        guard duration > 0 else { return "0:00" }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

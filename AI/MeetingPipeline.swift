//
//  MeetingPipeline.swift
//  NotabilityClone
//

import Foundation
import SwiftData

@MainActor
final class MeetingPipeline {
    static let shared = MeetingPipeline()

    private var processingRecordingIDs: Set<UUID> = []

    private init() {}

    func process(recording: Recording, noteTitle: String, modelContext: ModelContext) async {
        if processingRecordingIDs.contains(recording.id) { return }
        processingRecordingIDs.insert(recording.id)
        defer { processingRecordingIDs.remove(recording.id) }

        let artifact: MeetingArtifact
        if let existing = recording.meetingArtifact {
            artifact = existing
            artifact.processingStatus = .pending
            artifact.errorMessage = nil
            artifact.segments.removeAll()
        } else {
            artifact = MeetingArtifact(recording: recording)
            modelContext.insert(artifact)
            recording.meetingArtifact = artifact
        }
        try? modelContext.save()

        guard NIMConfiguration.hasAPIKey else {
            artifact.processingStatus = .failed
            artifact.errorMessage = "NVIDIA API key not configured."
            try? modelContext.save()
            return
        }

        do {
            guard let audioURL = RecordingFileStore.shared.getRecordingURL(for: recording.fileRelativePath) else {
                throw MeetingPipelineError.recordingNotFound
            }

            artifact.processingStatus = .transcribing
            try? modelContext.save()

            let transcriptionResponse = try await NIMClient.shared.transcribeAudio(
                sourceURL: audioURL,
                duration: recording.duration
            )
            let parsed = TranscriptionParser.parse(transcriptionResponse, duration: recording.duration)
            artifact.fullTranscript = parsed.fullTranscript

            artifact.segments.removeAll()
            for seg in parsed.segments {
                let segment = TranscriptSegment(startTime: seg.start, endTime: seg.end, text: seg.text)
                segment.artifact = artifact
                modelContext.insert(segment)
                artifact.segments.append(segment)
            }
            try? modelContext.save()

            artifact.processingStatus = .summarizing
            try? modelContext.save()

            // Summary/highlights are best-effort — keep transcript even if NVIDIA LLM fails
            do {
                artifact.summary = try await NIMClient.shared.summarize(transcript: artifact.fullTranscript)
            } catch {
                artifact.summary = ""
                artifact.errorMessage = "Summary unavailable: \(error.localizedDescription)"
            }

            do {
                let highlightsJSON = try await NIMClient.shared.extractHighlights(
                    transcript: artifact.fullTranscript,
                    duration: recording.duration
                )
                artifact.highlights = TranscriptionParser.parseHighlights(highlightsJSON)
            } catch {
                artifact.highlights = []
            }

            let pdfURL = try MeetingPDFExporter.export(
                noteTitle: noteTitle,
                recording: recording,
                artifact: artifact
            )
            artifact.pdfRelativePath = pdfURL.lastPathComponent
            artifact.processedAt = Date()
            artifact.processingStatus = .ready
            artifact.errorMessage = artifact.summary.isEmpty ? artifact.errorMessage : nil
            try? modelContext.save()
        } catch {
            artifact.processingStatus = .failed
            artifact.errorMessage = error.localizedDescription
            try? modelContext.save()
        }
    }

    enum MeetingPipelineError: Error, LocalizedError {
        case recordingNotFound

        var errorDescription: String? {
            switch self {
            case .recordingNotFound: return "Recording audio file not found."
            }
        }
    }
}
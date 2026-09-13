//
//  TranscriptionParser.swift
//  NotabilityClone
//

import Foundation

struct ParsedTranscription {
    let fullTranscript: String
    let segments: [(start: TimeInterval, end: TimeInterval, text: String)]
}

enum TranscriptionParser {
    private struct Payload: Decodable {
        struct Segment: Decodable {
            let start_seconds: Double?
            let end_seconds: Double?
            let text: String
        }
        let full_transcript: String?
        let segments: [Segment]?
    }

    static func parse(_ response: String, duration: TimeInterval) -> ParsedTranscription {
        if let jsonString = extractJSON(from: response),
           let data = jsonString.data(using: .utf8),
           let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            let segments = (payload.segments ?? []).compactMap { seg -> (TimeInterval, TimeInterval, String)? in
                guard !seg.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                let start = seg.start_seconds ?? 0
                let end = seg.end_seconds ?? max(start + 1, duration)
                return (start, end, seg.text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            let full = payload.full_transcript?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? segments.map(\.2).joined(separator: " ")
            if !full.isEmpty {
                return ParsedTranscription(fullTranscript: full, segments: segments.isEmpty ? [(0, duration, full)] : segments)
            }
        }

        let cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedTranscription(fullTranscript: cleaned, segments: [(0, duration, cleaned)])
    }

    static func parseHighlights(_ response: String) -> [MeetingHighlight] {
        guard let jsonString = extractJSON(from: response),
              let data = jsonString.data(using: .utf8) else { return [] }

        struct RawHighlight: Decodable {
            let title: String
            let detail: String
            let startTime: Double?
            let endTime: Double?
            let start_seconds: Double?
            let end_seconds: Double?
        }

        guard let raw = try? JSONDecoder().decode([RawHighlight].self, from: data) else { return [] }
        return raw.map { item in
            MeetingHighlight(
                title: item.title,
                detail: item.detail,
                startTime: item.startTime ?? item.start_seconds ?? 0,
                endTime: item.endTime ?? item.end_seconds
            )
        }
    }

    static func extractJSON(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("["),
           let start = trimmed.firstIndex(of: "["),
           let end = trimmed.lastIndex(of: "]") {
            return String(trimmed[start...end])
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            return String(text[start...end])
        }
        if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]") {
            return String(text[start...end])
        }
        return nil
    }
}

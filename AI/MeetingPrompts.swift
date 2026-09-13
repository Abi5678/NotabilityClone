//
//  MeetingPrompts.swift
//  NotabilityClone
//

import Foundation

enum MeetingPrompts {
    static let transcriptionPrompt = """
    Transcribe this meeting audio accurately. Return ONLY valid JSON with this exact shape:
    {
      "full_transcript": "complete transcript as one string",
      "segments": [
        {"start_seconds": 0.0, "end_seconds": 12.5, "text": "segment text"}
      ]
    }
    Use realistic timestamps in seconds. Split into logical sentence-level segments.
    """

    static func segmentPlainTranscript(text: String, duration: TimeInterval) -> String {
        """
        The meeting audio is \(Int(duration)) seconds long. Split the transcript below into timestamped segments.
        Return ONLY valid JSON:
        {"full_transcript": "complete text", "segments": [{"start_seconds": 0.0, "end_seconds": 10.0, "text": "..."}]}
        Distribute timestamps across the full \(Int(duration)) second duration.

        TRANSCRIPT:
        \(text)
        """
    }

    static let summarySystem = """
    You are a meeting assistant. Write clear, concise executive summaries of meeting transcripts.
    """

    static func summaryUser(transcript: String) -> String {
        """
        Summarize this meeting transcript in 3-5 short paragraphs covering: main topics, decisions, action items, and open questions.

        TRANSCRIPT:
        \(transcript)
        """
    }

    static let highlightsSystem = """
    You extract meeting highlights as JSON. Return ONLY a JSON array, no markdown fences.
    Each item: {"title": "short label", "detail": "1-2 sentences", "startTime": seconds, "endTime": seconds or null}
    Include action items, decisions, and key quotes. Provide 3-8 highlights.
    """

    static func highlightsUser(transcript: String, duration: TimeInterval) -> String {
        """
        Meeting duration: \(Int(duration)) seconds.

        TRANSCRIPT:
        \(transcript)
        """
    }

    static func chatSystem(transcript: String, summary: String, highlights: [MeetingHighlight]) -> String {
        let highlightsText = highlights.map { h in
            "- [\(formatTime(h.startTime))] \(h.title): \(h.detail)"
        }.joined(separator: "\n")

        return """
        You are a meeting assistant. Answer questions using ONLY the meeting transcript, summary, and highlights below.
        Cite timestamps as [MM:SS] when referencing specific moments.

        SUMMARY:
        \(summary)

        HIGHLIGHTS:
        \(highlightsText)

        FULL TRANSCRIPT:
        \(transcript)
        """
    }

    private static func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

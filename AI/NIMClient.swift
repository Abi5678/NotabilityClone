//
//  NIMClient.swift
//  NotabilityClone
//

import Foundation

struct NIMChatResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String?
            let content: String?
        }
        let message: Message?
    }
    let choices: [Choice]?
    struct ErrorBody: Codable {
        let message: String?
    }
    let error: ErrorBody?
}

enum NIMClientError: Error, LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "NVIDIA API key not configured. Open Settings to add your key."
        case .invalidResponse: return "Invalid response from NVIDIA API."
        case .apiError(let message): return Self.humanizeAPIError(message)
        }
    }

    private static func humanizeAPIError(_ message: String) -> String {
        if message.contains("EngineCore") {
            return "NVIDIA cloud service temporarily unavailable. On-device transcription will be used instead."
        }
        return message
    }
}

final class NIMClient {
    static let shared = NIMClient()
    private init() {}

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    func chatCompletion(model: String, messages: [[String: Any]], temperature: Double = 0.2, maxTokens: Int = 4096) async throws -> String {
        try await retrying(maxAttempts: 2) {
            try await self.chatCompletionOnce(model: model, messages: messages, temperature: temperature, maxTokens: maxTokens)
        }
    }

    private func chatCompletionOnce(model: String, messages: [[String: Any]], temperature: Double, maxTokens: Int) async throws -> String {
        guard let apiKey = NIMConfiguration.apiKey, !apiKey.isEmpty else {
            throw NIMClientError.missingAPIKey
        }

        var request = URLRequest(url: NIMConfiguration.baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NIMClientError.invalidResponse }

        if http.statusCode != 200 {
            throw NIMClientError.apiError(parseErrorMessage(from: data, statusCode: http.statusCode))
        }

        let decoded = try JSONDecoder().decode(NIMChatResponse.self, from: data)
        if let errorMessage = decoded.error?.message {
            throw NIMClientError.apiError(errorMessage)
        }
        guard let content = decoded.choices?.first?.message?.content,
              !content.isEmpty else {
            throw NIMClientError.apiError(parseErrorMessage(from: data, statusCode: http.statusCode))
        }
        return content
    }

    /// Transcribe using on-device Speech first, then NVIDIA cloud fallbacks.
    func transcribeAudio(sourceURL: URL, duration: TimeInterval) async throws -> String {
        var errors: [String] = []

        // 1. On-device Apple Speech (most reliable on macOS)
        do {
            let text = try await LocalSpeechTranscriber.transcribe(url: sourceURL)
            return await formatTranscript(text, duration: duration)
        } catch {
            errors.append("On-device: \(error.localizedDescription)")
        }

        // 2. NVIDIA Whisper (original m4a)
        do {
            let text = try await transcribeWithWhisper(fileURL: sourceURL)
            return await formatTranscript(text, duration: duration)
        } catch {
            errors.append("Whisper: \(error.localizedDescription)")
        }

        // 3. Convert to WAV and retry Whisper
        do {
            let wavURL = try await AudioConverter.convertToWAV(sourceURL: sourceURL)
            defer { try? FileManager.default.removeItem(at: wavURL) }
            let text = try await transcribeWithWhisper(fileURL: wavURL)
            return await formatTranscript(text, duration: duration)
        } catch {
            errors.append("Whisper (WAV): \(error.localizedDescription)")
        }

        // 4. Phi-4 multimodal last resort
        do {
            let wavURL = try await AudioConverter.convertToWAV(sourceURL: sourceURL)
            defer { try? FileManager.default.removeItem(at: wavURL) }
            return try await transcribeWithMultimodal(wavURL: wavURL)
        } catch {
            errors.append("Multimodal: \(error.localizedDescription)")
        }

        throw NIMClientError.apiError("All transcription methods failed.\n" + errors.joined(separator: "\n"))
    }

    private func formatTranscript(_ text: String, duration: TimeInterval) async -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        // Try LLM segmentation for timestamps; fall back to plain text
        do {
            return try await segmentTranscriptWithLLM(text: trimmed, duration: duration)
        } catch {
            return trimmed
        }
    }

    private func segmentTranscriptWithLLM(text: String, duration: TimeInterval) async throws -> String {
        let messages: [[String: Any]] = [
            ["role": "system", "content": "Return ONLY valid JSON. No markdown."],
            ["role": "user", "content": MeetingPrompts.segmentPlainTranscript(text: text, duration: duration)]
        ]
        return try await chatCompletion(model: NIMConfiguration.textModel, messages: messages, temperature: 0.1, maxTokens: 4096)
    }

    private func transcribeWithWhisper(fileURL: URL) async throws -> String {
        guard let apiKey = NIMConfiguration.apiKey, !apiKey.isEmpty else {
            throw NIMClientError.missingAPIKey
        }

        let audioData = try Data(contentsOf: fileURL)
        guard !audioData.isEmpty else { throw NIMClientError.apiError("Audio file is empty.") }

        let ext = fileURL.pathExtension.lowercased()
        let mimeType = ext == "m4a" ? "audio/mp4" : "audio/wav"
        let filename = ext == "m4a" ? "audio.m4a" : "audio.wav"

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("model", NIMConfiguration.whisperModel)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: NIMConfiguration.baseURL.appendingPathComponent("audio/transcriptions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NIMClientError.invalidResponse }
        if http.statusCode != 200 {
            throw NIMClientError.apiError(parseErrorMessage(from: data, statusCode: http.statusCode))
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }
        let plain = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !plain.isEmpty else { throw NIMClientError.invalidResponse }
        return plain
    }

    private func transcribeWithMultimodal(wavURL: URL) async throws -> String {
        let wavData = try Data(contentsOf: wavURL)
        guard !wavData.isEmpty else {
            throw NIMClientError.apiError("Converted WAV file is empty.")
        }

        let base64 = wavData.base64EncodedString()
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": [
                    ["type": "text", "text": MeetingPrompts.transcriptionPrompt],
                    ["type": "input_audio", "input_audio": ["data": base64, "format": "wav"]]
                ]
            ]
        ]

        return try await chatCompletion(
            model: NIMConfiguration.transcriptionModel,
            messages: messages,
            temperature: 0.1,
            maxTokens: 8192
        )
    }

    func summarize(transcript: String) async throws -> String {
        let messages: [[String: Any]] = [
            ["role": "system", "content": MeetingPrompts.summarySystem],
            ["role": "user", "content": MeetingPrompts.summaryUser(transcript: transcript)]
        ]
        return try await chatCompletion(model: NIMConfiguration.textModel, messages: messages, maxTokens: 2048)
    }

    func extractHighlights(transcript: String, duration: TimeInterval) async throws -> String {
        let messages: [[String: Any]] = [
            ["role": "system", "content": MeetingPrompts.highlightsSystem],
            ["role": "user", "content": MeetingPrompts.highlightsUser(transcript: transcript, duration: duration)]
        ]
        return try await chatCompletion(model: NIMConfiguration.textModel, messages: messages, maxTokens: 2048)
    }

    func chatAboutMeeting(transcript: String, summary: String, highlights: [MeetingHighlight], history: [MeetingChatMessage], question: String) async throws -> String {
        var messages: [[String: Any]] = [
            ["role": "system", "content": MeetingPrompts.chatSystem(transcript: transcript, summary: summary, highlights: highlights)]
        ]
        for msg in history.suffix(10) {
            messages.append(["role": msg.role, "content": msg.content])
        }
        messages.append(["role": "user", "content": question])
        return try await chatCompletion(model: NIMConfiguration.textModel, messages: messages, maxTokens: 2048)
    }

    private func retrying<T>(maxAttempts: Int, operation: () async throws -> T) async throws -> T {
        var lastError: Error?
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(2_000_000_000 * (attempt + 1)))
                }
            }
        }
        throw lastError ?? NIMClientError.invalidResponse
    }

    private func parseErrorMessage(from data: Data, statusCode: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let detail = json["detail"] as? String { return detail }
            if let detail = json["detail"] as? [[String: Any]],
               let first = detail.first,
               let msg = first["msg"] as? String { return msg }
            if let error = json["error"] as? [String: Any] {
                if let message = error["message"] as? String { return message }
            }
            if let message = json["message"] as? String { return message }
        }
        let snippet = String(data: data, encoding: .utf8) ?? ""
        if snippet.isEmpty { return "HTTP \(statusCode)" }
        return String(snippet.prefix(500))
    }
}

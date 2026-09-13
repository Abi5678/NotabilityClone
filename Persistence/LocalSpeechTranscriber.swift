//
//  LocalSpeechTranscriber.swift
//  NotabilityClone
//
//  On-device transcription via Apple Speech — avoids NVIDIA EngineCore ASR crashes.
//

import Foundation
import Speech

enum LocalSpeechTranscriber {
    enum TranscriptionError: Error, LocalizedError {
        case notAuthorized
        case notAvailable
        case emptyResult

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech recognition permission denied. Enable it in System Settings → Privacy → Speech Recognition."
            case .notAvailable:
                return "On-device speech recognition is not available."
            case .emptyResult:
                return "No speech detected in the recording."
            }
        }
    }

    static func transcribe(url: URL) async throws -> String {
        let status = await requestAuthorization()
        guard status == .authorized else { throw TranscriptionError.notAuthorized }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            throw TranscriptionError.notAvailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = false

            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                if finished { return }

                if let error {
                    finished = true
                    continuation.resume(throwing: error)
                    return
                }

                guard let result, result.isFinal else { return }

                finished = true
                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty {
                    continuation.resume(throwing: TranscriptionError.emptyResult)
                } else {
                    continuation.resume(returning: text)
                }
            }
        }
    }

    private static func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

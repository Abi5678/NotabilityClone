//
//  NIMConfiguration.swift
//  NotabilityClone
//

import Foundation

enum NIMConfiguration {
    static let baseURL = URL(string: "https://integrate.api.nvidia.com/v1")!
    /// Dedicated ASR — much more reliable than phi-4 multimodal for transcription.
    static let whisperModel = "openai/whisper-large-v3"
    static let transcriptionModel = "microsoft/phi-4-multimodal-instruct"
    static let textModel = "nvidia/nvidia-nemotron-nano-9b-v2"

    static var apiKey: String? {
        KeychainStore.loadAPIKey()
    }

    static var hasAPIKey: Bool {
        guard let key = apiKey else { return false }
        return !key.isEmpty
    }
}

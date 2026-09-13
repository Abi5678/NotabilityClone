//
//  MeetingHighlight.swift
//  NotabilityClone
//

import Foundation

struct MeetingHighlight: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var detail: String
    var startTime: TimeInterval
    var endTime: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case title, detail, startTime, endTime
    }
}

enum MeetingProcessingStatus: String {
    case pending
    case transcribing
    case summarizing
    case ready
    case failed
}

extension MeetingArtifact {
    var processingStatus: MeetingProcessingStatus {
        get { MeetingProcessingStatus(rawValue: status) ?? .pending }
        set { status = newValue.rawValue }
    }

    var highlights: [MeetingHighlight] {
        get {
            guard let data = highlightsJSON else { return [] }
            return (try? JSONDecoder().decode([MeetingHighlight].self, from: data)) ?? []
        }
        set {
            highlightsJSON = try? JSONEncoder().encode(newValue)
        }
    }
}

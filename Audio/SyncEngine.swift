//
//  SyncEngine.swift
//  NotabilityClone
//
//  Pure, unit-testable engine for time↔mark mapping
//

import Foundation

struct SyncMark: Identifiable, Hashable {
    let id: UUID
    let timeOffset: TimeInterval
    let strokeIndexStart: Int
    let strokeIndexEnd: Int

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SyncMark, rhs: SyncMark) -> Bool {
        lhs.id == rhs.id
    }
}

class SyncEngine: ObservableObject {
    @Published var activeMarkID: UUID?
    @Published var highlightedStrokeIndices: Set<Int> = []

    private var marks: [SyncMark] = []

    func updateMarks(_ marks: [SyncMark]) {
        self.marks = marks.sorted { $0.timeOffset < $1.timeOffset }
    }

    func tick(currentTime: TimeInterval) {
        updateActiveMark(for: currentTime)
    }

    private func updateActiveMark(for currentTime: TimeInterval) {
        guard !marks.isEmpty else {
            activeMarkID = nil
            highlightedStrokeIndices = []
            return
        }

        var left = 0
        var right = marks.count - 1
        var foundIndex: Int?

        while left <= right {
            let mid = (left + right) / 2
            let mark = marks[mid]

            if mark.timeOffset <= currentTime {
                foundIndex = mid
                left = mid + 1
            } else {
                right = mid - 1
            }
        }

        if let index = foundIndex {
            let mark = marks[index]
            activeMarkID = mark.id
            let start = min(mark.strokeIndexStart, mark.strokeIndexEnd)
            let end = max(mark.strokeIndexStart, mark.strokeIndexEnd)
            highlightedStrokeIndices = Set(start...end)
        } else {
            activeMarkID = nil
            highlightedStrokeIndices = []
        }
    }

    func timeOffset(forStrokeIndex strokeIndex: Int) -> TimeInterval? {
        for mark in marks {
            let start = min(mark.strokeIndexStart, mark.strokeIndexEnd)
            let end = max(mark.strokeIndexStart, mark.strokeIndexEnd)
            if strokeIndex >= start && strokeIndex <= end {
                return mark.timeOffset
            }
        }
        return nil
    }

    func clearMarks() {
        marks = []
        activeMarkID = nil
        highlightedStrokeIndices = []
    }
}

func syncMarks(from marks: [TimedMark]) -> [SyncMark] {
    marks.map { mark in
        SyncMark(
            id: mark.id,
            timeOffset: mark.timeOffset,
            strokeIndexStart: mark.strokeIndexStart,
            strokeIndexEnd: mark.strokeIndexEnd
        )
    }
}

extension SyncEngine {
    func _setMarksForTesting(_ marks: [SyncMark]) {
        self.marks = marks.sorted { $0.timeOffset < $1.timeOffset }
    }

    func _getMarksForTesting() -> [SyncMark] {
        marks
    }
}

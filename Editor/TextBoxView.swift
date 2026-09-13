//
//  TextBoxView.swift
//  NotabilityClone
//
//  Typed text blocks on a note page
//

import SwiftUI
import SwiftData

struct TextBoxOverlay: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var page: Page
    var recordingStartTime: Date?
    var highlightedTextRunID: PersistentIdentifier?
    var onCommit: (TextRun, TimeInterval?) -> Void

    @State private var editingRunID: PersistentIdentifier?
    @State private var draftText = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(page.textRuns, id: \.persistentModelID) { run in
                textRunView(run)
                    .position(x: run.xPosition, y: run.yPosition)
                    .allowsHitTesting(true)
            }

            Button(action: addTextBox) {
                Image(systemName: "text.badge.plus")
                    .font(.system(size: 14))
                    .padding(8)
                    .background(MonochromeColors.background.opacity(0.9))
                    .overlay(Rectangle().stroke(MonochromeColors.border, lineWidth: MonochromeBorders.hairline))
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(8)
            .allowsHitTesting(true)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func textRunView(_ run: TextRun) -> some View {
        let isHighlighted = highlightedTextRunID == run.persistentModelID
        let isEditing = editingRunID == run.persistentModelID

        Group {
            if isEditing {
                TextField("Type here", text: $draftText, onCommit: {
                    commitEdit(run)
                })
                .textFieldStyle(.plain)
                .font(.system(size: run.fontSize))
                .frame(minWidth: 120)
            } else {
                Text(run.text.isEmpty ? "Double-click to edit" : run.text)
                    .font(.system(size: run.fontSize))
                    .foregroundColor(run.text.isEmpty ? .secondary : .primary)
            }
        }
        .padding(6)
        .background(isHighlighted ? Color.yellow.opacity(0.35) : Color.clear)
        .overlay(
            Rectangle()
                .stroke(MonochromeColors.border, lineWidth: isEditing ? 1 : 0)
        )
        .onTapGesture(count: 2) {
            editingRunID = run.persistentModelID
            draftText = run.text
        }
    }

    private func addTextBox() {
        let run = TextRun(text: "", xPosition: 120, yPosition: 120)
        modelContext.insert(run)
        run.page = page
        page.textRuns.append(run)
    }

    private func commitEdit(_ run: TextRun) {
        run.text = draftText
        editingRunID = nil
        let offset: TimeInterval?
        if let start = recordingStartTime {
            offset = Date().timeIntervalSince(start)
        } else {
            offset = nil
        }
        run.recordingTimeOffset = offset
        onCommit(run, offset)
    }
}

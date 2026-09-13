//
//  TranscriptChatView.swift
//  NotabilityClone
//

import SwiftUI
import SwiftData

struct TranscriptChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var artifact: MeetingArtifact
    var onSeek: (TimeInterval) -> Void

    @State private var draft = ""
    @State private var isSending = false
    @State private var errorMessage: String?

    private var sortedMessages: [MeetingChatMessage] {
        artifact.chatMessages.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(sortedMessages, id: \.persistentModelID) { message in
                            ChatBubble(message: message, onSeek: onSeek)
                                .id(message.persistentModelID)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: sortedMessages.count) { _, _ in
                    if let last = sortedMessages.last {
                        proxy.scrollTo(last.persistentModelID, anchor: .bottom)
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(MonochromeTypography.xs())
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
            }

            HStack(spacing: 8) {
                TextField("Ask about this meeting…", text: $draft)
                    .textFieldStyle(.plain)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.plain)
                .disabled(isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
            .overlay(Rectangle().stroke(MonochromeColors.border, lineWidth: MonochromeBorders.hairline))
        }
    }

    private func sendMessage() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isSending else { return }

        let userMessage = MeetingChatMessage(role: "user", content: question)
        userMessage.artifact = artifact
        modelContext.insert(userMessage)
        artifact.chatMessages.append(userMessage)
        draft = ""
        isSending = true
        errorMessage = nil

        Task {
            do {
                let answer = try await NIMClient.shared.chatAboutMeeting(
                    transcript: artifact.fullTranscript,
                    summary: artifact.summary,
                    highlights: artifact.highlights,
                    history: sortedMessages,
                    question: question
                )
                let assistantMessage = MeetingChatMessage(role: "assistant", content: answer)
                assistantMessage.artifact = artifact
                await MainActor.run {
                    modelContext.insert(assistantMessage)
                    artifact.chatMessages.append(assistantMessage)
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSending = false
                }
            }
        }
    }
}

struct ChatBubble: View {
    let message: MeetingChatMessage
    var onSeek: (TimeInterval) -> Void

    var body: some View {
        HStack {
            if message.role == "assistant" { Spacer(minLength: 24) }

            VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(MonochromeTypography.sm())
                    .foregroundColor(message.role == "user" ? MonochromeColors.background : MonochromeColors.foreground)
                    .padding(10)
                    .background(message.role == "user" ? MonochromeColors.foreground : MonochromeColors.background)
                    .overlay(Rectangle().stroke(MonochromeColors.border, lineWidth: MonochromeBorders.hairline))
                    .textSelection(.enabled)
                    .onTapGesture {
                        if let time = TimestampParser.firstTimestamp(in: message.content) {
                            onSeek(time)
                        }
                    }
            }

            if message.role == "user" { Spacer(minLength: 24) }
        }
    }
}

enum TimestampParser {
    static func firstTimestamp(in text: String) -> TimeInterval? {
        let pattern = #"\[(\d{2}):(\d{2})\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 3,
              let minRange = Range(match.range(at: 1), in: text),
              let secRange = Range(match.range(at: 2), in: text),
              let minutes = Int(text[minRange]),
              let seconds = Int(text[secRange]) else { return nil }
        return TimeInterval(minutes * 60 + seconds)
    }
}

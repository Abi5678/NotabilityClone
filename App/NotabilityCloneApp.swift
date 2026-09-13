//
//  NotabilityCloneApp.swift
//  NotabilityClone
//

import SwiftUI
import SwiftData

@main
struct NotabilityCloneApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Subject.self,
            Notebook.self,
            Note.self,
            Page.self,
            Recording.self,
            TimedMark.self,
            TextRun.self,
            MeetingArtifact.self,
            TranscriptSegment.self,
            MeetingChatMessage.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("NVIDIA API Key…") {
                    NotificationCenter.default.post(name: .showAPIKeySettings, object: nil)
                }
            }
        }
    }
}

extension Notification.Name {
    static let showAPIKeySettings = Notification.Name("showAPIKeySettings")
    static let apiKeyDidChange = Notification.Name("apiKeyDidChange")
}

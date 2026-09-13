//
//  RecordingFileStore.swift
//  NotabilityClone
//
//  Manages .m4a files and imported PDFs in App Support directory
//

import Foundation

class RecordingFileStore {
    static let shared = RecordingFileStore()
    
    private let fileManager = FileManager.default
    private var recordingsDirectory: URL {
        getApplicationSupportDirectory().appendingPathComponent("Recordings", isDirectory: true)
    }
    
    private var meetingExportsDirectory: URL {
        getApplicationSupportDirectory().appendingPathComponent("MeetingExports", isDirectory: true)
    }

    private var pdfsDirectory: URL {
        getApplicationSupportDirectory().appendingPathComponent("PDFs", isDirectory: true)
    }
    
    private func getApplicationSupportDirectory() -> URL {
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = urls[0].appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.notabilityclone.app", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        
        return appSupport
    }
    
    init() {
        // Create directories
        try? fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: pdfsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: meetingExportsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Recordings
    
    func createRecordingFile() -> URL? {
        let filename = UUID().uuidString
        let url = recordingsDirectory.appendingPathComponent("\(filename).m4a")
        
        do {
            try fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
            return url
        } catch {
            print("Failed to create recording directory: \(error)")
            return nil
        }
    }
    
    func createRecordingURL(filename: String) -> URL {
        recordingsDirectory.appendingPathComponent("\(filename).m4a")
    }
    
    func getRecordingURL(for relativePath: String) -> URL? {
        let url: URL?
        if relativePath.hasSuffix(".m4a") {
            url = recordingsDirectory.appendingPathComponent(relativePath)
        } else if relativePath.hasSuffix(".pdf") {
            url = pdfsDirectory.appendingPathComponent(relativePath)
        } else {
            url = nil
        }
        guard let url, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }
    
    func deleteRecording(at relativePath: String) {
        guard let url = getRecordingURL(for: relativePath) else { return }
        try? fileManager.removeItem(at: url)
    }
    
    // MARK: - PDFs
    
    func importPDF(from sourceURL: URL) -> String? {
        let filename = UUID().uuidString + ".pdf"
        let destinationURL = pdfsDirectory.appendingPathComponent(filename)
        
        do {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return filename
        } catch {
            print("Failed to import PDF: \(error)")
            return nil
        }
    }
    
    func getPDFURL(for relativePath: String) -> URL? {
        return pdfsDirectory.appendingPathComponent(relativePath)
    }
    
    func deletePDF(at relativePath: String) {
        guard let url = getPDFURL(for: relativePath) else { return }
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Meeting Exports

    func meetingExportURL(for filename: String) -> URL {
        meetingExportsDirectory.appendingPathComponent("\(filename).pdf")
    }

    func getMeetingExportURL(for relativePath: String) -> URL? {
        meetingExportsDirectory.appendingPathComponent(relativePath)
    }
    
    // MARK: - Helpers
    
    private func getBaseURL(for relativePath: String) -> URL? {
        if relativePath.hasSuffix(".m4a") {
            return recordingsDirectory
        } else if relativePath.hasSuffix(".pdf") {
            return pdfsDirectory
        }
        return nil
    }
}
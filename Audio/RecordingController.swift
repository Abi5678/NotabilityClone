//
//  RecordingController.swift
//  NotabilityClone
//
//  AVAudioRecorder wrapper for audio recording
//

import Foundation
import AVFoundation

struct RecordingResult {
    let url: URL
    let duration: TimeInterval
}

class RecordingController: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var error: Error?

    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var lastRecordingURL: URL?

    func requestPermission(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }

    func startRecording(at url: URL) {
        guard !isRecording else { return }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()

            lastRecordingURL = url
            isRecording = true
            recordingStartTime = Date()
            startTimer()
        } catch {
            self.error = error
        }
    }

    func stopRecording() -> RecordingResult? {
        guard isRecording else { return nil }

        let url = audioRecorder?.url ?? lastRecordingURL
        let duration = recordingTime

        audioRecorder?.stop()
        audioRecorder = nil
        stopTimer()

        isRecording = false
        recordingTime = 0
        recordingStartTime = nil

        guard let url else { return nil }
        return RecordingResult(url: url, duration: duration)
    }

    func getRecordingStartTime() -> Date? {
        recordingStartTime
    }

    private func startTimer() {
        stopTimer()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let startTime = self.recordingStartTime else { return }
            self.recordingTime = Date().timeIntervalSince(startTime)
        }
    }

    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
}

extension RecordingController: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            DispatchQueue.main.async {
                self.error = NSError(domain: "RecordingController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Recording failed"])
            }
        }
    }

    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        DispatchQueue.main.async {
            self.error = error ?? NSError(domain: "RecordingController", code: -1, userInfo: [NSLocalizedDescriptionKey: "Encoding error"])
        }
    }
}

//
//  AudioConverter.swift
//  NotabilityClone
//

import AVFoundation
import Foundation

enum AudioConverter {
    /// Converts m4a/aac to 16 kHz mono WAV for NVIDIA NIM upload.
    static func convertToWAV(sourceURL: URL) async throws -> URL {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw ConversionError.fileNotFound(sourceURL.lastPathComponent)
        }

        let attrs = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = attrs[.size] as? Int64 ?? 0
        guard fileSize > 0 else {
            throw ConversionError.emptyFile
        }

        let asset = AVURLAsset(url: sourceURL)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else {
            throw ConversionError.noAudioTrack
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(readerOutput)
        guard reader.startReading() else {
            throw ConversionError.readFailed(reader.error?.localizedDescription)
        }

        var pcmData = Data()
        while reader.status == .reading {
            guard let sampleBuffer = readerOutput.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { break }
            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: nil,
                totalLengthOut: &length,
                dataPointerOut: &dataPointer
            )
            if let dataPointer {
                pcmData.append(UnsafeBufferPointer(start: dataPointer, count: length))
            }
        }

        if reader.status == .failed {
            throw ConversionError.readFailed(reader.error?.localizedDescription)
        }

        guard !pcmData.isEmpty else {
            throw ConversionError.readFailed("No audio samples decoded.")
        }

        let wavData = wrapPCMInWAV(pcmData: pcmData, sampleRate: 16000, channels: 1, bitsPerSample: 16)
        try wavData.write(to: outputURL)
        return outputURL
    }

    private static func wrapPCMInWAV(pcmData: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        var header = Data()
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = UInt32(pcmData.count)
        let chunkSize = 36 + dataSize

        header.append(contentsOf: "RIFF".utf8)
        header.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian) { Data($0) })
        header.append(contentsOf: "WAVE".utf8)
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(byteRate).littleEndian) { Data($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(blockAlign).littleEndian) { Data($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian) { Data($0) })
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        header.append(pcmData)
        return header
    }

    enum ConversionError: Error, LocalizedError {
        case fileNotFound(String)
        case emptyFile
        case noAudioTrack
        case readFailed(String?)

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let name):
                return "Recording file not found: \(name)."
            case .emptyFile:
                return "Recording file is empty."
            case .noAudioTrack:
                return "Recording has no audio track."
            case .readFailed(let detail):
                return detail.map { "Failed to convert audio: \($0)" } ?? "Failed to convert audio to WAV."
            }
        }
    }
}

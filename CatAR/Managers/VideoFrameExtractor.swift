// VideoFrameExtractor.swift
// Extracts evenly-spaced frames from a recorded video using AVAssetImageGenerator.

import AVFoundation
import UIKit
import Observation

@available(iOS 17.0, *)
@Observable
@MainActor
final class VideoFrameExtractor {

    var progress: Double = 0
    var frameCount: Int = 0
    var isExtracting: Bool = false
    var errorMessage: String?

    private(set) var outputFolder: URL

    init() {
        let tmp = FileManager.default.temporaryDirectory
        outputFolder = tmp.appendingPathComponent("catAR_capture", isDirectory: true)
    }

    /// Extract `targetFrameCount` frames from `videoURL` and save to the output folder.
    /// Returns the folder URL containing the JPEG frames.
    func extract(from videoURL: URL, targetFrameCount: Int = 60) async throws -> URL {
        isExtracting = true
        progress = 0
        frameCount = 0
        defer { isExtracting = false }

        // Prepare output folder
        let fm = FileManager.default
        if fm.fileExists(atPath: outputFolder.path) {
            try fm.removeItem(at: outputFolder)
        }
        try fm.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        let asset = AVURLAsset(url: videoURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        guard totalSeconds > 0 else {
            throw NSError(domain: "VideoFrameExtractor",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Video has zero duration"])
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter  = CMTime(seconds: 0.1, preferredTimescale: 600)
        generator.maximumSize = CGSize(width: 4032, height: 3024)

        // Build evenly-spaced time array
        let interval = totalSeconds / Double(targetFrameCount)
        var times: [NSValue] = []
        for i in 0..<targetFrameCount {
            let seconds = interval * Double(i) + interval * 0.5
            let cmTime = CMTime(seconds: seconds, preferredTimescale: 600)
            times.append(NSValue(time: cmTime))
        }

        var localCount = 0
        let totalExpected = times.count

        for (index, timeValue) in times.enumerated() {
            let requestedTime = timeValue.timeValue
            let (cgImage, _) = try await generator.image(at: requestedTime)

            let uiImage = UIImage(cgImage: cgImage)
            guard let jpegData = uiImage.jpegData(compressionQuality: 0.92) else { continue }

            let fileName = String(format: "frame_%04d.jpg", index)
            let fileURL = outputFolder.appendingPathComponent(fileName)
            try jpegData.write(to: fileURL)

            localCount += 1
            self.frameCount = localCount
            self.progress = Double(localCount) / Double(totalExpected)
        }

        return outputFolder
    }
}

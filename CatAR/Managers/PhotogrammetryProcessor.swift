// PhotogrammetryProcessor.swift
// Wraps Apple's PhotogrammetrySession for async processing.

import Foundation
import RealityKit
import Observation

@available(iOS 17.0, *)
@Observable
@MainActor
final class PhotogrammetryProcessor {

    // MARK: - Public state
    var progress: Double = 0
    var statusMessage: String = "Initialising…"
    var outputURL: URL?
    var isProcessing: Bool = false
    var isCancelled: Bool = false
    var errorMessage: String?

    // MARK: - Private
    private var session: PhotogrammetrySession?

    // MARK: - Process

    /// Start photogrammetry. `inputFolder` must contain JPEG/HEIF images.
    /// The resulting `.usdz` is saved to the app's Documents directory.
    func process(inputFolder: URL) async {
        isProcessing = true
        isCancelled = false
        errorMessage = nil
        progress = 0
        statusMessage = "Starting photogrammetry…"

        let outputFolder = Self.documentsURL
        let outputFile = outputFolder.appendingPathComponent("my_cat_\(Date().timeIntervalSince1970).usdz")

        var config = PhotogrammetrySession.Configuration()
        config.featureSensitivity = .high
        config.isObjectMaskingEnabled = true
        config.checkpointDirectory = Self.checkpointURL

        do {
            let newSession = try PhotogrammetrySession(input: inputFolder, configuration: config)
            self.session = newSession

            let request = PhotogrammetrySession.Request(modelFile: outputFile)
            try newSession.process(requests: [request])

            // The loop suspends on each iteration and runs on @MainActor, ensuring safe state access
            for try await output in newSession.outputs {
                guard !isCancelled else { break }
                handleOutput(output, expectedURL: outputFile)
            }

            if !isCancelled {
                self.outputURL = outputFile
                self.statusMessage = "Complete! 🎉"
                self.isProcessing = false
            }

        } catch {
            self.errorMessage = error.localizedDescription
            self.statusMessage = "Processing failed"
            self.isProcessing = false
        }
    }

    func cancel() {
        isCancelled = true
        session?.cancel()
        isProcessing = false
        statusMessage = "Cancelled"
    }

    // MARK: - Output handler

    private func handleOutput(_ output: PhotogrammetrySession.Output, expectedURL: URL) {
        switch output {

        case .processingComplete:
            break

        case .requestError(_, let error):
            self.errorMessage = "Request error: \(error.localizedDescription)"
            self.statusMessage = "Error"
            self.isProcessing = false

        case .requestComplete(_, _):
            self.statusMessage = "Model ready ✓"

        case .requestProgress(_, let fractionComplete):
            self.progress = fractionComplete
            let pct = Int(fractionComplete * 100)
            self.statusMessage = "Processing… \(pct)%"

        case .requestProgressInfo(_, let progressInfo):
            if let msg = progressInfo.processingStage?.display {
                self.statusMessage = msg
            }

        case .processingCancelled:
            self.statusMessage = "Cancelled"
            self.isProcessing = false

        case .inputComplete:
            self.statusMessage = "Input loaded, building model…"

        case .invalidSample(_, _):
            break

        case .skippedSample(_):
            break

        case .automaticDownsampling:
            self.statusMessage = "Downsampling images…"

        @unknown default:
            break
        }
    }

    // MARK: - Helpers

    static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var checkpointURL: URL {
        let url = documentsURL.appendingPathComponent("photogrammetry_checkpoints", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

// MARK: - Convenience display name for processing stages

extension PhotogrammetrySession.Output.ProcessingStage {
    var display: String? {
        switch self {
        case .preProcessing:      return "Pre-processing images…"
        case .imageAlignment:     return "Aligning images…"
        case .pointCloudGeneration: return "Generating point cloud…"
        case .meshGeneration:     return "Building mesh…"
        case .textureMapping:     return "Applying textures…"
        case .optimization:       return "Optimising model…"
        @unknown default:         return nil
        }
    }
}

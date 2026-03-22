// PhotoCaptureManager.swift
// Manages the AVCaptureSession for photo capture.

@preconcurrency import AVFoundation
import UIKit
import Observation

enum CaptureError: LocalizedError {
    case sessionSetupFailed
    case outputDirectoryError
    case captureDeviceNotFound

    var errorDescription: String? {
        switch self {
        case .sessionSetupFailed: return "Failed to set up camera session."
        case .outputDirectoryError: return "Could not create capture output folder."
        case .captureDeviceNotFound: return "No camera found on this device."
        }
    }
}

@available(iOS 17.0, *)
@Observable
@MainActor
final class PhotoCaptureManager: NSObject {

    // MARK: - Public state
    var photoCount: Int = 0
    var isSessionRunning: Bool = false
    var lastCapturedImage: UIImage?
    var errorMessage: String?

    // MARK: - Internal
    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private(set) var outputFolder: URL

    // Used to signal completion of a single async capture
    private var captureContinuation: CheckedContinuation<Void, Error>?

    // MARK: - Init
    override init() {
        let tmp = FileManager.default.temporaryDirectory
        outputFolder = tmp.appendingPathComponent("catAR_capture", isDirectory: true)
        super.init()
    }

    // MARK: - Session lifecycle

    func prepareSession() throws {
        try resetOutputFolder()

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .back)
        else { throw CaptureError.captureDeviceNotFound }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CaptureError.sessionSetupFailed }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else { throw CaptureError.sessionSetupFailed }
        session.addOutput(photoOutput)

        // Note: maxPhotoBitDepth is omitted for broader device compatibility
        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else { return }
        print("📸 [PhotoCaptureManager] Starting session...")
        
        // Observe runtime errors
        NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionRuntimeError,
            object: session,
            queue: .main
        ) { [weak self] notification in
            if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
                print("❌ [PhotoCaptureManager] Runtime error: \(error.localizedDescription)")
                self?.errorMessage = "Camera error: \(error.localizedDescription)"
            }
        }

        Task(priority: .userInitiated) {
            self.session.startRunning()
            print("✅ [PhotoCaptureManager] Session is running: \(self.session.isRunning)")
            self.isSessionRunning = true
        }
    }

    func stopSession() {
        print("📸 [PhotoCaptureManager] Stopping session...")
        guard session.isRunning else { return }
        session.stopRunning()
        isSessionRunning = false
    }

    // MARK: - Capture one photo (async)

    func capturePhoto() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Reset

    func resetOutputFolder() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: outputFolder.path) {
            try fm.removeItem(at: outputFolder)
        }
        try fm.createDirectory(at: outputFolder, withIntermediateDirectories: true)
        photoCount = 0
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension PhotoCaptureManager: AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                                 didFinishProcessingPhoto photo: AVCapturePhoto,
                                 error: Error?) {
        Task { @MainActor in
            if let error {
                captureContinuation?.resume(throwing: error)
                captureContinuation = nil
                return
            }

            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data) else {
                captureContinuation?.resume(throwing: CaptureError.sessionSetupFailed)
                captureContinuation = nil
                return
            }

            let fileName = String(format: "frame_%04d.jpg", photoCount)
            let fileURL = outputFolder.appendingPathComponent(fileName)

            do {
                if let jpegData = image.jpegData(compressionQuality: 0.92) {
                    try jpegData.write(to: fileURL)
                    self.photoCount += 1
                    self.lastCapturedImage = image
                }
                captureContinuation?.resume()
            } catch {
                captureContinuation?.resume(throwing: error)
            }
            captureContinuation = nil
        }
    }
}

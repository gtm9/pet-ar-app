// CaptureView.swift
// Camera capture screen supporting Photo mode and Video mode.

import SwiftUI
import AVFoundation
import UIKit

struct CaptureView: View {

    let mode: CaptureMode

    @State private var manager = PhotoCaptureManager()
    @State private var extractor = VideoFrameExtractor()

    // Video recording state
    @State private var videoOutput: AVCaptureMovieFileOutput?
    @State private var tempVideoURL: URL?
    @State private var isRecording = false
    @State private var activeDelegate: VideoRecordingDelegate?
    @State private var isProcessingFrames = false

    // Navigation
    @State private var navigateToProcessing = false
    @State private var captureFolder: URL?

    // UI
    @State private var showError = false
    @State private var autoBurst = false
    @State private var coverage: Double = 0

    @Environment(\.dismiss) private var dismiss

    // Minimum photos before allowing Process
    private let minPhotos = 30

    var body: some View {
        ZStack {
            // Live camera preview
            CameraPreviewView(session: manager.session)
                .ignoresSafeArea()

            // Dark vignette
            RadialGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.55)]),
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                // MARK: Top bar
                topBar

                Spacer()

                // MARK: Coverage ring + instruction
                progressRing

                Spacer()

                // MARK: Bottom controls
                bottomControls
            }
        }
        .navigationBarHidden(true)
        .onAppear { startCamera() }
        .onDisappear { manager.stopSession() }
        .alert("Camera Error", isPresented: $showError, presenting: manager.errorMessage) { _ in
            Button("Go Back") { dismiss() }
        } message: { msg in Text(msg) }
        // Auto-burst timer
        .onChange(of: autoBurst) { _, on in
            if on { startAutoBurst() }
        }
        .navigationDestination(isPresented: $navigateToProcessing) {
            if let folder = captureFolder {
                ProcessingView(inputFolder: folder)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            Text(mode == .photos ? "📸 Photo Mode" : "🎥 Video Mode")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            // Auto-burst toggle (photos only)
            if mode == .photos {
                Toggle("", isOn: $autoBurst)
                    .toggleStyle(BurstToggleStyle())
            } else {
                Spacer().frame(width: 28)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)
    }

    // MARK: - Coverage Ring

    private var progressRing: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.15), lineWidth: 8)
                    .frame(width: 130, height: 130)
                Circle()
                    .trim(from: 0, to: coverage)
                    .stroke(
                        LinearGradient(colors: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 130, height: 130)
                    .animation(.easeOut(duration: 0.3), value: coverage)

                VStack(spacing: 2) {
                    if mode == .photos {
                        Text("\(manager.photoCount)")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("photos")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    } else if isRecording {
                        Text("Recording")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                    } else if tempVideoURL != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "record.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                }
            }

            Text(instructionText)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.vertical, 10)
                .background(.black.opacity(0.5))
                .clipShape(Capsule())
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            if mode == .photos {
                // Photo capture button
                Button(action: captureOnePhoto) {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 80, height: 80)
                        Circle()
                            .stroke(LinearGradient(colors: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")],
                                                   startPoint: .leading, endPoint: .trailing),
                                    lineWidth: 4)
                            .frame(width: 94, height: 94)
                    }
                }
                .disabled(manager.photoCount >= 100 || autoBurst)
            } else {
                // Record button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(isRecording ? Color.red : Color.white)
                            .frame(width: 80, height: 80)
                            .animation(.easeInOut(duration: 0.2), value: isRecording)
                        if isRecording {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.white)
                                .frame(width: 28, height: 28)
                        }
                        Circle()
                            .stroke(.white.opacity(0.4), lineWidth: 4)
                            .frame(width: 94, height: 94)
                    }
                }
            }

            Button(action: beginProcessing) {
                HStack(spacing: 8) {
                    Image(systemName: isProcessingFrames ? "hourglass" : "cpu")
                    if isProcessingFrames {
                        Text("Extracting Frames...")
                    } else if mode == .photos {
                        Text(canProcess ? "Process \(frameLabel) →" : "Need \(minPhotos - manager.photoCount) more photos")
                    } else {
                        Text(canProcess ? "Process Video →" : (isRecording ? "Recording..." : "Capture Video first"))
                    }
                }
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    (canProcess && !isProcessingFrames)
                    ? LinearGradient(colors: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")],
                                     startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.12)],
                                     startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(.white.opacity((canProcess && !isProcessingFrames) ? 1.0 : 0.4))
                .clipShape(Capsule())
            }
            .disabled(!canProcess || isProcessingFrames)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Computed

    private var canProcess: Bool {
        if mode == .photos { return manager.photoCount >= minPhotos }
        return tempVideoURL != nil && !isRecording
    }

    private var frameLabel: String {
        mode == .photos ? "\(manager.photoCount) photos" : "video"
    }

    private var instructionText: String {
        switch mode {
        case .photos:
            if manager.photoCount < minPhotos {
                return "Walk slowly around your cat and tap to capture"
            } else if manager.photoCount < 60 {
                return "Great! Keep going for higher quality"
            } else {
                return "Excellent coverage! Tap Process when ready"
            }
        case .video:
            return isRecording
                ? "Walk slowly 360° around your cat"
                : (tempVideoURL == nil ? "Tap the button to start recording" : "Video captured! Tap Process")
        }
    }

    // MARK: - Actions

    private func startCamera() {
        Task {
            do {
                try manager.prepareSession()
                if mode == .video { configureVideoOutput() }
                manager.startSession()
            } catch {
                await MainActor.run {
                    manager.errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func captureOnePhoto() {
        Task {
            do {
                try await manager.capturePhoto()
                withAnimation { coverage = min(1.0, Double(manager.photoCount) / 80.0) }
            } catch {
                manager.errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func startAutoBurst() {
        Task {
            while autoBurst && manager.photoCount < 100 {
                do {
                    try await manager.capturePhoto()
                    withAnimation { coverage = min(1.0, Double(manager.photoCount) / 80.0) }
                    try await Task.sleep(for: .milliseconds(800))
                } catch {
                    autoBurst = false
                    break
                }
            }
            autoBurst = false
        }
    }

    // MARK: - Video recording

    private func configureVideoOutput() {
        let output = AVCaptureMovieFileOutput()
        guard manager.session.canAddOutput(output) else { return }
        manager.session.beginConfiguration()
        manager.session.addOutput(output)
        if let connection = output.connection(with: .video) {
            connection.preferredVideoStabilizationMode = .auto
        }
        manager.session.commitConfiguration()
        videoOutput = output
    }

    private func toggleRecording() {
        guard let output = videoOutput else { return }
        if isRecording {
            output.stopRecording()
            isRecording = false
            withAnimation { self.coverage = 1.0 }
        } else {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("cat_capture_\(Int(Date().timeIntervalSince1970)).mov")
            
            self.coverage = 0
            isRecording = true
            tempVideoURL = nil

            let delegate = VideoRecordingDelegate { savedURL in
                Task { @MainActor in
                    self.tempVideoURL = savedURL
                    withAnimation { self.coverage = 1.0 }
                    self.activeDelegate = nil // Release once done
                }
            }
            self.activeDelegate = delegate
            output.startRecording(to: url, recordingDelegate: delegate)
            
            // Animate coverage over 20 seconds (typical minimum for a good scan)
            withAnimation(.linear(duration: 20)) {
                self.coverage = 1.0
            }
        }
    }

    private func beginProcessing() {
        Task {
            if mode == .photos {
                captureFolder = manager.outputFolder
                manager.stopSession()
                navigateToProcessing = true
            } else if let videoURL = tempVideoURL {
                isProcessingFrames = true
                manager.stopSession()
                // Extract frames first
                do {
                    let folder = try await extractor.extract(from: videoURL, targetFrameCount: 60)
                    captureFolder = folder
                    isProcessingFrames = false
                    navigateToProcessing = true
                } catch {
                    isProcessingFrames = false
                    manager.errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        // Session is already set, but we could update properties here if needed
    }

    class PreviewUIView: UIView {
        var session: AVCaptureSession? {
            get { videoLayer.session }
            set { videoLayer.session = newValue }
        }

        override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }

        var videoLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            setupLayer()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupLayer()
        }

        private func setupLayer() {
            videoLayer.videoGravity = .resizeAspectFill
            backgroundColor = .black
        }
    }
}

// MARK: - Video Recording Delegate

final class VideoRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    let completion: @Sendable (URL) -> Void
    init(completion: @Sendable @escaping (URL) -> Void) { self.completion = completion }

    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if let error {
            print("❌ [VideoRecordingDelegate] Recording failed: \(error.localizedDescription)")
            return
        }
        print("✅ [VideoRecordingDelegate] Saved to: \(outputFileURL.lastPathComponent)")
        completion(outputFileURL)
    }
}

// MARK: - Burst toggle style

struct BurstToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Image(systemName: configuration.isOn ? "bolt.fill" : "bolt")
                .font(.system(size: 22))
                .foregroundColor(configuration.isOn ? Color(hex: "FF8C42") : .white.opacity(0.6))
        }
    }
}

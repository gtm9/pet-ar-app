// ProcessingView.swift
// Shows photogrammetry progress and transitions to AR preview.

import SwiftUI
import RealityKit

struct ProcessingView: View {

    let inputFolder: URL
    @State private var processor = PhotogrammetryProcessor()
    @State private var showError = false
    @State private var navigateToAR = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0D0D1A"), Color(hex: "1A1033")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                // Animated cat
                Text(animatedCat)
                    .font(.system(size: 100))
                    .scaleEffect(processor.isProcessing ? 1.0 : 0.85)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                               value: processor.isProcessing)

                // Title
                Text("Building Your Cat")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")],
                                       startPoint: .leading, endPoint: .trailing)
                    )

                // Progress
                VStack(spacing: 12) {
                    ProgressView(value: processor.progress, total: 1.0)
                        .progressViewStyle(GradientProgressStyle())
                        .frame(height: 10)

                    Text(processor.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: processor.statusMessage)
                }
                .padding(.horizontal, 40)

                // Stage cards
                StageIndicatorView(currentStage: processor.statusMessage)

                Spacer()

                // Cancel
                if processor.isProcessing {
                    Button(role: .destructive) {
                        processor.cancel()
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white.opacity(0.08))
                            .foregroundColor(.white.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 40)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .task {
            await processor.process(inputFolder: inputFolder)
            if processor.outputURL != nil {
                navigateToAR = true
            } else if processor.errorMessage != nil {
                showError = true
            }
        }
        .alert("Processing Failed", isPresented: $showError, presenting: processor.errorMessage) { _ in
            Button("OK") { dismiss() }
        } message: { msg in
            Text(msg)
        }
        .navigationDestination(isPresented: $navigateToAR) {
            if let url = processor.outputURL {
                ARPreviewView(modelURL: url)
            }
        }
    }

    // Rotate between cat emojis
    private var animatedCat: String {
        let cats = ["🐱", "😺", "😸", "🐾"]
        let idx = Int(processor.progress * Double(cats.count * 10)) % cats.count
        return cats[idx]
    }
}

// MARK: - Gradient progress bar

struct GradientProgressStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.1))
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(configuration.fractionCompleted ?? 0))
                    .animation(.easeInOut(duration: 0.4), value: configuration.fractionCompleted)
            }
        }
    }
}

// MARK: - Stage indicator

struct StageIndicatorView: View {
    let currentStage: String
    let stages = [
        ("Pre-processing", "photo.fill"),
        ("Image Alignment", "arrow.triangle.2.circlepath"),
        ("Point Cloud",    "point.3.connected.trianglepath.dotted"),
        ("Mesh",           "cube.fill"),
        ("Texturing",      "paintpalette.fill"),
        ("Optimising",     "sparkles"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(stages.indices, id: \.self) { i in
                let stage = stages[i]
                let active = currentStage.lowercased().contains(stage.0.lowercased().prefix(5))
                VStack(spacing: 4) {
                    Circle()
                        .fill(active
                              ? LinearGradient(colors: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")],
                                              startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [.white.opacity(0.12), .white.opacity(0.12)],
                                              startPoint: .leading, endPoint: .trailing))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: stage.1)
                                .font(.system(size: 13))
                                .foregroundColor(active ? .white : .white.opacity(0.35))
                        )
                    Text(stage.0)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(active ? .white.opacity(0.9) : .white.opacity(0.3))
                        .multilineTextAlignment(.center)
                        .frame(width: 44)
                }
                if i < stages.count - 1 {
                    Rectangle()
                        .fill(.white.opacity(0.12))
                        .frame(height: 1)
                        .padding(.bottom, 20)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

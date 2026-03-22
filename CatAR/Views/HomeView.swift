// HomeView.swift
// Main landing screen for CatAR.

import SwiftUI

enum CaptureMode: String, CaseIterable {
    case photos = "Photos"
    case video  = "Video"

    var icon: String {
        switch self {
        case .photos: return "photo.stack.fill"
        case .video:  return "video.fill"
        }
    }
}

struct HomeView: View {

    @State private var captureMode: CaptureMode = .photos
    @State private var navigateToCapture = false
    @State private var navigateToPreview: URL? = nil
    @State private var savedModels: [URL] = []

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "0D0D1A"), Color(hex: "1A1033")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // MARK: Header
                    VStack(spacing: 8) {
                        Text("🐱")
                            .font(.system(size: 80))
                        Text("CatAR")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                        Text("Turn your cat into a 3D AR model")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.top, 36)

                    // MARK: Capture mode picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Capture Mode")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1.5)

                        HStack(spacing: 12) {
                            ForEach(CaptureMode.allCases, id: \.self) { mode in
                                Button {
                                    withAnimation(.spring(response: 0.35)) {
                                        captureMode = mode
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: mode.icon)
                                        Text(mode.rawValue)
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        captureMode == mode
                                        ? LinearGradient(colors: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")],
                                                         startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.07)],
                                                         startPoint: .leading, endPoint: .trailing)
                                    )
                                    .foregroundColor(captureMode == mode ? .white : .white.opacity(0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(captureMode == mode ? Color.clear : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // MARK: Scan button
                    NavigationLink(destination: CaptureView(mode: captureMode)) {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.title2)
                            Text("Scan My Cat")
                                .font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(
                            LinearGradient(colors: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: Color(hex: "FF3CAC").opacity(0.5), radius: 20, y: 8)
                    }
                    .padding(.horizontal, 24)

                    // MARK: Instructions card
                    VStack(alignment: .leading, spacing: 14) {
                        Text("How it works")
                            .font(.headline)
                            .foregroundColor(.white)
                        ForEach(instructions, id: \.title) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Text(item.emoji)
                                    .font(.title2)
                                    .frame(width: 36)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title).fontWeight(.semibold).foregroundColor(.white)
                                    Text(item.detail).font(.caption).foregroundColor(.white.opacity(0.55))
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.08), lineWidth: 1))
                    .padding(.horizontal, 24)

                    // MARK: Saved models
                    if !savedModels.isEmpty {
                        savedModelsSection
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: loadSavedModels)
        .navigationDestination(item: $navigateToPreview) { url in
            ARPreviewView(modelURL: url)
        }
    }

    // MARK: - Saved models section

    private var savedModelsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Cats")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)

            ForEach(savedModels, id: \.self) { url in
                Button {
                    navigateToPreview = url
                } label: {
                    HStack {
                        Image(systemName: "cube.fill")
                            .foregroundStyle(LinearGradient(colors: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")],
                                                            startPoint: .leading, endPoint: .trailing))
                            .font(.title2)
                            .frame(width: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.deletingPathExtension().lastPathComponent)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("Tap to view in AR")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(16)
                    .background(.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.08), lineWidth: 1))
                }
                .padding(.horizontal, 24)
            }
        }
    }

    // MARK: - Helpers

    private func loadSavedModels() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let all  = (try? FileManager.default.contentsOfDirectory(
            at: docs,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        savedModels = all.filter { $0.pathExtension == "usdz" }
            .sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
    }

    private let instructions: [(emoji: String, title: String, detail: String)] = [
        ("📸", "Capture your cat", "Walk 360° around your cat taking photos or video from all angles"),
        ("⚙️", "Auto-process", "Apple's Object Capture builds a photorealistic 3D model on-device"),
        ("🌍", "Place in AR", "Put your 3D cat anywhere in the real world!")
    ]
}

// MARK: - URL extension

extension URL {
    var creationDate: Date? {
        (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate
    }
}

// MARK: - Hex color

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (1, 1, 0)
        }
        self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }
}

#Preview {
    NavigationStack { HomeView() }.preferredColorScheme(.dark)
}

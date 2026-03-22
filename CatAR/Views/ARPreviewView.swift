// ARPreviewView.swift
// AR placement screen for the generated .usdz model.

import SwiftUI
import RealityKit

struct ARPreviewView: View {

    let modelURL: URL

    @State private var isPlacing = true
    @State private var statusMessage = "Aim at a flat surface, then tap to place your cat 🐾"
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // AR View fills entire screen
            ARViewContainer(
                modelURL: modelURL,
                isPlacing: $isPlacing,
                statusMessage: $statusMessage
            )
            .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top header with close button and status toast
                ZStack(alignment: .top) {
                    HStack {
                        Button {
                            // First dismiss closes the AR view.
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(.black.opacity(0.6)))
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                    }
                    
                    // Status toast at top
                    HStack {
                        Image(systemName: isPlacing ? "scope" : "checkmark.circle.fill")
                            .foregroundColor(isPlacing ? .yellow : .green)
                        Text(statusMessage)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.black.opacity(0.55))
                    .clipShape(Capsule())
                }
                .padding(.top, 60)
                .animation(.easeInOut, value: statusMessage)

                Spacer()

                // Bottom toolbar
                HStack(spacing: 20) {
                    // Re-scan button
                    ToolbarButton(
                        icon: "camera.fill",
                        label: "Re-scan",
                        gradient: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")]
                    ) {
                        dismiss()
                        dismiss() // pop back to home
                    }

                    // Animate button (disabled for Feature 1)
                    ToolbarButton(
                        icon: "figure.walk",
                        label: "Animate",
                        gradient: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)],
                        isDisabled: true
                    ) {}

                    // Share USDZ
                    ShareLink(item: modelURL) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color(hex: "4776E6"), Color(hex: "8E54E9")],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text("Share")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 48)
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
    }
}

// MARK: - Toolbar Button

struct ToolbarButton: View {
    let icon: String
    let label: String
    let gradient: [Color]
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: gradient,
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white.opacity(isDisabled ? 0.4 : 1.0))
                }
                Text(label)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(isDisabled ? 0.4 : 0.85))
            }
        }
        .disabled(isDisabled)
    }
}

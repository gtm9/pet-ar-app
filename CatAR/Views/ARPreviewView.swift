// ARPreviewView.swift
// AR placement screen for the generated .usdz model.

import SwiftUI
import RealityKit

struct ARPreviewView: View {

    let modelURL: URL

    @State private var isPlacing = true
    @State private var statusMessage = "Aim at a flat surface, then tap to place your cat 🐾"
    @State private var showShareSheet = false
    
    // Feature 3: AI & Animation state
    @State private var triggerAnimation = false
    @State private var isAutoBehaviorEnabled = false
    @State private var selectedAnimation: ARViewContainer.CatAnimation? = nil
    
    // Feature 5: World Interaction state
    @State private var lookAtMe = false
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // AR View fills entire screen
            ARViewContainer(
                modelURL: modelURL,
                isPlacing: $isPlacing,
                statusMessage: $statusMessage,
                triggerAnimation: $triggerAnimation,
                isAutoBehaviorEnabled: $isAutoBehaviorEnabled,
                selectedAnimation: $selectedAnimation,
                lookAtMe: $lookAtMe
            )
            .ignoresSafeArea()

            // Overlay UI
            VStack {
                // Top UI layer
                VStack(spacing: 12) {
                    // Row 1: Close button
                    HStack {
                        Button {
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
                    
                    // Row 2: Status toast
                    HStack {
                        Spacer()
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
                        Spacer()
                    }
                }
                .padding(.top, 60)
                .animation(.easeInOut, value: statusMessage)

                Spacer()

                // Bottom toolbar
                HStack(spacing: 12) {
                    // Re-scan button
                    ToolbarButton(
                        icon: "camera.fill",
                        label: "Re-scan",
                        gradient: [Color(hex: "FF8C42"), Color(hex: "FF3CAC")]
                    ) {
                        dismiss()
                        dismiss()
                    }

                    // Behavior Toggle
                    ToolbarButton(
                        icon: isAutoBehaviorEnabled ? "brain.head.profile" : "brain",
                        label: isAutoBehaviorEnabled ? "Auto AI" : "Manual",
                        gradient: isAutoBehaviorEnabled ? [Color.green, Color.blue] : [Color.gray, Color.black],
                        isDisabled: isPlacing
                    ) {
                        isAutoBehaviorEnabled.toggle()
                        statusMessage = isAutoBehaviorEnabled ? "Cat AI is now active! 🧠" : "Cat AI paused."
                    }
                    
                    // Feature 5: Look-at-me Toggle
                    ToolbarButton(
                        icon: lookAtMe ? "eye.fill" : "eye.slash",
                        label: "Eye Contact",
                        gradient: lookAtMe ? [Color.orange, Color.yellow] : [Color.gray, Color.black.opacity(0.8)],
                        isDisabled: isPlacing
                    ) {
                        lookAtMe.toggle()
                        statusMessage = lookAtMe ? "The cat is watching you! 👀" : "The cat is distracted."
                    }

                    // Animations Menu
                    Menu {
                        Button("Jump & Spin") { 
                            selectedAnimation = .hop
                            triggerAnimation = true
                        }
                        Button("Pounce Move") { 
                            selectedAnimation = .pounce 
                            triggerAnimation = true
                        }
                        Button("Stretch Up") { 
                            selectedAnimation = .stretch
                            triggerAnimation = true
                        }
                    } label: {
                        ToolbarButton(
                            icon: "figure.walk",
                            label: "Action",
                            gradient: [Color(hex: "00C9FF"), Color(hex: "92FE9D")],
                            isDisabled: isPlacing
                        ) {}
                    }
                    .disabled(isPlacing)

                    // Share USDZ
                    ShareLink(item: modelURL) {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color(hex: "4776E6"), Color(hex: "8E54E9")],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            Text("Share")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
                .padding(.horizontal, 10)
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

// ARViewContainer.swift
// UIViewRepresentable wrapping ARKit's ARView for model placement.

import SwiftUI
import ARKit
import RealityKit
import Combine

struct ARViewContainer: UIViewRepresentable {

    let modelURL: URL
    @Binding var isPlacing: Bool
    @Binding var statusMessage: String
    @Binding var triggerAnimation: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.sceneUnderstanding.options = []

        // AR configuration
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.sceneReconstruction = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
            ? .mesh : []
        config.environmentTexturing = .automatic
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        // Coaching overlay
        let coachingOverlay = ARCoachingOverlayView()
        coachingOverlay.session = arView.session
        coachingOverlay.goal = .horizontalPlane
        coachingOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(coachingOverlay)

        // Gesture recognizer
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handleTap(_:)))
        arView.addGestureRecognizer(tap)

        context.coordinator.arView = arView
        context.coordinator.modelURL = modelURL
        context.coordinator.isPlacing = _isPlacing
        context.coordinator.statusMessage = _statusMessage

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // Trigger programmatic RealityKit animation when the SwiftUI binding changes
        if triggerAnimation {
            context.coordinator.playHopAnimation()
            
            // Immediately reset binding to allow future triggers (must be dispatched to avoid modifying state during view update)
            DispatchQueue.main.async {
                triggerAnimation = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject {
        weak var arView: ARView?
        var modelURL: URL? {
            didSet {
                if let url = modelURL, loadedModel == nil {
                    loadModelAsync(url: url)
                }
            }
        }
        var isPlacing: Binding<Bool>?
        var statusMessage: Binding<String>?
        
        // Store the loaded model in memory so it's ready to place instantly
        private var loadedModel: ModelEntity?
        private var placedEntity: ModelEntity?
        private var isAnimating = false

        func playHopAnimation() {
            guard let entity = placedEntity else { return }
            guard !isAnimating else { return }
            isAnimating = true
            
            let originalTransform = entity.transform
            
            // Hop up 20cm and rotate 180 degrees
            var upTransform = originalTransform
            upTransform.translation.y += 0.2
            upTransform.rotation = simd_quatf(angle: .pi, axis: [0, 1, 0]) * originalTransform.rotation
            
            // Land back down and complete 360 degree rotation
            var downTransform = originalTransform
            downTransform.rotation = simd_quatf(angle: .pi * 2, axis: [0, 1, 0]) * originalTransform.rotation
            
            // Execute sequence
            entity.move(to: upTransform, relativeTo: entity.parent, duration: 0.3, timingFunction: .easeOut)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) {
                // By 0.31s, the first animation should be complete
                entity.move(to: downTransform, relativeTo: entity.parent, duration: 0.3, timingFunction: .easeIn)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) {
                    self.isAnimating = false
                    // Reset rotation perfectly flat to avoid drift from floating point errors
                    entity.transform.rotation = originalTransform.rotation
                }
            }
        }

        private func loadModelAsync(url: URL) {
            print("📦 [ARViewContainer] Starting async load of model from: \(url.lastPathComponent)")
            Task {
                do {
                    let entity = try await ModelEntity(contentsOf: url)
                    print("✅ [ARViewContainer] Model loaded successfully into memory.")
                    
                    // Pre-calculate scale
                    let bounds = entity.visualBounds(relativeTo: nil)
                    print("📏 [ARViewContainer] Model bounds: extents = \(bounds.extents)")
                    
                    let height = bounds.extents.y
                    if height > 0 {
                        // Make it roughly 40cm tall by default so it's clearly visible
                        let targetHeight: Float = 0.40
                        let scale = targetHeight / height
                        entity.scale = SIMD3<Float>(repeating: scale)
                        print("🔍 [ARViewContainer] Applied scale factor: \(scale)")
                    }
                    
                    entity.generateCollisionShapes(recursive: true)
                    self.loadedModel = entity
                } catch {
                    print("❌ [ARViewContainer] Failed to load model: \(error)")
                    statusMessage?.wrappedValue = "Failed to load model: \(error.localizedDescription)"
                }
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let arView else { return }
            
            guard let readyModel = loadedModel else {
                print("⚠️ [ARViewContainer] Tap ignored: Model is not yet loaded into memory.")
                statusMessage?.wrappedValue = "Still loading model, please wait..."
                return
            }

            let location = recognizer.location(in: arView)
            print("👆 [ARViewContainer] Screen tapped at: \(location)")

            // Raycast for surfaces (Try horizontal plane first, then any surface)
            var results = arView.raycast(from: location,
                                         allowing: .estimatedPlane,
                                         alignment: .horizontal)
            
            var worldTransform: simd_float4x4?
            
            if let first = results.first {
                worldTransform = first.worldTransform
                print("🎯 [ARViewContainer] Surface found from raycast.")
            } else {
                print("⚠️ [ARViewContainer] No surface. Trying fallback manual placement...")
                // Place 1 meter in front of camera
                if let cameraTransform = arView.session.currentFrame?.camera.transform {
                    var translation = matrix_identity_float4x4
                    translation.columns.3.z = -1.0 // 1 meter forward
                    worldTransform = matrix_multiply(cameraTransform, translation)
                    statusMessage?.wrappedValue = "No surface found. Placing in mid-air!"
                }
            }

            guard let finalTransform = worldTransform else {
                statusMessage?.wrappedValue = "Search for a floor first!"
                return
            }

            // Remove previously placed model
            if let existing = placedEntity {
                existing.removeFromParent()
                placedEntity = nil
            }

            // Place anchor
            let anchor = AnchorEntity(world: finalTransform)
            arView.scene.addAnchor(anchor)

            // Load USDZ
            guard let readyModel = loadedModel else {
                print("⚠️ [ARViewContainer] Model still loading.")
                statusMessage?.wrappedValue = "Model still loading..."
                return
            }
            
            // Re-declaring the entityToPlace and scaling logic
            let entityToPlace = readyModel.clone(recursive: true)
            
            // Final check on scaling - ensure it's not invisible
            let bounds = entityToPlace.visualBounds(relativeTo: nil)
            if bounds.extents.y < 0.01 {
                print("⚠️ [ARViewContainer] Model extents too small (\(bounds.extents.y)). Forcing scale up.")
                entityToPlace.scale = [10.0, 10.0, 10.0] // Emergency visibility boost
            }

            entityToPlace.generateCollisionShapes(recursive: true)
            
            // Enable gestures
            arView.installGestures([.translation, .rotation, .scale], for: entityToPlace)

            anchor.addChild(entityToPlace)
            self.placedEntity = entityToPlace
            print("🎉 [ARViewContainer] Cat placed! Extents: \(bounds.extents)")

            statusMessage?.wrappedValue = "Cat placed! Drag or pinch to resize."
            isPlacing?.wrappedValue = false
        }
    }
}

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

    func updateUIView(_ uiView: ARView, context: Context) {}

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
            
            // Debug: Add a small cube to verify anchor position
            let debugCube = ModelEntity(mesh: .generateBox(size: 0.05), materials: [SimpleMaterial(color: .green.withAlphaComponent(0.5), isMetallic: false)])
            anchor.addChild(debugCube)
            
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

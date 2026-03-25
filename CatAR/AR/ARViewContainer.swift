// ARViewContainer.swift
// UIViewRepresentable wrapping ARKit's ARView for model placement and autonomous behavior.

import SwiftUI
import ARKit
import RealityKit
import Combine

struct ARViewContainer: UIViewRepresentable {

    let modelURL: URL
    @Binding var isPlacing: Bool
    @Binding var statusMessage: String
    @Binding var triggerAnimation: Bool
    @Binding var isAutoBehaviorEnabled: Bool
    @Binding var selectedAnimation: CatAnimation?
    @Binding var lookAtMe: Bool

    enum CatAnimation {
        case hop, pounce, stretch
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.sceneUnderstanding.options = [.occlusion, .physics, .collision]

        // AR configuration
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        
        // Feature 5: Enable Scene Depth (Occlusion) if supported
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        }
        
        config.sceneReconstruction = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
            ? .mesh : []
        config.environmentTexturing = .automatic
        
        arView.session.delegate = context.coordinator
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
        // Handle explicit animation triggers
        if triggerAnimation, let animation = selectedAnimation {
            switch animation {
            case .hop: context.coordinator.playHopAnimation()
            case .pounce: context.coordinator.playPounceAnimation()
            case .stretch: context.coordinator.playStretchAnimation()
            }
            
            DispatchQueue.main.async {
                triggerAnimation = false
                selectedAnimation = nil
            }
        }
        
        // Toggle autonomous behavior
        if isAutoBehaviorEnabled {
            context.coordinator.startAutonomousBehavior()
        } else {
            context.coordinator.stopAutonomousBehavior()
        }
        
        // Feature 5: Toggle Look-at-me behavior
        if lookAtMe {
            context.coordinator.startLookAtMe()
        } else {
            context.coordinator.stopLookAtMe()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, ARSessionDelegate {
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
        
        private var loadedModel: ModelEntity?
        private var placedEntity: ModelEntity?
        private var isAnimating = false
        private var behaviorTask: Task<Void, Never>?
        private var lookAtMeTask: Task<Void, Never>?

        // MARK: - Autonomous Behavior

        func startAutonomousBehavior() {
            guard behaviorTask == nil else { return }
            print("🐱 [Coordinator] Starting Cat AI autonomous loop.")
            
            behaviorTask = Task {
                while !Task.isCancelled {
                    // Wait 5-12 seconds between actions
                    try? await Task.sleep(nanoseconds: UInt64.random(in: 5...12) * 1_000_000_000)
                    
                    guard let entity = placedEntity, !isAnimating else { continue }
                    
                    // 70% chance to Wander, 30% chance to Pounce
                    if Float.random(in: 0...1) < 0.7 {
                        await performWander()
                    } else {
                        await MainActor.run { playPounceAnimation() }
                    }
                }
            }
        }

        func stopAutonomousBehavior() {
            behaviorTask?.cancel()
            behaviorTask = nil
            print("🛑 [Coordinator] Cat AI loop stopped.")
        }
        
        // MARK: - Feature 5: Look-at-me Logic
        
        func startLookAtMe() {
            guard lookAtMeTask == nil else { return }
            print("👁️ [Coordinator] Starting Look-at-me tracking.")
            
            lookAtMeTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 33_000_000) // ~30fps
                    
                    guard let entity = placedEntity, 
                          let arView = arView,
                          !isAnimating else { continue }
                    
                    // Get camera position in world space
                    let cameraTransform = arView.cameraTransform
                    let targetPosition = cameraTransform.translation
                    
                    // Only track if the cat is placed on an anchor
                    if let anchor = entity.anchor {
                        // Project target onto the same horizontal plane (Y level of cat)
                        var lookTarget = targetPosition
                        lookTarget.y = entity.position.y 
                        
                        // Smoothly rotate the entity to face the camera
                        entity.look(at: lookTarget, from: entity.position, relativeTo: anchor)
                    }
                }
            }
        }
        
        func stopLookAtMe() {
            lookAtMeTask?.cancel()
            lookAtMeTask = nil
            print("🛑 [Coordinator] Look-at-me stopped.")
        }

        private func performWander() async {
            guard let entity = placedEntity, let parent = entity.parent else { return }
            
            await MainActor.run { isAnimating = true }
            
            // Pick a random point within 1 meter
            let randomX = Float.random(in: -0.8...0.8)
            let randomZ = Float.random(in: -0.8...0.8)
            
            var targetTransform = entity.transform
            targetTransform.translation.x += randomX
            targetTransform.translation.z += randomZ
            
            // 1. Face the direction
            let direction = normalize(targetTransform.translation - entity.transform.translation)
            if length(direction) > 0.1 {
                let lookTransform = entity.transform
                entity.look(at: targetTransform.translation, from: entity.transform.translation, relativeTo: parent)
                // We actually want a smooth rotation, but for simplicity we'll just snap and walk
            }
            
            // 2. "Walk" there
            let duration = Double(length(targetTransform.translation - entity.transform.translation)) * 2.0
            entity.move(to: targetTransform, relativeTo: parent, duration: duration, timingFunction: .easeInOut)
            
            try? await Task.sleep(nanoseconds: UInt64(duration * 1.1 * 1_000_000_000))
            
            await MainActor.run { isAnimating = false }
        }

        // MARK: - Animations

        func playHopAnimation() {
            guard let entity = placedEntity, !isAnimating else { return }
            isAnimating = true
            
            let originalTransform = entity.transform
            var upTransform = originalTransform
            upTransform.translation.y += 0.2
            upTransform.rotation = simd_quatf(angle: .pi, axis: [0, 1, 0]) * originalTransform.rotation
            
            var downTransform = originalTransform
            downTransform.rotation = simd_quatf(angle: .pi * 2, axis: [0, 1, 0]) * originalTransform.rotation
            
            entity.move(to: upTransform, relativeTo: entity.parent, duration: 0.3, timingFunction: .easeOut)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) {
                entity.move(to: downTransform, relativeTo: entity.parent, duration: 0.3, timingFunction: .easeIn)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.31) {
                    self.isAnimating = false
                    entity.transform.rotation = originalTransform.rotation
                }
            }
        }

        func playPounceAnimation() {
            guard let entity = placedEntity, !isAnimating else { return }
            isAnimating = true
            
            let originalTransform = entity.transform
            
            // Lunge forward 30cm and down slightly
            var lungeTransform = originalTransform
            let forward = entity.transform.matrix.columns.2.xyz // Forward is -Z in RealityKit usually
            lungeTransform.translation += forward * -0.3
            lungeTransform.translation.y -= 0.05
            
            entity.move(to: lungeTransform, relativeTo: entity.parent, duration: 0.2, timingFunction: .easeOut)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                entity.move(to: originalTransform, relativeTo: entity.parent, duration: 0.4, timingFunction: .easeInOut)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    self.isAnimating = false
                }
            }
        }

        func playStretchAnimation() {
            guard let entity = placedEntity, !isAnimating else { return }
            isAnimating = true
            
            let originalScale = entity.scale
            let stretchScale = originalScale * [1.0, 1.2, 1.3] // Stretch up and forward
            
            let stretchTransform = Transform(scale: stretchScale, 
                                            rotation: entity.transform.rotation, 
                                            translation: entity.transform.translation)
            
            entity.move(to: stretchTransform, relativeTo: entity.parent, duration: 0.6, timingFunction: .easeInOut)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                guard let self = self, let entity = self.placedEntity else { return }
                
                let returnTransform = Transform(scale: originalScale, 
                                               rotation: entity.transform.rotation, 
                                               translation: entity.transform.translation)
                
                entity.move(to: returnTransform, relativeTo: entity.parent, duration: 0.4, timingFunction: .easeInOut)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
                    self?.isAnimating = false
                }
            }
        }

        // MARK: - Loading Logic

        private func loadModelAsync(url: URL) {
            print("📦 [ARViewContainer] Starting async load of model from: \(url.lastPathComponent)")
            Task {
                do {
                    let entity = try await ModelEntity(contentsOf: url)
                    let bounds = entity.visualBounds(relativeTo: nil)
                    let height = bounds.extents.y
                    if height > 0 {
                        let targetHeight: Float = 0.40
                        let scale = targetHeight / height
                        entity.scale = SIMD3<Float>(repeating: scale)
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
            guard let arView, let readyModel = loadedModel else { return }
            let location = recognizer.location(in: arView)
            
            var results = arView.raycast(from: location, allowing: .estimatedPlane, alignment: .horizontal)
            var worldTransform: simd_float4x4?
            
            if let first = results.first {
                worldTransform = first.worldTransform
            } else if let cameraTransform = arView.session.currentFrame?.camera.transform {
                var translation = matrix_identity_float4x4
                translation.columns.3.z = -1.0
                worldTransform = matrix_multiply(cameraTransform, translation)
            }

            guard let finalTransform = worldTransform else { return }

            if let existing = placedEntity {
                existing.removeFromParent()
            }

            let anchor = AnchorEntity(world: finalTransform)
            arView.scene.addAnchor(anchor)

            let entityToPlace = readyModel.clone(recursive: true)
            entityToPlace.generateCollisionShapes(recursive: true)
            arView.installGestures([.translation, .rotation, .scale], for: entityToPlace)

            anchor.addChild(entityToPlace)
            self.placedEntity = entityToPlace
            
            statusMessage?.wrappedValue = "Cat placed! It might start wandering soon."
            isPlacing?.wrappedValue = false
        }
    }
}

extension simd_float4 {
    var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

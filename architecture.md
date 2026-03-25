# CatAR Architecture

This document describes the core architecture of `CatAR`, an iOS application designed to generate and render 3D AR models of pets using Apple's Object Capture APIs.

## High Level Overview

The app follows a modern SwiftUI MVVM architecture augmented with Apple's latest programmatic RealityKit frameworks. 

### Core Components
1. **App Entry & Navigation (`CatARApp`, `HomeView`)**: Serves as the primary coordinator of the user's flow from capturing a pet to viewing a generated AR model.
2. **Photogrammetry Engine (`PhotogrammetryProcessor`)**: An active `@Observable` manager that interfaces with Apple's `PhotogrammetrySession` to asynchronously process raw images/video frames into a `.usdz` 3D model.
3. **AR Rendering (`ARViewContainer`, `ARPreviewView`)**: Uses `UIViewRepresentable` and `Coordinator` patterns to bridge UIKit/RealityKit capabilities (like Raycasting and Anchors) into the declarative SwiftUI paradigm.

## State Management Principles
`CatAR` adheres strictly to standard SwiftUI state management best practices:
- Internal view state rests in `private @State` properties.
- Shared/injected configuration states (like triggering animations from UI overlays to underlying AR containers) utilize `@Binding`.
- Complex asynchronous processing lives in `@Observable` classes independent of the UI layer to maintain purity in the View `body`.

## Animation & AI Behavior System
Because Photogrammetry generates static 3D meshes (without skeletons or bone rigs), standard skeletal animations cannot be applied. Instead, `CatAR` implements **Transform-Based Animations & AI**:
- **Programmatic RealityKit Animations**: `Entity.move(to:duration:timingFunction)` sequences apply full-body translations and rotations to simulate life-like motion (e.g., "Hop & Spin", "Pounce", "Stretch").
- **Autonomous Cat AI**: A state machine within the `Coordinator` manages a background `Task` that periodically triggers behaviors (e.g., wandering to a random point on the floor) when the "Auto Behavior" mode is enabled in the UI.
- **World Interaction (Feature 5)**: 
    - **Occlusion**: Utilizes `.sceneDepth` and `.personSegmentation` frame semantics to ensure the virtual cat is correctly hidden behind physical furniture and people.
    - **Eye Contact**: An async `lookAtMeTask` in the `Coordinator` continuously adjusts the cat's rotation to face the AR camera's world position, simulating lifelike attention.
- **State Guarding**: All animations and AI movements are guarded by an `isAnimating` flag to prevent overlapping transforms and ensure smooth transitions.

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

## Animation System
Because Photogrammetry generates static 3D meshes (without skeletons or bone rigs), standard skeletal animations cannot be applied. Instead, `CatAR` implements **Transform-Based Animations**:
- Programmatic RealityKit `Entity.move(to:duration:timingFunction)` sequences apply full-body translations and rotations to simulate life-like motion (e.g., a "Hop & Spin").
- Animation states are tightly coupled to the Coordinator to prevent redundant or conflicting transforms during active sequences.

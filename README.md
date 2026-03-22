# CatAR - Pet AR App

An iOS app that uses Apple's `PhotogrammetrySession` to turn 360-degree photos and videos of your pet into a 3D `.usdz` model that you can place in Augmented Reality.

## Features Currently Implemented
*   **Photo & Video Capture**: Custom camera UI to scan objects or record video.
*   **Asset Extraction**: Extracts evenly-spaced 60 frames from videos.
*   **Photogrammetry**: Processes images securely on-device into a 3D model.
*   **AR Viewer**: Raycasts to horizontal or fallback surfaces to place the 3D model.
*   **Terminal Build System**: Configured for direct `xcodebuild` injection outside of Xcode IDE.

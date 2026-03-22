# CatAR - Pet AR App

An iOS app that uses Apple's `PhotogrammetrySession` to turn 360-degree photos and videos of your pet into a 3D `.usdz` model that you can place in Augmented Reality.

## Features Currently Implemented
*   **Photo & Video Capture**: Custom camera UI to scan objects or record video.
*   **Asset Extraction**: Extracts evenly-spaced 60 frames from videos.
*   **Photogrammetry**: Processes images securely on-device into a 3D model.
*   **AR Viewer**: Raycasts to horizontal or fallback surfaces to place the 3D model.
*   **Terminal Build System**: Configured for direct `xcodebuild` injection outside of Xcode IDE.

## Build & Deploy (Terminal Guide)
Due to macOS iCloud synchronization (`com.apple.FinderInfo` detritus) and Xcode's automatic codesigning behaviors, the most reliable way to build and deploy this app is entirely through the terminal to an isolated `/tmp` directory.

### 1. Identify Your Connected iPhone
Find the 36-character `Identifier` for your connected iPhone via:
```bash
xcrun devicectl list devices
```

### 2. Clean, Build, and Install
Execute the following one-liner in the terminal. Replace the `A0A5...` dummy ID with your iPhone's identifier:
```bash
# Clear previous cache
rm -rf /tmp/CatAR_build

# Regenerate project (ensures manual signing settings are clean)
ruby /tmp/create_catAR_project.rb

# Build to the isolated `/tmp` directory
xcodebuild -project CatAR.xcodeproj -scheme CatAR -destination 'platform=iOS,name=appleeskai14' -allowProvisioningUpdates -derivedDataPath /tmp/CatAR_build build

# Install the `.app` bundle onto the phone
xcrun devicectl device install app --device A0A50E3A-392E-57BF-8B0E-1D9A7D30E3E2 /tmp/CatAR_build/Build/Products/Debug-iphoneos/CatAR.app
```

### 3. Launch & Debug
To remotely launch the app and stream AR placement logs directly to your terminal:
```bash
xcrun devicectl device process launch --device A0A50E3A-392E-57BF-8B0E-1D9A7D30E3E2 com.catapp.CatAR
xcrun devicectl device process log --device A0A50E3A-392E-57BF-8B0E-1D9A7D30E3E2 --process CatAR
```

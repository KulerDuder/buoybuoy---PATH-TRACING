# Controls & Usage

## 🎮 Game Controls (Current Build)

- **Left Click (on water):** Commands the boat to navigate to the target position. A glowing marker appears.
- **L Key:** Toggles the boat's lantern on/off. The path tracer will immediately show the dynamic light and shadows.
- **Camera:** The `IsoCamera` follows the boat automatically. 
- **Middle Mouse Drag:** Rotates the isometric camera around the boat.
- **Mouse Wheel:** Zooms the isometric camera in/out.

## 🛠️ Path Tracer Debug Controls (For Testing)

These are useful if you want to see the path tracing convergence in action:
- **Leave the boat alone:** Stop moving the mouse. The path tracer will accumulate samples and the noise will disappear in 2-3 seconds.
- **Move the camera:** The image will reset and become noisy again. This is expected behavior (like in Blender Cycles).
- **Toggle Node:** You can check/uncheck the `PathTracerOverlay` node in the Godot editor to compare the native Godot renderer with the path traced version.

## ⚙️ Inspector Settings (Pathtracer Overlay)

- `Resolution Scale`: (Default 0.5) Renders at half resolution. Lower this to 0.35 if you have performance issues.
- `Samples When Still`: (Default 4) Samples per frame to converge when nothing moves.
- `Samples When Moving`: (Default 2) Samples per frame when the camera moves.
- `Max Samples`: (Default 1024) Stops calculating if the image is already clean.
- `Exposure`: Adjusts the overall brightness.
- `Water Level`: Must match the `water.gd` level (Default 0.0).

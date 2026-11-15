# Godot Real-Time Path Tracing Overlay

A custom, real-time path tracing renderer built for **Godot 4.7** using **GDScript** and **GLSL Compute Shaders**. 

This system does not replace Godot's native renderer. Instead, it runs as an overlay (`CanvasLayer` + `TextureRect`) that captures the scene's geometry and lights, builds a Bounding Volume Hierarchy (BVH) on the CPU, and renders a fully path-traced image on the GPU.

## 🌟 Current Features

- **Hardware-agnostic:** Runs on any GPU supporting Vulkan compute shaders (no RTX hardware required).
- **Static Geometry:** Fast BVH traversal for terrain, buildings, and props.
- **Dynamic Geometry:** Real-time tracking of moving objects (boats, barrels, markers) using OBBs and spheres.
- **Physical Materials:** Support for Albedo, Roughness, Metallic, and Emission (glow).
- **Dynamic Lighting:** Supports `DirectionalLight3D`, `OmniLight3D`, and `SpotLight3D`.
- **Day/Night Cycle:** Fully integrated with the game's `dayandnight.gd` script, including procedural stars and moon lighting.
- **Cinematic Post-Processing:** ACES Tonemapping, adaptive ray offset, and firefly clamping.
- **Progressive Rendering:** The image accumulates samples when the camera and scene are still, resulting in a clean, noise-free "Cycles-like" render.

## 🚀 Quick Start

1. Ensure your project is using the **Forward+** renderer (`Project Settings > Rendering > Renderer`).
2. Add a new `Node` to your main 3D scene.
3. Attach the `res://pathtracer/pathtracer_overlay.gd` script to this node.
4. Run the game. The path tracer will automatically scan the scene and overlay the rendered image.
5. *Optional:* Toggle the `PathTracerOverlay` node on/off to compare with the native Godot renderer.

## 🎮 Controls & Interactions

- **L Key**: Toggles the boat's lantern. The path tracer will immediately show the dynamic light and shadows.
- **Click on Water**: Spawns the navigation marker. The path tracer represents it as a glowing dynamic sphere.
- **Dynamic Movement**: Moving the camera resets the accumulation buffer (shows noise). Stopping the camera allows the image to converge.

## 📚 Documentation Index

- [ARCHITECTURE.md](ARCHITECTURE.md) - File structure and module responsibilities.
- [RENDERING_PIPELINE.md](RENDERING_PIPELINE.md) - How the BVH, buffers, and compute shader work together.
- [FEATURES.md](FEATURES.md) - Detailed breakdown of all implemented features.
- [CONTROLS.md](CONTROLS.md) - Extended guide on game controls and debug tools.
- [LIMITATIONS.md](LIMITATIONS.md) - What the renderer cannot do (yet) and why.
- [ROADMAP.md](ROADMAP.md) - Prioritized list of future improvements (D.4, D.5, etc.).
- [CHANGELOG.md](CHANGELOG.md) - Development milestones and key architectural decisions.

## ⚠️ Important Requirements

- **Renderer:** Must be Forward+ (or Mobile). The Compatibility renderer does not support `RenderingDevice`.
- **GPU:** Must support Vulkan Compute Shaders. 
- **Architecture:** The path tracer requires a GPU buffer upload for static geometry. Scenes with more than 1 million triangles may cause performance drops during the initial scan.

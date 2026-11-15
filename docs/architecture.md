# Architecture & File Structure

The path tracer is designed with a **modular, separation-of-concerns** architecture. The main `pathtracer_overlay.gd` acts strictly as an orchestrator. It does not know how to build a BVH, how to pack GPU buffers, or how to read lights. It delegates all those tasks to specialized modules.

## 📂 Directory Tree

```text
res://pathtracer/
├── pathtracer_overlay.gd          # The main node. Orchestrates the frame loop.
├── pathtracer.glsl                # The compute shader (traversal, lighting, accumulation).
├── core/
│   └── gpu_resources.gd           # Encapsulates all RenderingDevice logic (buffers, textures).
├── scene/
│   ├── scene_scanner.gd           # Extracts static triangles from the Godot scene tree.
│   ├── bvh_builder.gd             # Builds the Bounding Volume Hierarchy on the CPU.
│   ├── dynamic_tracker.gd         # Tracks moving objects (boats, barrels, markers).
│   └── light_collector.gd         # Gathers OmniLight3D and SpotLight3D from the scene.
└── integrations/
	└── daynight_link.gd           # Bridges the path tracer with `dayandnight.gd`.

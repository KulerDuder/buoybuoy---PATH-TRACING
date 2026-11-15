# Implemented Features

This document lists all features currently supported by the path tracer, along with technical notes.

## 🏗️ Geometry
- **Static Geometry (BVH):** All `MeshInstance3D` nodes in the scene are scanned and built into a BVH. Supports Vertex Colors (for terrain).
- **Dynamic Objects:** Supports `RigidBody3D`, `CharacterBody3D`, and `AnimatableBody3D`. 
  - *Approximation:* Dynamic objects are rendered as Oriented Bounding Boxes (OBB) or Spheres.
  - *Custom Objects:* Any `MeshInstance3D` in the `pt_dynamic` group will be tracked.
- **Synthetic Water:** A flat, infinite-looking plane added to the BVH at `water_level` to reflect the sky and receive shadows.

## 🎨 Materials
- **Albedo (Base Color):** Supported.
- **Roughness:** Supported (0.0 = mirror, 1.0 = fully diffuse).
- **Metallic:** Supported.
- **Emission:** Supported. Materials with `emission_enabled = true` will glow and act as light sources (e.g., lightbulbs).
- **Vertex Colors:** Supported (used by the terrain).

## 💡 Lighting
- **Directional Light (Sun/Moon):** Driven by the `dayandnight.gd` integration. Casts shadows.
- **OmniLight3D:** Supported up to 16 dynamic lights. Attenuation and shadows are calculated.
- **SpotLight3D:** Supported. Inner/outer cone angles and shadows are calculated.
- **Ambient Light:** A simple ambient term is added based on the day/night cycle.

## 🌌 Environment (Sky)
- **Day Sky:** Procedural gradient (horizon to zenith).
- **Night Sky:** Dark gradient with procedurally generated stars using a hash function.
- **Sun/Moon Discs:** Visible in the sky and reflect on the water.

## 🎥 Camera
- **Perspective:** Supported.
- **Orthographic (Isometric):** Supported. Essential for the current game's camera style.

## ⚙️ Rendering & Quality
- **Progressive Accumulation:** The image gets cleaner when the camera and scene are static.
- **Adaptive Resolution:** The `resolution_scale` export variable allows rendering at 0.5x or 0.75x and scaling up.
- **ACES Tonemapping:** Prevents colors from washing out.
- **Dynamic Sample Rate:** Uses 4 samples when still, and 2 samples when moving to maintain FPS.

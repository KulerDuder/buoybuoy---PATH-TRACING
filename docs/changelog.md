# Development Changelog

## Version 0.3.0 - The Refactor & Lighting Update
- **Major Architecture Refactor:**
  - Extracted `GPUResources`, `DynamicTracker`, `LightCollector`, and `DayNightLink`.
  - Shrunk `pathtracer_overlay.gd` from ~600 lines to ~170 lines.
- **Features Added:**
  - Full Day/Night cycle integration (Sun, Moon, Stars).
  - Dynamic Omni/Spot lighting support (up to 16 lights).
  - Material emission support (glowing bulbs).
  - Dynamic tracking for the navigation marker (rendered as a glowing sphere).
  - Added `pt_dynamic` group for easy scripting of dynamic objects.

## Version 0.2.0 - Game Integration
- **Major Features:**
  - Ported the path tracer from the test project into the actual game.
  - Replaced the hardcoded scene with `SceneScanner` and `BVHBuilder`.
  - Added support for Orthographic (Isometric) camera projection.
  - Added synthetic water plane for reflections and navigation clarity.
  - Implemented ACES tonemapping and Firefly clamping.
  - Fixed the "Shadow Acne" and camera-jitter bugs using adaptive ray offsets and movement thresholds.

## Version 0.1.0 - Prototype
- **Initial implementation:**
  - Built a compute shader path tracer from scratch.
  - Implemented basic diffuse and GGX specular BRDFs.
  - Tested with primitive shapes (a car made of boxes, procedural city).

---

# 📖 Key Conversation References

This section serves as a historical log of the key architectural decisions made during development.

1. **The Initial Idea:**
   > "me gustaria mucho que me ayudes a hacer una especie de plugin para godot 4.7 para conseguir path tracing."
   *Decision:* We decided to skip the full addon structure initially and focus on a pure GDScript/GLSL proof-of-concept.

2. **The Shift to the Real Game:**
   > "este juego tiene algo especial que esta todo generado de manera programatica... determinas si podemos hacer algo."
   *Decision:* We abandoned the test project and ported the system to the actual game. We identified the BVH as the main technical blocker.

3. **Discovering the "Claymation" Look:**
   > "El barquito casi parece una especie de barco hecho de plastilina... los barriles tambien se ven preciosos."
   *Decision:* We accepted the OBB/Sphere approximation for dynamic objects because it gives the game a unique, artistic aesthetic, rather than forcing full dynamic meshes.

4. **The Rendering Bug (Shadow Acne):**
   > "Tienes toda la razón, y el detalle de que la cámara esté relacionada ha sido la pista clave... No es un bug del sombreado en sí. Es un bug de acumulación de muestras."
   *Decision:* We implemented camera movement thresholds and adaptive ray offsets to fix the visual glitches when looking at grazing angles.

5. **The Architectural Refactor:**
   > "cada pequeña cosa que queramos añadir, seran mas y mas lineas en pathtracer_overlay y el glsl? ... Te preocupa que el proyecto colapse bajo su propio peso."
   *Decision:* We stopped feature development and completely modularized the code into `core`, `scene`, and `integrations` folders to ensure the project can scale.

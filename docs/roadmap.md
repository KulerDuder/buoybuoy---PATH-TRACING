# Roadmap & Future Improvements

This is a prioritized list of features to implement next.

## 🔥 High Priority (Fixes & Polish)

1. **Fix Lantern Range (D.3.1):**
   - Update `island_props.gd` to set `omni_range = 15.0`.
   - Update `pathtracer.glsl` to use `dist > col_range.w * 1.5` for softer light falloff.

2. **Glow / Bloom Post-Processing (D.4):**
   - Implement a simple Gaussian blur on the `output_image` for bright pixels (emission, sun). 
   - This would make the lanterns and boat lights look even more cinematic.

## 🚀 Medium Priority (Gameplay Features)

3. **Dynamic Triangles (D.5):**
   - Replace the OBB/Sphere approximation for the boat and barrels with their actual meshes. 
   - This requires updating the Dynamic Buffer to hold triangles, or building a secondary dynamic BVH on the GPU.

4. **Projectiles & Particles:**
   - Add support for moving spheres with high emission (e.g., cannonballs on fire). 
   - Since spheres are already supported, this just requires adding them to the `pt_dynamic` group.

5. **Day/Night Sky Shader:**
   - Improve the procedural sky. Add clouds or a more complex color palette during twilight.

## 🧪 Low Priority (Advanced Rendering)

6. **Transparency & Water Refraction (D.6):**
   - Implement stochastic transparency for glass.
   - Add screen-space refraction for the water to see the sea floor.

7. **GDExtension Port:**
   - Rewrite the heavy CPU parts (`BVHBuilder` and `SceneScanner`) in C++ using GDExtension.
   - This would reduce the initial load time from ~300ms to <10ms and allow for much larger scenes.

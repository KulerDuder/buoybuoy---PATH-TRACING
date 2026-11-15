# Known Limitations & Constraints

While the path tracer looks amazing, it is a custom implementation and has technical limitations compared to full production engines like Unreal Engine 5 or Blender Cycles.

## 🚧 Current Bugs / Missing Features

1. **Distant Lanterns Cutoff (BUG):** 
   - *Issue:* The lanterns on the island stalls might not cast light if you are too far away, or the light cuts off abruptly.
   - *Cause:* The `omni_range` in `island_props.gd` is too small (8.0), and the shader's distance check (`dist > col_range.w`) is too harsh.
   - *Fix needed:* Increase `omni_range` to 15.0 and multiply the shader's distance check by 1.5.

2. **Dynamic Objects are Primitives:**
   - *Issue:* The boat, barrels, and marker look like floating boxes and spheres, not their actual 3D meshes.
   - *Cause:* Building a BVH for dynamic objects every frame is too expensive. We approximate them using OBBs and Spheres.
   - *Future:* We could support full dynamic triangle meshes if we build a specialized GPU BVH.

3. **No True Transparency / Glass:**
   - *Issue:* The water is a solid plane (not see-through). You can't make transparent materials.
   - *Cause:* Refraction and transparency require complex ray splitting (or stochastic transparency) and a material system that supports IOR (Index of Refraction).

4. **No Volumetrics (Fog/Clouds):**
   - *Issue:* Fog is currently a post-processing effect in Godot, not in the path tracer.
   - *Cause:* Volumetric rendering requires ray marching inside the path tracing loop, which is very expensive computationally.

5. **Maximum 16 Dynamic Lights:**
   - *Issue:* If you have more than 16 Omni/Spot lights active, only the 16 closest to the camera will be rendered.
   - *Cause:* Shader loop unrolling and register limits. Pushing it to 32 caused memory crashes on some GPUs.

6. **No Hardware Ray Tracing:**
   - *Issue:* It uses Compute Shaders (software traversal).
   - *Cause:* Godot 4.7's native RT is experimental and complex to integrate via GDScript. This approach runs on *any* Vulkan GPU.

7. **Shadow Acne:**
   - *Issue:* Some extremely sharp, distant geometry might have tiny shadow artifacts.
   - *Cause:* Floating point precision. We use an adaptive ray offset, but extreme distances can still cause precision loss.

# Rendering Pipeline

The path tracer uses a compute shader (`pathtracer.glsl`) dispatched across the screen. This document explains how the GPU processes the data.

## 1. The Buffers (GPU Memory)

The `GPUResources` module creates several Storage Buffers (SSBO) and one Uniform Buffer (UBO). The shader binds them as follows:

| Binding | Type | Buffer Name | Description |
|---|---|---|---|
| 0 | Image | `output_image` | The final HDR image displayed on the screen. |
| 1 | Uniform | `Params` | Camera matrices, sun/moon data, screen resolution, exposure, sample count. |
| 2 | Storage | `TriangleBuffer` | Static geometry. 10 `vec4` per triangle (Vertices, Normals, Colors, Emission). |
| 3 | Image | `accum_image` | Accumulation buffer. Stores the sum of all samples to remove noise over time. |
| 4 | Storage | `BVHBuffer` | Bounding Volume Hierarchy nodes. 3 `vec4` per node (AABB min, AABB max, child/tri data). |
| 5 | Storage | `TriOrderBuffer` | Reordered triangle indices for better cache coherency during traversal. |
| 6 | Storage | `DynamicBuffer` | Moving objects (boats, barrels). 9 `vec4` per object. |
| 7 | Storage | `LightBuffer` | Point lights (Omni/Spot). 3 `vec4` per light (Position, Color+Range, Direction+Angle). |

## 2. The Ray Generation

In `main()`, the shader calculates the initial ray for each pixel.
- **Perspective Camera:** Uses the camera's FOV and aspect ratio.
- **Orthographic Camera:** Uses the camera's `size` and aspect ratio (used for the isometric view).

## 3. Path Tracing Loop (Bounces)

For every sample, the shader runs a loop up to `MAX_BOUNCES` (currently 5).
1. **Trace Scene:** Calls `trace_scene()`, which tests intersection against the static BVH and the dynamic list.
2. **Evaluate Material:** Extracts Albedo, Roughness, Metallic, and Emission.
3. **Direct Lighting:**
   - Traces a shadow ray towards the Sun/Moon.
   - Loops through the `LightBuffer` and traces shadow rays towards each Omni/Spot light.
4. **Indirect Lighting (Russian Roulette):** 
   - Generates a new ray using a cosine-weighted hemisphere or GGX sampling.
   - Multiplies the `throughput` by the material's BRDF.
5. **Emission:** If the material has an emission color (e.g., lanterns), it is added directly to the result.

## 4. Post-Processing & Accumulation

- **Firefly Clamping:** If a sample color exceeds `FIREFLY_CLAMP` (5.0), it is clamped. This prevents white pixels from ruining the accumulation buffer.
- **Accumulation:** The sample is added to `accum_image`. The final displayed color is `accum_image / sample_count`.
- **Tonemapping:** The image is passed through an **ACES** tonemapper and gamma-corrected (`pow(color, 1/2.2)`) before being sent to `output_image`.

## 5. BVH Traversal

The BVH is built on the CPU with a median-split strategy. The shader traverses it using a stack (`MAX_STACK = 64`). 
- **Internal nodes** store the left/right child indices.
- **Leaf nodes** store the start index and count of triangles in the `TriOrderBuffer`.
- **AABB Test:** Uses the slab method (Ray-AABB intersection) to quickly discard branches.

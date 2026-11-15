#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform image2D output_image;
layout(set = 0, binding = 3, rgba32f) uniform image2D accum_image;

layout(set = 0, binding = 1, std140) uniform Params {
	vec4 camera_position;
	vec4 camera_forward;
	vec4 camera_right;
	vec4 camera_up;
	vec4 resolution_fov;
	vec4 misc;
	vec4 ortho_info;
	vec4 sun_info;
	vec4 sun_color;
	vec4 misc2;            // x=dynamic_count, y=light_count
	vec4 moon_info;
	vec4 moon_color;
	vec4 ambient_info;
} params;

layout(set = 0, binding = 2, std430) readonly buffer TriangleBuffer { vec4 data[]; } tri_buf;
layout(set = 0, binding = 4, std430) readonly buffer BVHBuffer { vec4 data[]; } bvh_buf;
layout(set = 0, binding = 5, std430) readonly buffer TriOrderBuffer { int data[]; } order_buf;
layout(set = 0, binding = 6, std430) readonly buffer DynamicBuffer { vec4 data[]; } dyn_buf;
layout(set = 0, binding = 7, std430) readonly buffer LightBuffer { vec4 data[]; } light_buf;

const int VECS_PER_TRI = 10;
const int BVH_VEC4_PER_NODE = 3;
const int MAX_BOUNCES = 5;
const int MAX_STACK = 64;
const int MAX_DYNAMIC = 32;
const int VEC4_PER_DYNAMIC = 9;
const int MAX_LIGHTS = 16;
const int VEC4_PER_LIGHT = 3;
const float PI = 3.14159265359;
const float FIREFLY_CLAMP = 5.0;

uint pcg(inout uint state) {
	state = state * 747796405u + 2891336453u;
	uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
	return (word >> 22u) ^ word;
}
float rand(inout uint state) { return float(pcg(state) & 0xFFFFFFu) / float(0x1000000u); }

float hash_stars(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3)); p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 sky_color(vec3 dir) {
	float sun_h = params.moon_color.w;
	float day_amount = smoothstep(-0.1, 0.3, sun_h);
	float twilight_amount = 1.0 - smoothstep(0.0, 0.4, abs(sun_h));
	vec3 night_horizon = vec3(0.02, 0.03, 0.08); vec3 night_zenith  = vec3(0.01, 0.01, 0.03);
	vec3 day_horizon   = vec3(0.65, 0.55, 0.45); vec3 day_zenith    = vec3(0.25, 0.42, 0.80);
	vec3 horizon = mix(night_horizon, day_horizon, day_amount);
	vec3 zenith  = mix(night_zenith, day_zenith, day_amount);
	horizon = mix(horizon, vec3(1.0, 0.4, 0.15), twilight_amount * 0.8);
	float t = smoothstep(-0.1, 0.6, dir.y);
	vec3 col = mix(horizon, zenith, t);
	float d_sun = dot(dir, params.sun_info.xyz);
	float sun_core = smoothstep(0.9995, 0.9999, d_sun);
	float sun_glow = pow(max(d_sun, 0.0), 300.0);
	col += (sun_core * 4.0 + sun_glow * 0.3) * params.sun_color.rgb * day_amount;
	float night_amount = 1.0 - day_amount;
	if (night_amount > 0.01) {
		float d_moon = dot(dir, params.moon_info.xyz);
		float moon_core = smoothstep(0.9998, 0.9999, d_moon);
		col += moon_core * params.moon_color.rgb * 3.0 * night_amount;
		vec3 p = dir * 400.0; vec3 ip = floor(p); float s = hash_stars(ip);
		if (s > 0.995) {
			float star = smoothstep(0.995, 1.0, s);
			col += vec3(1.0, 0.95, 0.9) * star * night_amount * 2.0;
		}
	}
	return col;
}

vec3 cosine_hemisphere(vec3 n, inout uint rng) {
	float r1 = rand(rng); float r2 = rand(rng); float phi = 2.0 * PI * r2; float sqrt_r1 = sqrt(r1);
	vec3 t; if (abs(n.x) > 0.5) t = normalize(cross(vec3(0,1,0), n)); else t = normalize(cross(vec3(1,0,0), n));
	vec3 b = cross(n, t); return normalize(t * sqrt_r1 * cos(phi) + b * sqrt_r1 * sin(phi) + n * sqrt(1.0 - r1));
}
vec3 sample_ggx(vec3 n, float roughness, inout uint rng) {
	float a = max(roughness * roughness, 1e-4); float r1 = rand(rng); float r2 = rand(rng);
	float cos_theta = sqrt((1.0 - r1) / (1.0 + (a*a - 1.0) * r1)); float sin_theta = sqrt(max(0.0, 1.0 - cos_theta * cos_theta));
	float phi = 2.0 * PI * r2; vec3 t; if (abs(n.x) > 0.5) t = normalize(cross(vec3(0,1,0), n)); else t = normalize(cross(vec3(1,0,0), n));
	vec3 b = cross(n, t); vec3 local = vec3(sin_theta * cos(phi), sin_theta * sin(phi), cos_theta); return normalize(t * local.x + b * local.y + n * local.z);
}
vec3 fresnel_schlick(float cos_theta, vec3 f0) { return f0 + (1.0 - f0) * pow(clamp(1.0 - cos_theta, 0.0, 1.0), 5.0); }

bool ray_aabb(vec3 orig, vec3 inv_dir, vec3 bmin, vec3 bmax, float t_max, out float t_enter) {
	vec3 t0 = (bmin - orig) * inv_dir; vec3 t1 = (bmax - orig) * inv_dir; vec3 tmin = min(t0, t1); vec3 tmax = max(t0, t1);
	float tnear = max(max(tmin.x, tmin.y), tmin.z); float tfar = min(min(tmax.x, tmax.y), tmax.z);
	if (tfar < max(tnear, 0.0) || tnear >= t_max) return false; t_enter = max(tnear, 0.0); return true;
}

bool ray_triangle_bary(vec3 orig, vec3 dir, vec3 v0, vec3 v1, vec3 v2, out float t, out float u, out float v) {
	vec3 edge1 = v1 - v0; vec3 edge2 = v2 - v0; vec3 pvec = cross(dir, edge2); float det = dot(edge1, pvec);
	if (abs(det) < 1e-8) return false; float inv_det = 1.0 / det; vec3 tvec = orig - v0;
	u = dot(tvec, pvec) * inv_det; if (u < 0.0 || u > 1.0) return false;
	vec3 qvec = cross(tvec, edge1); v = dot(dir, qvec) * inv_det; if (v < 0.0 || u + v > 1.0) return false;
	t = dot(edge2, qvec) * inv_det; return t > 1e-3;
}

bool ray_obb(vec3 orig, vec3 dir, vec3 obj_pos, vec3 r0, vec3 r1, vec3 r2, vec3 bmin, vec3 bmax, out float t_hit, out vec3 n_hit) {
	vec3 d = orig - obj_pos; vec3 local_orig = vec3(dot(r0, d), dot(r1, d), dot(r2, d)); vec3 local_dir  = vec3(dot(r0, dir), dot(r1, dir), dot(r2, dir));
	vec3 safe_dir = local_dir; if (abs(safe_dir.x) < 1e-6) safe_dir.x = 1e-6; if (abs(safe_dir.y) < 1e-6) safe_dir.y = 1e-6; if (abs(safe_dir.z) < 1e-6) safe_dir.z = 1e-6;
	vec3 inv_d = 1.0 / safe_dir; vec3 t0 = (bmin - local_orig) * inv_d; vec3 t1 = (bmax - local_orig) * inv_d;
	vec3 tmin = min(t0, t1); vec3 tmax = max(t0, t1); float t_near = max(max(tmin.x, tmin.y), tmin.z); float t_far  = min(min(tmax.x, tmax.y), tmax.z);
	if (t_far < max(t_near, 0.0)) return false; t_hit = max(t_near, 0.0); vec3 local_n;
	if (tmin.x > tmin.y && tmin.x > tmin.z)      local_n = vec3(sign(local_dir.x), 0.0, 0.0);
	else if (tmin.y > tmin.z)                    local_n = vec3(0.0, sign(local_dir.y), 0.0);
	else                                          local_n = vec3(0.0, 0.0, sign(local_dir.z));
	n_hit = normalize(r0 * local_n.x + r1 * local_n.y + r2 * local_n.z); return true;
}

bool ray_sphere(vec3 orig, vec3 dir, vec3 center, float radius, out float t_hit, out vec3 n_hit) {
	vec3 oc = orig - center; float b = dot(oc, dir); float c = dot(oc, oc) - radius * radius; float disc = b * b - c;
	if (disc < 0.0) return false; float sq = sqrt(disc); float t = -b - sq; if (t < 1e-4) t = -b + sq;
	if (t < 1e-4) return false; t_hit = t; n_hit = normalize(orig + dir * t - center); return true;
}

bool trace_bvh(vec3 orig, vec3 dir, out float t_hit, out vec3 n_hit, out vec3 albedo, out float roughness, out float metalness, out vec3 emission) {
	t_hit = 1e30; n_hit = vec3(0.0); albedo = vec3(0.0); roughness = 1.0; metalness = 0.0; emission = vec3(0.0); bool hit = false;
	vec3 safe_dir = dir; if (abs(safe_dir.x) < 1e-6) safe_dir.x = 1e-6; if (abs(safe_dir.y) < 1e-6) safe_dir.y = 1e-6; if (abs(safe_dir.z) < 1e-6) safe_dir.z = 1e-6;
	vec3 inv_dir = 1.0 / safe_dir; int stack[MAX_STACK]; int sp = 0; stack[sp++] = 0;
	while (sp > 0) {
		int node_idx = stack[--sp]; int base = node_idx * BVH_VEC4_PER_NODE; vec4 n0 = bvh_buf.data[base + 0]; vec4 n1 = bvh_buf.data[base + 1]; vec4 n2 = bvh_buf.data[base + 2];
		float t_aabb; if (!ray_aabb(orig, inv_dir, n0.xyz, n1.xyz, t_hit, t_aabb)) continue;
		if (n1.w > 0.5) {
			int tri_count = int(n0.w); int tri_start = int(n2.z);
			for (int i = 0; i < tri_count; i++) {
				int real_idx = order_buf.data[tri_start + i]; int tb = real_idx * VECS_PER_TRI;
				vec3 v0 = tri_buf.data[tb + 0].xyz; vec3 v1 = tri_buf.data[tb + 1].xyz; vec3 v2 = tri_buf.data[tb + 2].xyz;
				float t, u, v; if (ray_triangle_bary(orig, dir, v0, v1, v2, t, u, v)) {
					if (t < t_hit) {
						t_hit = t; vec3 nv0 = tri_buf.data[tb + 3].xyz; vec3 nv1 = tri_buf.data[tb + 4].xyz; vec3 nv2 = tri_buf.data[tb + 5].xyz;
						vec3 cv0 = tri_buf.data[tb + 6].rgb; vec3 cv1 = tri_buf.data[tb + 7].rgb; vec3 cv2 = tri_buf.data[tb + 8].rgb; vec3 em = tri_buf.data[tb + 9].rgb;
						float w0 = 1.0 - u - v; vec3 interp_n = w0 * nv0 + u * nv1 + v * nv2; if (length(interp_n) < 0.1) interp_n = cross(v1 - v0, v2 - v0);
						n_hit = normalize(interp_n); albedo = w0 * cv0 + u * cv1 + v * cv2; emission = em;
						roughness = tri_buf.data[tb + 6].w; metalness = tri_buf.data[tb + 7].w; hit = true;
					}
				}
			}
		} else {
			int left = int(n2.x); int right = int(n2.y); if (sp < MAX_STACK - 2) { stack[sp++] = left; stack[sp++] = right; }
		}
	}
	return hit;
}

bool trace_dynamic(vec3 orig, vec3 dir, float t_current, out float t_hit, out vec3 n_hit, out vec3 albedo, out float roughness, out float metalness, out vec3 emission) {
	t_hit = t_current; n_hit = vec3(0.0); albedo = vec3(0.0); roughness = 1.0; metalness = 0.0; emission = vec3(0.0); bool hit = false;
	int dyn_count = int(params.misc2.x);
	for (int i = 0; i < MAX_DYNAMIC; i++) {
		if (i >= dyn_count) break; int b = i * VEC4_PER_DYNAMIC;
		vec4 pos_shape = dyn_buf.data[b + 0]; vec4 r0v = dyn_buf.data[b + 1]; vec4 r1v = dyn_buf.data[b + 2]; vec4 r2v = dyn_buf.data[b + 3];
		vec4 bmin = dyn_buf.data[b + 4]; vec4 bmax = dyn_buf.data[b + 5]; vec4 alb = dyn_buf.data[b + 6]; vec4 em = dyn_buf.data[b + 7];
		float t; vec3 nh; bool this_hit = false;
		if (pos_shape.w < 0.5) this_hit = ray_obb(orig, dir, pos_shape.xyz, r0v.xyz, r1v.xyz, r2v.xyz, bmin.xyz, bmax.xyz, t, nh);
		else this_hit = ray_sphere(orig, dir, pos_shape.xyz, r2v.w, t, nh);
		if (this_hit && t < t_hit) { t_hit = t; n_hit = nh; albedo = alb.xyz; roughness = r0v.w; metalness = r1v.w; emission = em.xyz; hit = true; }
	}
	return hit;
}

bool trace_scene(vec3 orig, vec3 dir, out float t_hit, out vec3 n_hit, out vec3 albedo, out float roughness, out float metalness, out vec3 emission) {
	bool hit_bvh = trace_bvh(orig, dir, t_hit, n_hit, albedo, roughness, metalness, emission);
	float t_dyn = 1e30; vec3 n_dyn, a_dyn, em_dyn; float r_dyn, m_dyn;
	bool hit_dyn = trace_dynamic(orig, dir, t_hit, t_dyn, n_dyn, a_dyn, r_dyn, m_dyn, em_dyn);
	if (hit_dyn) { t_hit = t_dyn; n_hit = n_dyn; albedo = a_dyn; roughness = r_dyn; metalness = m_dyn; emission = em_dyn; return true; }
	return hit_bvh;
}

vec3 trace_path(vec3 origin, vec3 dir, inout uint rng) {
	vec3 throughput = vec3(1.0); vec3 result = vec3(0.0);
	float sun_h = params.moon_color.w; float day_amount = smoothstep(-0.05, 0.1, sun_h);
	vec3 light_dir = normalize(mix(params.moon_info.xyz, params.sun_info.xyz, day_amount));
	vec3 light_col = mix(params.moon_color.rgb * params.moon_info.w, params.sun_color.rgb * params.sun_info.w, day_amount);
	int num_lights = int(params.misc2.y);

	for (int bounce = 0; bounce < MAX_BOUNCES; bounce++) {
		float t_hit; vec3 n_hit, albedo, emission; float roughness, metalness;
		if (!trace_scene(origin, dir, t_hit, n_hit, albedo, roughness, metalness, emission)) {
			result += throughput * sky_color(dir); break;
		}

		if (dot(n_hit, dir) > 0.0) n_hit = -n_hit;
		vec3 hit_pos = origin + dir * t_hit;
		float adaptive_offset = clamp(t_hit * 0.001, 0.01, 0.1);
		vec3 offset_origin = hit_pos + n_hit * adaptive_offset;

		// EMISIÓN (si el material brilla, lo sumamos)
		result += throughput * emission;

		vec3 f0 = mix(vec3(0.04), albedo, metalness); vec3 diffuse_albedo = albedo * (1.0 - metalness); float cos_in = max(dot(n_hit, -dir), 0.0);

		// 1. Luz Direccional (Sol/Luna)
		float t_shadow; vec3 n_s, alb_s, em_s; float r_s, m_s;
		if (!trace_scene(offset_origin, light_dir, t_shadow, n_s, alb_s, r_s, m_s, em_s)) {
			float ndotl = max(dot(n_hit, light_dir), 0.0);
			result += throughput * diffuse_albedo * ndotl * light_col;
			if (roughness < 0.9) {
				vec3 V = -dir; vec3 H = normalize(V + light_dir); float ndoth = max(dot(n_hit, H), 0.0);
				float rough4 = max(roughness * roughness * roughness * roughness, 1e-4); float spec_exp = clamp(2.0 / rough4 - 2.0, 2.0, 500.0);
				float spec = pow(ndoth, spec_exp); vec3 F = fresnel_schlick(max(dot(H, V), 0.0), f0);
				result += throughput * F * spec * ndotl * light_col;
			}
		}

		// 2. Luces Puntuales (Omni / Spot)
		for (int i = 0; i < MAX_LIGHTS; i++) {
			if (i >= num_lights) break;
			int b = i * VEC4_PER_LIGHT;
			vec4 pos_type = light_buf.data[b + 0]; vec4 col_range = light_buf.data[b + 1]; vec4 dir_angle = light_buf.data[b + 2];
			
			vec3 L = pos_type.xyz - hit_pos; float dist = length(L);
			if (dist > col_range.w) continue; // Fuera de rango
			L /= dist;
			
			float ndotl = max(dot(n_hit, L), 0.0);
			if (ndotl <= 0.0) continue;
			
			// Atenuación con caída suave al borde del rango
			float atten = 1.0 / (1.0 + dist * dist);
			float range_falloff = clamp(1.0 - (dist * dist) / (col_range.w * col_range.w), 0.0, 1.0);
			atten *= range_falloff * range_falloff;
			
			// Comprobación de cono (Spot)
			if (pos_type.w > 0.5) {
				float spot_cos = dot(-L, dir_angle.xyz);
				if (spot_cos < dir_angle.w) continue;
				atten *= smoothstep(dir_angle.w, dir_angle.w + 0.05, spot_cos);
			}
			
			// Sombra para la luz puntual
			if (!trace_scene(offset_origin, L, t_shadow, n_s, alb_s, r_s, m_s, em_s)) {
				vec3 l_col = col_range.rgb * atten;
				result += throughput * diffuse_albedo * ndotl * l_col;
				// Specular puntual (aproximado)
				vec3 V = -dir; vec3 H = normalize(V + L); float ndoth = max(dot(n_hit, H), 0.0);
				float rough4 = max(roughness * roughness * roughness * roughness, 1e-4); float spec_exp = clamp(2.0 / rough4 - 2.0, 2.0, 500.0);
				float spec = pow(ndoth, spec_exp); vec3 F = fresnel_schlick(max(dot(H, V), 0.0), f0);
				result += throughput * F * spec * ndotl * l_col;
			}
		}

		vec3 ambient_sky = mix(vec3(0.02, 0.02, 0.05), vec3(0.4, 0.5, 0.7), day_amount);
		result += throughput * diffuse_albedo * ambient_sky * params.ambient_info.x * 0.05;

		vec3 F_in = fresnel_schlick(cos_in, f0); float spec_prob = clamp(dot(F_in, vec3(0.3333)) + metalness * 0.5, 0.05, 0.95);
		if (rand(rng) < spec_prob) {
			vec3 refl = reflect(dir, n_hit); vec3 new_dir = sample_ggx(refl, roughness, rng);
			if (dot(new_dir, n_hit) < 0.0) break; dir = new_dir; throughput *= F_in / spec_prob;
		} else {
			dir = cosine_hemisphere(n_hit, rng); throughput *= diffuse_albedo / (1.0 - spec_prob);
		}
		origin = offset_origin;

		if (bounce >= 2) {
			float p = clamp(max(throughput.r, max(throughput.g, throughput.b)), 0.1, 1.0);
			if (rand(rng) > p) break; throughput /= p;
		}
	}
	return result;
}

vec3 aces_tonemap(vec3 x) { const float a = 2.51; const float b = 0.03; const float c = 2.43; const float d = 0.59; const float e = 0.14; return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0); }

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy); ivec2 size = imageSize(output_image);
	if (pixel.x >= size.x || pixel.y >= size.y) return;
	int N = int(params.misc.x); bool reset = params.misc.y > 0.5; int samples_this_frame = int(params.misc.z); bool is_ortho = params.misc.w > 0.5;
	if (reset) N = 0; int new_count = N + samples_this_frame;
	uint rng = uint(pixel.x) * 1973u + uint(pixel.y) * 9277u + uint(N) * 26699u + 0x9E3779B9u; pcg(rng);
	vec3 accum_sum = vec3(0.0); float aspect = float(size.x) / float(size.y);

	for (int s = 0; s < samples_this_frame; s++) {
		vec2 jitter = vec2(rand(rng), rand(rng)); float px = float(pixel.x) + jitter.x; float py = float(pixel.y) + jitter.y;
		vec2 ndc; ndc.x = px / float(size.x) * 2.0 - 1.0; ndc.y = 1.0 - py / float(size.y) * 2.0;
		vec3 ray_origin; vec3 ray_dir;
		if (is_ortho) {
			float half_h = params.ortho_info.x; float half_w = params.ortho_info.y;
			ray_origin = params.camera_position.xyz + ndc.x * half_w * params.camera_right.xyz + ndc.y * half_h * params.camera_up.xyz;
			ray_dir = normalize(params.camera_forward.xyz);
		} else {
			ray_origin = params.camera_position.xyz; float tan_half_fov = params.resolution_fov.z;
			ray_dir = normalize(params.camera_forward.xyz + ndc.x * aspect * tan_half_fov * params.camera_right.xyz + ndc.y * tan_half_fov * params.camera_up.xyz);
		}
		vec3 sample_col = trace_path(ray_origin, ray_dir, rng);
		sample_col = min(sample_col, vec3(FIREFLY_CLAMP)); accum_sum += sample_col;
	}

	vec3 existing = reset ? vec3(0.0) : imageLoad(accum_image, pixel).rgb;
	vec3 new_acc = existing + accum_sum; imageStore(accum_image, pixel, vec4(new_acc, 1.0));
	vec3 display = new_acc / float(new_count); display *= params.sun_color.w; display = aces_tonemap(display); display = pow(display, vec3(1.0 / 2.2));
	imageStore(output_image, pixel, vec4(display, 1.0));
}
# waves.gd
extends Node
# AUTOLOAD "Waves": fuente única de verdad del oleaje

# Cada ola: dir (dirección XZ), amplitude, frequency (k), speed (ω), phase (φ)
# h = Σ amplitude * sin( frequency * dir·pos - speed * t + phase )
var waves: Array = [
	{"dir": Vector2(1.0, 0.0),  "amplitude": 0.15, "frequency": 0.5, "speed": 1.0, "phase": 0.0},
	{"dir": Vector2(0.7, 0.7),  "amplitude": 0.10, "frequency": 0.9, "speed": 1.4, "phase": 1.3},
	{"dir": Vector2(-0.4, 0.9), "amplitude": 0.06, "frequency": 1.6, "speed": 2.0, "phase": 2.1},
]

var current_time: float = 0.0
var water_level: float = 0.0   # la escribe water.gd en _ready

func _process(delta: float) -> void:
	current_time += delta

func height_at(x: float, z: float) -> float:
	var h := 0.0
	var pos := Vector2(x, z)
	for w in waves:
		var k: float = w.frequency
		var phase: float = k * w.dir.dot(pos) - current_time * w.speed + w.phase
		h += w.amplitude * sin(phase)
	return h

func surface_y_at(x: float, z: float) -> float:
	return water_level + height_at(x, z)

# Empuja la config al shader (una vez al arrancar)
func apply_to_shader(mat: ShaderMaterial) -> void:
	for i in range(min(3, waves.size())):
		var w = waves[i]
		mat.set_shader_parameter("wave_dirs_%d" % i,
			Vector4(w.dir.x, w.dir.y, w.amplitude, w.frequency))
		mat.set_shader_parameter("wave_speed_%d" % i, w.speed)
		mat.set_shader_parameter("wave_phase_%d" % i, w.phase)
	mat.set_shader_parameter("world_time", current_time)

# Actualiza solo el tiempo (cada frame desde water.gd)
func update_shader_time(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("world_time", current_time)

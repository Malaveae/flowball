## GrassPatch3D — MultiMesh grass card system for the pitch
##
## Populates a MultiMeshInstance3D with billboarded grass blade quads.
## Uses a ShaderMaterial with the grass_card shader for billboarding,
## alpha scissor, wind animation, and normal-mapped blade volume.
##
## Intended as a visual layer on top of the existing pitch BoxMesh.
@tool
class_name GrassPatch3D
extends MultiMeshInstance3D

# --- Textures ---
@export var blade_texture: Texture2D
@export var blade_normal_texture: Texture2D
@export var wind_noise_texture: Texture2D

# --- Coverage ---
@export var area_center := Vector3(0.0, 0.0, 0.0)
@export var area_size := Vector2(24.0, 32.0)       # metres along X and Z
@export var density := 196.0                     # blades per m²
@export var max_instances := 100000                  # safety cap

# --- Blade dimensions (each quad) ---
@export var blade_width := 0.008
@export var blade_height := 0.018

# --- Exclusion zones (area where grass shouldn't grow) ---
@export var exclusion_radius := 0.5                # around ball/player

# --- Determinism ---
@export var placement_seed := 1337                 # fixed seed: identical layout every run

# --- Shader parameters (forwarded to the material) ---
@export var wind_direction := Vector2(0.6, 0.8)
@export var wind_speed := 0.2
@export var wind_strength := 0.04
@export var wind_noise_scale := 12.0
@export var gust_strength := 0.1
@export var gust_speed := 0.4
@export var flutter_strength := 0.02
@export var flutter_frequency := 5.5
@export var perspective_factor := 0.0
@export var perspective_max_dist := 55.0
@export var animation_fps := 0.0
@export var interaction_radius := 1.2
@export var interaction_strength := 0.95
@export var alpha_cutoff := 0.35
@export var brightness_variation := 0.14
@export var patch_noise_scale := 8.0
@export var patch_noise_strength := 0.18
@export var accent_probability := 0.16
@export var translucency_gain := 0.4
@export var blade_forward := 0.3

var _shader_loaded := false
var _actor_positions: Array[Vector3] = []


func _ready():
	_populate()


func _populate():
	if not blade_texture or not blade_normal_texture:
		push_error("GrassPatch3D: blade_texture and blade_normal_texture are required")
		return

	# --- Base mesh: a single quad (centered, shifted in shader) ---
	var quad := QuadMesh.new()
	quad.size = Vector2(blade_width, blade_height)

	# --- Instance count ---
	var area := area_size.x * area_size.y
	var count := mini(int(area * density), max_instances)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = count
	mm.visible_instance_count = count

	# --- Populate instances (seeded RNG for deterministic layout) ---
	var rng := RandomNumberGenerator.new()
	rng.seed = placement_seed + int(area_center.x * 7.0 + area_center.z * 13.0)
	var half_x := area_size.x * 0.5
	var half_z := area_size.y * 0.5

	for i in count:
		var x := rng.randf_range(-half_x, half_x) + area_center.x
		var z := rng.randf_range(-half_z, half_z) + area_center.z

		# Exclusion zone: skip if too close to center (ball/player area)
		var dx := x - area_center.x
		var dz := z - area_center.z
		if sqrt(dx * dx + dz * dz) < exclusion_radius:
			# Place it anyway but pushed out — simpler than sparse array
			var angle := rng.randf_range(0.0, TAU)
			x = area_center.x + cos(angle) * exclusion_radius * 1.2
			z = area_center.z + sin(angle) * exclusion_radius * 1.2

		var t := Transform3D()
		# Offset Y: blade center at ground + half height + padding above pitch surface
		t.origin = Vector3(x, blade_height * 0.5 + 0.03, z)

		mm.set_instance_transform(i, t)

		# (No custom data needed — shader seeds per-blade randomness
		# from a hash of the blade's world position.)

	multimesh = mm

	# --- Material ---
	var shader_path := "res://assets/shaders/grass_card.gdshader"
	var shader_res := load(shader_path) as Shader
	if not shader_res:
		push_error("GrassPatch3D: could not load shader: ", shader_path)
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader_res
	mat.set_shader_parameter("blade_tex", blade_texture)
	mat.set_shader_parameter("blade_normal_tex", blade_normal_texture)
	mat.set_shader_parameter("wind_noise_tex", wind_noise_texture)
	mat.set_shader_parameter("wind_direction", wind_direction)
	mat.set_shader_parameter("wind_speed", wind_speed)
	mat.set_shader_parameter("wind_strength", wind_strength)
	mat.set_shader_parameter("wind_noise_scale", wind_noise_scale)
	mat.set_shader_parameter("gust_strength", gust_strength)
	mat.set_shader_parameter("gust_speed", gust_speed)
	mat.set_shader_parameter("flutter_strength", flutter_strength)
	mat.set_shader_parameter("flutter_frequency", flutter_frequency)
	mat.set_shader_parameter("alpha_cutoff", alpha_cutoff)
	mat.set_shader_parameter("brightness_variation", brightness_variation)
	mat.set_shader_parameter("patch_noise_scale", patch_noise_scale)
	mat.set_shader_parameter("patch_noise_strength", patch_noise_strength)
	mat.set_shader_parameter("accent_probability", accent_probability)
	mat.set_shader_parameter("translucency_gain", translucency_gain)
	mat.set_shader_parameter("blade_forward", blade_forward)
	mat.set_shader_parameter("perspective_factor", perspective_factor)
	mat.set_shader_parameter("perspective_max_dist", perspective_max_dist)
	mat.set_shader_parameter("animation_fps", animation_fps)
	mat.set_shader_parameter("interaction_radius", interaction_radius)
	mat.set_shader_parameter("interaction_strength", interaction_strength)
	mat.set_shader_parameter("actor_count", 0)
	for i in range(4):
		mat.set_shader_parameter("actor_positions[%d]" % i, Vector3.ZERO)

	material_override = mat
	_shader_loaded = true
	if not Engine.is_editor_hint():
		set_process(true)


func set_wind(strength: float, speed: float) -> void:
	if not _shader_loaded:
		return
	var mat := material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("wind_strength", strength)
		mat.set_shader_parameter("wind_speed", speed)

func set_gust(strength: float, speed: float) -> void:
	if not _shader_loaded:
		return
	var mat := material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("gust_strength", strength)
		mat.set_shader_parameter("gust_speed", speed)

## Update actor positions that push grass aside.
## Accepts up to 4 Vector3 world-space positions (player, ball, etc.).
func set_actor_positions(positions: Array[Vector3]) -> void:
	_actor_positions = positions.duplicate()

func _process(_delta: float) -> void:
	if not _shader_loaded:
		return
	var mat := material_override as ShaderMaterial
	if mat == null:
		return
	var count := mini(_actor_positions.size(), 4)
	mat.set_shader_parameter("actor_count", count)
	for i in range(count):
		mat.set_shader_parameter("actor_positions[%d]" % i, _actor_positions[i])
	# Zero out unused slots
	for i in range(count, 4):
		mat.set_shader_parameter("actor_positions[%d]" % i, Vector3.ZERO)

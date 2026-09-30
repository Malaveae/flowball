class_name CRTEffect
extends CanvasLayer

enum Preset { OFF, SUBTLE, FULL }

## Current CRT preset.
@export var preset: Preset = Preset.SUBTLE

## Whether the CRT layer is active.
@export var enabled: bool = true

@onready var color_rect: ColorRect
@onready var shader_material: ShaderMaterial

signal preset_changed(p: Preset)

func _ready() -> void:
	visible = enabled

	# Reuse existing ColorRect if present, otherwise create one.
	if not has_node("PostProcessRect"):
		color_rect = ColorRect.new()
		color_rect.name = "PostProcessRect"
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.offset_left = 0
		color_rect.offset_top = 0
		color_rect.offset_right = 0
		color_rect.offset_bottom = 0
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(color_rect)
	else:
		color_rect = get_node("PostProcessRect") as ColorRect

	# Assign or reuse ShaderMaterial.
	if color_rect.material == null:
		var shader := load("res://assets/shaders/crt_post_process.gdshader") as Shader
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader
		color_rect.material = shader_material
	else:
		shader_material = color_rect.material as ShaderMaterial

	apply_preset(preset)

## Apply a preset to the CRT intensity uniform.
func apply_preset(p: Preset) -> void:
	preset = p
	var new_intensity := 0.0
	match p:
		Preset.OFF:
			new_intensity = 0.0
		Preset.SUBTLE:
			new_intensity = 0.35
		Preset.FULL:
			new_intensity = 0.85

	if is_instance_valid(shader_material):
		shader_material.set_shader_parameter("intensity", new_intensity)

	preset_changed.emit(p)

## Toggle visibility and effect.
func set_enabled(e: bool) -> void:
	enabled = e
	visible = e

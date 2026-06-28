class_name GoalkeeperController
extends CharacterBody3D

const DEFAULT_READY_ANIMATION := &"gk_ready"
const GOAL_CENTER := Vector3(0.0, 1.2, -52.5)
const LEFT_ZONE_X := -1.0
const RIGHT_ZONE_X := 1.0
const HIGH_ZONE_Y := 1.8

@export var reaction_delay_seconds: float = 0.45
@export var dive_offset_meters: float = 1.25
@export var dive_up_offset_meters: float = 0.65
@export var recover_seconds: float = 0.45
@export var idle_breath_height: float = 0.035
@export var idle_sway_degrees: float = 1.5
@export var idle_cycle_seconds: float = 1.35
@export var animation_player_path: NodePath = NodePath("Model/ImportedGoalkeeper/AnimationPlayer")
@export var fallback_animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var model_path: NodePath = NodePath("Model")
@export var skeleton_path: NodePath = NodePath("Model/ImportedGoalkeeper/GoalkeeperArmature/Skeleton3D")

var home_position: Vector3
var current_zone: StringName = &"center"
var _model_home_position := Vector3.ZERO
var _model_home_rotation := Vector3.ZERO
var _reaction_token := 0
var _idle_active := false
var _idle_time := 0.0
var _motion_tween: Tween
var _idle_tween: Tween

@onready var animation_player: AnimationPlayer = _resolve_animation_player()
@onready var model: Node3D = get_node_or_null(model_path) as Node3D
@onready var skeleton: Skeleton3D = get_node_or_null(skeleton_path) as Skeleton3D

func _ready() -> void:
	if animation_player == null:
		push_warning("GoalkeeperController could not find an AnimationPlayer; goalkeeper animations will be visual-only movement.")
	home_position = global_position
	if model != null:
		_model_home_position = model.position
		_model_home_rotation = model.rotation
	_register_placeholder_animations()
	_configure_animation_playback()
	reset_for_free_kick()

func _process(delta: float) -> void:
	if _idle_active:
		_update_idle_pose(delta)

func reset_for_free_kick() -> void:
	_reaction_token += 1
	_stop_motion_tween()
	_stop_idle_tween()
	global_position = home_position
	rotation = Vector3.ZERO
	if model != null:
		model.position = _model_home_position
		model.rotation = _model_home_rotation
	current_zone = &"center"
	_play_animation(&"gk_idle")
	_start_idle_motion()

func set_ready() -> void:
	_play_animation(DEFAULT_READY_ANIMATION)
	_start_idle_motion()

func react_to_shot(_shot_params: ShotParams, predicted_target: Vector3) -> void:
	_reaction_token += 1
	var token := _reaction_token
	var zone := classify_target(predicted_target)
	current_zone = zone
	_stop_idle_tween()
	_idle_active = false
	_reset_skeleton_pose()
	_play_animation(&"gk_anticipation")
	await get_tree().create_timer(reaction_delay_seconds).timeout
	if token != _reaction_token or not is_inside_tree():
		return
	play_save_animation(zone)

func play_save_animation(save_zone: StringName) -> void:
	var animation_name := _animation_for_zone(save_zone)
	_play_animation(animation_name)
	_move_placeholder_for_zone(save_zone)

func play_goal_conceded_reaction() -> void:
	_reaction_token += 1
	_stop_motion_tween()
	_play_animation(&"gk_concede")

func classify_target(predicted_target: Vector3) -> StringName:
	if predicted_target.y >= HIGH_ZONE_Y:
		return &"up"
	if predicted_target.x <= LEFT_ZONE_X:
		return &"left"
	if predicted_target.x >= RIGHT_ZONE_X:
		return &"right"
	return &"center"

func _animation_for_zone(save_zone: StringName) -> StringName:
	match save_zone:
		&"left":
			return &"gk_dive_left"
		&"right":
			return &"gk_dive_right"
		&"up":
			return &"gk_dive_up"
		_:
			return &"gk_ready"

func _move_placeholder_for_zone(save_zone: StringName) -> void:
	_stop_motion_tween()
	_stop_idle_tween()
	var offset := Vector3.ZERO
	var tilt_z := 0.0
	match save_zone:
		&"left":
			offset = Vector3(-dive_offset_meters, 0.15, 0.0)
			tilt_z = deg_to_rad(62.0)
		&"right":
			offset = Vector3(dive_offset_meters, 0.15, 0.0)
			tilt_z = deg_to_rad(-62.0)
		&"up":
			offset = Vector3(0.0, dive_up_offset_meters, 0.0)
		_:
			offset = Vector3.ZERO
			tilt_z = 0.0

	_motion_tween = create_tween()
	_motion_tween.set_trans(Tween.TRANS_QUAD)
	_motion_tween.set_ease(Tween.EASE_OUT)
	_motion_tween.tween_property(self, "global_position", home_position + offset, 0.22)
	_motion_tween.parallel().tween_property(self, "rotation:z", tilt_z, 0.22)
	_motion_tween.tween_interval(0.22)
	_motion_tween.tween_property(self, "global_position", home_position, recover_seconds)
	_motion_tween.parallel().tween_property(self, "rotation:z", 0.0, recover_seconds)
	_motion_tween.tween_callback(set_ready)

func _update_idle_pose(delta: float) -> void:
	if skeleton == null:
		return
	_idle_time += delta
	var phase := sin(_idle_time * TAU / idle_cycle_seconds)
	var breathe := deg_to_rad(4.0 * phase)
	var arm_sway := deg_to_rad(14.0 + 6.0 * phase)
	var knee_bend := deg_to_rad(-22.0 - 8.0 * phase)
	_set_bone_rotation("spine", Vector3(breathe, 0.0, deg_to_rad(0.8 * phase)))
	_set_bone_rotation("chest", Vector3(breathe * 0.6, 0.0, deg_to_rad(0.6 * phase)))
	_set_bone_rotation("upper_arm.L", Vector3(deg_to_rad(18.0 + 4.0 * phase), 0.0, -arm_sway))
	_set_bone_rotation("upper_arm.R", Vector3(deg_to_rad(18.0 + 4.0 * phase), 0.0, arm_sway))
	_set_bone_rotation("forearm.L", Vector3(deg_to_rad(18.0 + 3.0 * phase), 0.0, deg_to_rad(-10.0)))
	_set_bone_rotation("forearm.R", Vector3(deg_to_rad(18.0 + 3.0 * phase), 0.0, deg_to_rad(10.0)))
	_set_bone_rotation("thigh.L", Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(-2.5 * phase)))
	_set_bone_rotation("thigh.R", Vector3(deg_to_rad(12.0), 0.0, deg_to_rad(2.5 * phase)))
	_set_bone_rotation("shin.L", Vector3(knee_bend, 0.0, 0.0))
	_set_bone_rotation("shin.R", Vector3(knee_bend, 0.0, 0.0))

func _set_bone_rotation(bone_name: String, euler: Vector3) -> void:
	var index := skeleton.find_bone(bone_name)
	if index < 0:
		return
	var pose := skeleton.get_bone_pose(index)
	pose.basis = Basis.from_euler(euler)
	skeleton.set_bone_pose(index, pose)

func _reset_skeleton_pose() -> void:
	if skeleton == null:
		return
	for i in range(skeleton.get_bone_count()):
		skeleton.reset_bone_pose(i)

func _play_animation(animation_name: StringName) -> void:
	if animation_player == null:
		return
	if animation_player.has_animation(animation_name):
		animation_player.play(animation_name)

func _resolve_animation_player() -> AnimationPlayer:
	var imported_player := get_node_or_null(animation_player_path) as AnimationPlayer
	if imported_player != null:
		return imported_player
	return get_node_or_null(fallback_animation_player_path) as AnimationPlayer

func _stop_motion_tween() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null

func _start_idle_motion() -> void:
	_idle_active = true
	if skeleton != null:
		return
	if model == null:
		return
	_stop_idle_tween()
	model.position = _model_home_position
	model.rotation = _model_home_rotation
	_idle_tween = create_tween()
	_idle_tween.set_loops()
	_idle_tween.set_trans(Tween.TRANS_SINE)
	_idle_tween.set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(model, "position:y", _model_home_position.y + idle_breath_height, idle_cycle_seconds * 0.5)
	_idle_tween.parallel().tween_property(model, "rotation:z", _model_home_rotation.z + deg_to_rad(idle_sway_degrees), idle_cycle_seconds * 0.5)
	_idle_tween.tween_property(model, "position:y", _model_home_position.y, idle_cycle_seconds * 0.5)
	_idle_tween.parallel().tween_property(model, "rotation:z", _model_home_rotation.z - deg_to_rad(idle_sway_degrees), idle_cycle_seconds * 0.5)

func _stop_idle_tween() -> void:
	_idle_active = false
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null

func _configure_animation_playback() -> void:
	if animation_player == null:
		return
	if animation_player.has_animation(&"gk_idle"):
		var idle_animation := animation_player.get_animation(&"gk_idle")
		idle_animation.loop_mode = Animation.LOOP_LINEAR
	if animation_player.has_animation(&"gk_ready"):
		var ready_animation := animation_player.get_animation(&"gk_ready")
		ready_animation.loop_mode = Animation.LOOP_LINEAR

func _register_placeholder_animations() -> void:
	if animation_player == null:
		return
	for animation_name in [
		&"gk_idle",
		&"gk_ready",
		&"gk_anticipation",
		&"gk_dive_left",
		&"gk_dive_right",
		&"gk_dive_up",
		&"gk_land",
		&"gk_recover",
		&"gk_concede",
	]:
		if not animation_player.has_animation(animation_name):
			var library := animation_player.get_animation_library("")
			if library == null:
				library = AnimationLibrary.new()
				animation_player.add_animation_library("", library)
			var animation := Animation.new()
			animation.length = 0.5
			library.add_animation(animation_name, animation)

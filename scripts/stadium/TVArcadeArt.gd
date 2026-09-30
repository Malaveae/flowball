class_name TVArcadeArt
extends Node3D

## Visual-only adapter. Existing physics bodies and gameplay cameras remain in place.
const KIT := "res://assets/models/tv_arcade/"
const CEL := preload("res://assets/shaders/tv_arcade_cel.gdshader")
const OUTLINE := preload("res://assets/shaders/tv_arcade_outline.gdshader")
var _materials: Dictionary = {}
var _bowl_layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/preparation/layout.json"))

func bowl_point(angle: float, depth: float, height: float) -> Vector3:
	var power := float(_bowl_layout["power"])
	var radius := pow(
		pow(absf(sin(angle) / (float(_bowl_layout["half_width"]) + depth)), power)
		+ pow(absf(cos(angle) / (float(_bowl_layout["half_length"]) + depth)), power), -1.0 / power)
	return Vector3(radius * sin(angle), height, -radius * cos(angle))

func install(sandbox: Node3D) -> void:
	# Subpixel net strands and stadium diagonals need spatial anti-aliasing.
	get_viewport().msaa_3d = Viewport.MSAA_4X
	for path in ["TestPitch/PitchMesh", "Goal", "GoalNetVisual", "TribunaBackground/Mesh", "LeftLateralBackground/Mesh", "RightLateralBackground/Mesh", "GoalBackgroundFloor/Mesh", "PitchSurround/LeftMesh", "PitchSurround/RightMesh", "Player3D/MeshInstance3D", "StadiumLighting", "StadiumScoreboard", "StadiumBanners"]:
		var old := sandbox.get_node_or_null(path) as Node3D
		if old != null:
			old.hide()
			old.process_mode = Node.PROCESS_MODE_DISABLED
			for viewport in old.find_children("*", "SubViewport", true, false):
				(viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	for i in range(14):
		var grass := sandbox.get_node_or_null("GrassPatch%d" % i) as Node3D
		if grass != null:
			grass.hide()
			grass.process_mode = Node.PROCESS_MODE_DISABLED
	var post := sandbox.get_node_or_null("PostProcessLayer")
	if post is CanvasLayer:
		post.hide()
		post.process_mode = Node.PROCESS_MODE_DISABLED
	var stadium := _preparation_asset("stadium")
	add_child(stadium)
	var goal := instantiate_asset("goal")
	add_child(goal)
	goal.position.z = -52.5
	var ball := sandbox.get_node("Ball3D")
	# Remove only the superseded visual: reset_for_free_kick makes children visible.
	var previous := ball.get_node_or_null("SoccerBallVisual")
	if previous != null:
		ball.remove_child(previous)
		previous.queue_free()
	ball.add_child(_preparation_asset("ball"))
	var keeper := sandbox.get_node("Goalkeeper/Model/ImportedGoalkeeper")
	apply_materials(keeper, true)
	for child in keeper.find_children("*", "MeshInstance3D", true, false):
		for surface in range(child.mesh.get_surface_count()):
			var source: Material = child.mesh.surface_get_material(surface)
			if source != null and source.resource_name == "Orange":
				var jersey := (child.get_surface_override_material(surface) as ShaderMaterial).duplicate() as ShaderMaterial
				jersey.set_shader_parameter("base_color", Color("ffcc18"))
				child.set_surface_override_material(surface, jersey)
	for dummy in sandbox.wall_root.get_children():
		for child in dummy.get_children():
			if child is MeshInstance3D:
				child.hide()
		var player := instantiate_asset("wall_player", true)
		player.name = "ArcadeWallPlayer"
		player.position.y = -0.9
		dummy.add_child(player)
	var world := sandbox.get_node("WorldEnvironment") as WorldEnvironment
	world.environment = world.environment.duplicate()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("102349")
	sky_material.sky_horizon_color = Color("07142c")
	sky_material.ground_horizon_color = Color("07142c")
	sky_material.ground_bottom_color = Color("193f2e")
	sky.sky_material = sky_material
	world.environment.sky = sky
	world.environment.background_mode = Environment.BG_SKY
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a4b7d9")
	world.environment.ambient_light_energy = 0.65
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world.environment.glow_enabled = false
	world.environment.ssao_enabled = false
	world.environment.fog_enabled = false
	var sun := sandbox.get_node("DirectionalLight3D") as DirectionalLight3D
	sun.rotation_degrees = Vector3(-48, -24, 0)
	sun.light_color = Color("ffe6bd")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.08
	_add_broadcast_ribbons()
	_add_lamp_halos()
	_add_foreground_grass(sandbox)

func _preparation_asset(asset: String) -> Node3D:
	var visual := (load("res://assets/models/preparation/" + asset + ".glb") as PackedScene).instantiate() as Node3D
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if source.resource_name.begins_with("PrepTurf"):
				var grass := ShaderMaterial.new()
				grass.shader = preload("res://assets/shaders/preparation_turf.gdshader")
				# Shader-only textures aren't detected as 3D by the importer. Generate
				# the mip chain explicitly, without changing user import settings.
				var texture_image := preload("res://assets/textures/preparation/turf_albedo.png").get_image()
				if texture_image.is_compressed():
					texture_image.decompress()
				texture_image.generate_mipmaps()
				grass.set_shader_parameter("albedo_texture", ImageTexture.create_from_image(texture_image))
				mesh.set_surface_override_material(surface, grass)
				mesh.position.y += 0.033
				continue
			if source.resource_name.begins_with("PrepCrowd"):
				# Soft silhouettes stay subordinate to the interactive foreground.
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = Color(0.50, 0.58, 0.77)
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif source.resource_name.begins_with("PrepBall"):
				material.roughness = 0.62
				material.metallic_specular = 0.3
			elif source.resource_name == "PrepBlue":
				var led := ShaderMaterial.new()
				led.shader = preload("res://assets/shaders/preparation_led.gdshader")
				mesh.set_surface_override_material(surface, led)
				continue
			elif source.resource_name == "PrepIvory":
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mesh.set_surface_override_material(surface, material)
	return visual

func _add_broadcast_ribbons() -> void:
	for tier in [Vector2(0, 1.15), Vector2(8, 7.35), Vector2(17, 15.05)]:
		for index in range(40):
			var angle := float(index) * TAU / 40.0
			var label := Label3D.new()
			label.text = "✦  FOOTBALL  ✦"
			label.font = HudTheme.DISPLAY_FONT
			label.font_size = 64
			label.pixel_size = 0.009
			label.outline_size = 0
			label.no_depth_test = false
			label.position = bowl_point(angle, tier.x - 0.7, tier.y)
			var tangent := bowl_point(angle + 0.0001, tier.x, 0) - bowl_point(angle - 0.0001, tier.x, 0)
			label.rotation.y = atan2(-tangent.z, tangent.x)
			label.modulate = Color("dff7ff")
			add_child(label)

func _add_lamp_halos() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/preparation_lamp.gdshader")
	for index in range(16):
		var angle := float(index) * TAU / 16.0
		var halo := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(7.0, 5.0)
		halo.mesh = quad
		halo.material_override = material
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.position = bowl_point(angle, 11.5, 20.95)
		add_child(halo)

func _add_foreground_grass(sandbox: Node3D) -> void:
	# One instanced draw provides physical blades in the near field. The patch
	# follows the reset ball; it never owns a collider or modifies the shot.
	var blades := MultiMeshInstance3D.new()
	blades.name = "ForegroundGrass"
	var triangle := SurfaceTool.new()
	triangle.begin(Mesh.PRIMITIVE_TRIANGLES)
	for point in [Vector3(-0.0025, 0, 0), Vector3(0.0025, 0, 0), Vector3(0.007, 0.028, 0.009)]:
		triangle.set_normal(Vector3.UP)
		triangle.add_vertex(point)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = triangle.commit()
	multi.instance_count = 80000
	var random := RandomNumberGenerator.new()
	random.seed = 71139
	for index in range(multi.instance_count):
		var angle := random.randf() * TAU
		var radius := sqrt(random.randf()) * 6.0
		var point := Vector3(cos(angle) * radius, 0.047, sin(angle) * radius)
		var scale_value := random.randf_range(0.55, 1.3) * smoothstep(0.0, 2.0, 6.0 - radius)
		var basis := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * maxf(0.01, scale_value))
		multi.set_instance_transform(index, Transform3D(basis, point))
		multi.set_instance_color(index, Color("26460b").lerp(Color("578218"), random.randf()))
	blades.multimesh = multi
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/preparation_grass_blade.gdshader")
	blades.material_override = material
	blades.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blades)
	var ball := sandbox.get_node("Ball3D") as Node3D
	blades.global_position = Vector3(ball.global_position.x, 0, ball.global_position.z)
	# The visual patch relocates only when a new run-up starts.
	sandbox.controller.camera_rig.mode_changed.connect(func(mode: StringName) -> void:
		if mode == &"POWER_VIEW":
			blades.global_position = Vector3(ball.global_position.x, 0, ball.global_position.z)
	)

func instantiate_asset(asset: String, outlined: bool = false) -> Node3D:
	var scene := load(KIT + asset + ".glb") as PackedScene
	var visual := scene.instantiate() as Node3D
	apply_materials(visual, outlined)
	return visual

func apply_materials(node: Node, outlined: bool = false) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		mesh.material_override = null
		for surface in range(mesh.mesh.get_surface_count()):
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			var color := source.albedo_color if source != null else Color.WHITE
			var key := color.to_html() + str(outlined)
			if not _materials.has(key):
				var resource_path := "res://assets/materials/tv_arcade/%s.tres" % (source.resource_name if source != null else "Ivory")
				var mat: ShaderMaterial
				if ResourceLoader.exists(resource_path):
					mat = load(resource_path).duplicate() as ShaderMaterial
				else:
					mat = ShaderMaterial.new()
					mat.shader = CEL
					mat.set_shader_parameter("base_color", color)
				if outlined:
					var outline := ShaderMaterial.new()
					outline.shader = OUTLINE
					mat.next_pass = outline
				_materials[key] = mat
			mesh.set_surface_override_material(surface, _materials[key])
	for child in node.get_children():
		apply_materials(child, outlined)

func _add_crowd() -> void:
	var sample := instantiate_asset("spectator")
	var source := sample.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var crowd := MultiMeshInstance3D.new()
	crowd.name = "InstancedCrowd"
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = source.mesh
	multi.instance_count = 2400
	crowd.multimesh = multi
	var material := ShaderMaterial.new()
	material.shader = CEL
	material.set_shader_parameter("instance_tint", true)
	crowd.material_override = material
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd)
	var colors := [Color("0068c9"), Color("ff9419"), Color("00ab5d"), Color("9227ce"), Color("f5efe4")]
	for index in range(multi.instance_count):
		var side := index / 600
		var seat := index % 75
		var row := (index % 600) / 75
		var point: Vector3
		var angle := 0.0
		if side < 2:
			point = Vector3(-39.0 + seat * 1.05, 1.0 + row * 0.60, (59.0 + row * 1.1) * (-1 if side == 0 else 1))
			angle = PI if side == 0 else 0.0
		else:
			point = Vector3((39.0 + row * 1.1) * (-1 if side == 2 else 1), 1.0 + row * 0.60, -52.0 + seat * 1.4)
			angle = PI * 0.5 if side == 2 else -PI * 0.5
		multi.set_instance_transform(index, Transform3D(Basis(Vector3.UP, angle), point))
		multi.set_instance_color(index, colors[(index * 7 + row) % colors.size()])
	sample.free()

func _add_banners() -> void:
	for index in range(7):
		var label := Label3D.new()
		label.text = "FLOWBALL  /  FOOTBALL ARCHIVE"
		label.font = HudTheme.DISPLAY_FONT
		label.font_size = 64
		label.pixel_size = 0.014
		label.position = Vector3(-36 + index * 12, 1.1, -57.25)
		label.modulate = Color("f5efe4")
		add_child(label)

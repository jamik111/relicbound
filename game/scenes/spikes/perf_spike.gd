extends Node3D
## Sprint 0 task 0.6: mobile performance spike (Gate A).
## A 32x24 tile room drawn with MultiMesh, 8 flickering torch lights, a tilted ortho camera,
## 20 Jolt debris bodies that keep respawning, and 10 billboard pixel sprites.
## After SAMPLE_SECONDS it prints avg fps / 1% low / draw calls (visible in `adb logcat -s godot`).
## Throwaway spike code: not a template for the real LevelView.

const ROOM_W: int = 32
const ROOM_H: int = 24
const TORCH_COUNT: int = 8
const DEBRIS_COUNT: int = 20
const SPRITE_COUNT: int = 10
const WARMUP_SECONDS: float = 3.0
const SAMPLE_SECONDS: float = 30.0
## Placeholder until the pixelfx sheets are baked (task 0.9). Matches the art pipeline's 1/48 tile per VFX pixel.
const VFX_PIXEL_SIZE: float = 1.0 / 48.0
const SPRITE_FRAMES: int = 8
const SPRITE_FRAME_PX: int = 32

var _rng := RandomNumberGenerator.new()
var _torches: Array[OmniLight3D] = []
var _debris: Array[RigidBody3D] = []
var _stats: Label
var _elapsed: float = 0.0
var _frame_times: PackedFloat32Array = PackedFloat32Array()
var _reported: bool = false


func _ready() -> void:
	_rng.seed = 1936
	_build_environment()
	_build_room()
	_build_torches()
	_build_debris()
	_build_sprites()
	_build_camera()
	_build_overlay()


func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = _elapsed
	for i: int in _torches.size():
		_torches[i].light_energy = 1.6 + 0.35 * sin(t * 9.0 + i * 1.7) + 0.15 * sin(t * 23.0 + i)
	for body: RigidBody3D in _debris:
		if body.position.y < -2.0 or body.sleeping:
			_respawn_debris(body)
	if _elapsed > WARMUP_SECONDS and not _reported:
		_frame_times.append(delta)
		if _elapsed > WARMUP_SECONDS + SAMPLE_SECONDS:
			_report()
	_update_overlay()


# --- Construction -------------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.22, 0.2)
	env.ambient_light_energy = 0.4
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_room() -> void:
	var floor_xforms: Array[Transform3D] = []
	var wall_xforms: Array[Transform3D] = []
	for y: int in ROOM_H:
		for x: int in ROOM_W:
			var edge: bool = x == 0 or y == 0 or x == ROOM_W - 1 or y == ROOM_H - 1
			var pillar: bool = x % 6 == 3 and y % 5 == 2
			if edge or pillar:
				wall_xforms.append(Transform3D(Basis(), Vector3(x, 0.5, y)))
			else:
				floor_xforms.append(Transform3D(Basis(), Vector3(x, -0.05, y)))
	_add_multimesh(_box(Vector3(1.0, 0.1, 1.0)), Color(0.55, 0.5, 0.42), floor_xforms)
	_add_multimesh(_box(Vector3(1.0, 1.0, 1.0)), Color(0.42, 0.45, 0.38), wall_xforms)

	# Static ground collider for the debris (one box, not per tile).
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ROOM_W, 0.1, ROOM_H)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(ROOM_W / 2.0 - 0.5, -0.05, ROOM_H / 2.0 - 0.5)
	add_child(ground)


func _add_multimesh(mesh: Mesh, color: Color, xforms: Array[Transform3D]) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _box(size: Vector3) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	return arr_mesh


func _build_torches() -> void:
	for i: int in TORCH_COUNT:
		var light := OmniLight3D.new()
		var col: int = i % 4
		var row: int = i / 4
		light.position = Vector3(4.0 + col * 8.0, 1.6, 6.0 + row * 12.0)
		light.light_color = Color(1.0, 0.65, 0.35)
		light.omni_range = 7.0
		light.shadow_enabled = false
		add_child(light)
		_torches.append(light)


func _build_debris() -> void:
	var mesh := _box(Vector3(0.25, 0.25, 0.25))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.42, 0.34)
	mesh.surface_set_material(0, mat)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.25, 0.25, 0.25)
	for i: int in DEBRIS_COUNT:
		var body := RigidBody3D.new()
		body.can_sleep = true
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(mi)
		body.add_child(cs)
		add_child(body)
		_respawn_debris(body)
		_debris.append(body)


func _respawn_debris(body: RigidBody3D) -> void:
	body.linear_velocity = Vector3(_rng.randf_range(-2, 2), _rng.randf_range(1, 4), _rng.randf_range(-2, 2))
	body.angular_velocity = Vector3(_rng.randf_range(-6, 6), _rng.randf_range(-6, 6), _rng.randf_range(-6, 6))
	body.position = Vector3(_rng.randf_range(8, 24), _rng.randf_range(2, 5), _rng.randf_range(6, 18))
	body.sleeping = false


func _build_sprites() -> void:
	var frames := _placeholder_frames()
	for i: int in SPRITE_COUNT:
		var sprite := AnimatedSprite3D.new()
		sprite.sprite_frames = frames
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.pixel_size = VFX_PIXEL_SIZE
		sprite.position = Vector3(3.0 + i * 2.8, 0.6, 4.0 + (i % 3) * 7.0)
		sprite.frame = i % SPRITE_FRAMES
		add_child(sprite)
		sprite.play("default")


## Procedural sparkle frames so the spike runs before pixelfx is baked in (0.9 swaps these out).
func _placeholder_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 12.0)
	frames.set_animation_loop("default", true)
	var s: int = SPRITE_FRAME_PX
	for f: int in SPRITE_FRAMES:
		var img := Image.create_empty(s, s, false, Image.FORMAT_RGBA8)
		var c: int = s / 2
		var r: int = mini(3 + f * 2, c - 1)
		for k: int in range(-r, r + 1):
			var a: float = 1.0 - absf(k) / float(r + 1)
			var col := Color(1.0, 0.85, 0.4, a)
			img.set_pixel(c + k, c, col)
			img.set_pixel(c, c + k, col)
		img.set_pixel(c, c, Color.WHITE)
		frames.add_frame("default", ImageTexture.create_from_image(img))
	return frames


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 16.0
	var target := Vector3(ROOM_W / 2.0, 0.0, ROOM_H / 2.0)
	var pitch: float = deg_to_rad(35.0)
	cam.position = target + Vector3(0.0, sin(pitch), cos(pitch)) * 30.0
	add_child(cam)
	cam.look_at(target)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	_stats = Label.new()
	_stats.position = Vector2(16, 16)
	_stats.add_theme_font_size_override("font_size", 22)
	layer.add_child(_stats)
	add_child(layer)


# --- Measurement ------------------------------------------------------------

func _update_overlay() -> void:
	_stats.text = "FPS %d  |  %.2f ms\ndraw calls %d  |  objects %d\n%s  |  %s" % [
		Engine.get_frames_per_second(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_current_rendering_method(),
		"sampling..." if not _reported else "done (see log)",
	]


func _report() -> void:
	_reported = true
	var sorted := _frame_times.duplicate()
	sorted.sort()
	var total: float = 0.0
	for dt: float in sorted:
		total += dt
	var avg_fps: float = sorted.size() / total
	var worst_count: int = maxi(1, sorted.size() / 100)
	var worst_total: float = 0.0
	for i: int in worst_count:
		worst_total += sorted[sorted.size() - 1 - i]
	var low_fps: float = worst_count / worst_total
	var line: String = "PERF_SPIKE renderer=%s device=%s avg_fps=%.1f low1_fps=%.1f draw_calls=%d frames=%d" % [
		RenderingServer.get_current_rendering_method(), OS.get_model_name(), avg_fps, low_fps,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), sorted.size()]
	print(line)
	var file := FileAccess.open("user://perf_spike.log", FileAccess.READ_WRITE if FileAccess.file_exists("user://perf_spike.log") else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line("%s %s" % [Time.get_datetime_string_from_system(), line])
	# For scripted runs: `godot --path game res://scenes/spikes/perf_spike.tscn -- --quit-on-report`
	if "--quit-on-report" in OS.get_cmdline_user_args():
		get_tree().quit()

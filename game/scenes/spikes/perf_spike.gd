extends Node3D
## Sprint 0 task 0.6: mobile performance spike (Gate A).
## A 32x24 tile room drawn with MultiMesh, 8 flickering torch lights, a tilted ortho camera,
## 20 Jolt debris bodies that keep respawning, and pixelfx sprites: 8 looping torches plus
## dust/sparkle one-shots popping continuously (10+ on screen at once).
## After the sample it prints avg fps / 1% low / draw calls (visible in `adb logcat -s godot`), and every
## 2 s a PERF_TICK line splitting the frame into CPU and GPU render time.
## Throwaway spike code: not a template for the real LevelView.
##
## Optional user://spike.cfg (section [spike]) changes the load for bisecting on a device, e.g.
##   torches=0  debris=0  fx=false  render_scale=0.5  sample_seconds=15  autostart=true
## On a debug APK: adb shell run-as com.dscvrx.meridian sh -c 'printf "[spike]\ntorches=0\n" > files/spike.cfg'

const ROOM_W: int = 32
const ROOM_H: int = 24
const CONFIG_PATH: String = "user://spike.cfg"
const WARMUP_SECONDS: float = 3.0
const TICK_LOG_SECONDS: float = 2.0
## Seconds between dust/sparkle one-shots (each lives ~1 s, so ~4 alive alongside the torches).
const BURST_INTERVAL: float = 0.25

var _torch_count: int = 8
var _debris_count: int = 20
var _fx_enabled: bool = true
var _render_scale: float = 1.0
var _sample_seconds: float = 30.0
## Floor/wall MultiMesh chunk size in tiles (0 = one mesh for the whole room).
var _chunk: int = 0
## "omni": real OmniLight3D torches. "vertex": no lights; tiles are tinted per instance from the torches.
var _light_mode: String = "omni"

const VERTEX_LIGHT_HZ: float = 10.0
const TORCH_RANGE: float = 7.0
var _vertex_meshes: Array[MultiMesh] = []
var _vertex_positions: Array[PackedVector3Array] = []
var _vertex_base: Array[Color] = []
var _torch_positions: PackedVector3Array = PackedVector3Array()
var _vertex_timer: float = 0.0

var _rng := RandomNumberGenerator.new()
var _torches: Array[OmniLight3D] = []
var _debris: Array[RigidBody3D] = []
var _stats: Label
var _elapsed: float = 0.0
var _burst_timer: float = 0.0
var _burst_count: int = 0
var _frame_times: PackedFloat32Array = PackedFloat32Array()
var _reported: bool = false
var _tick_log_timer: float = 0.0


## True if user://spike.cfg asks to skip the boot screen (used by scripted device runs).
static func autostart_requested() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(CONFIG_PATH) == OK and bool(cfg.get_value("spike", "autostart", false))


func _ready() -> void:
	_load_config()
	_rng.seed = 1936
	var vp: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	get_viewport().scaling_3d_scale = _render_scale
	# Parse sheets up front so the first burst doesn't hitch.
	for fx_name: String in ["torch", "dust", "sparkle"]:
		PixelFx.load_sheet(fx_name)
	_build_environment()
	_build_room()
	_build_torches()
	_build_debris()
	_build_camera()
	_build_overlay()


func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = _elapsed
	for i: int in _torches.size():
		_torches[i].light_energy = 1.6 + 0.35 * sin(t * 9.0 + i * 1.7) + 0.15 * sin(t * 23.0 + i)
	if _light_mode == "vertex":
		_vertex_timer += delta
		if _vertex_timer >= 1.0 / VERTEX_LIGHT_HZ:
			_vertex_timer = 0.0
			_update_vertex_light()
	for body: RigidBody3D in _debris:
		if body.position.y < -2.0 or body.sleeping:
			_respawn_debris(body)
	if _fx_enabled:
		_burst_timer += delta
		while _burst_timer >= BURST_INTERVAL:
			_burst_timer -= BURST_INTERVAL
			_spawn_burst()
	_maybe_screenshot()
	if _elapsed > WARMUP_SECONDS and not _reported:
		_frame_times.append(delta)
		if _elapsed > WARMUP_SECONDS + _sample_seconds:
			_report()
	_tick_log_timer += delta
	if _tick_log_timer >= TICK_LOG_SECONDS:
		_tick_log_timer = 0.0
		print("PERF_TICK %s" % _timing_summary())
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
	# Group tiles by chunk (one group when _chunk == 0); each group becomes one MultiMesh per tile type.
	var floor_groups: Dictionary = {}
	var wall_groups: Dictionary = {}
	for y: int in ROOM_H:
		for x: int in ROOM_W:
			var key := Vector2i(x / _chunk, y / _chunk) if _chunk > 0 else Vector2i.ZERO
			var edge: bool = x == 0 or y == 0 or x == ROOM_W - 1 or y == ROOM_H - 1
			var pillar: bool = x % 6 == 3 and y % 5 == 2
			var groups: Dictionary = wall_groups if edge or pillar else floor_groups
			if not groups.has(key):
				groups[key] = [] as Array[Transform3D]
			var pos := Vector3(x, 0.5, y) if edge or pillar else Vector3(x, -0.05, y)
			(groups[key] as Array[Transform3D]).append(Transform3D(Basis(), pos))
	var floor_mesh: ArrayMesh = _box(Vector3(1.0, 0.1, 1.0))
	var wall_mesh: ArrayMesh = _box(Vector3(1.0, 1.0, 1.0))
	_set_material(floor_mesh, Color(0.55, 0.5, 0.42))
	_set_material(wall_mesh, Color(0.42, 0.45, 0.38))
	for key: Vector2i in floor_groups:
		_add_multimesh(floor_mesh, Color(0.55, 0.5, 0.42), floor_groups[key])
	for key: Vector2i in wall_groups:
		_add_multimesh(wall_mesh, Color(0.42, 0.45, 0.38), wall_groups[key])

	# Static ground collider for the debris (one box, not per tile).
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ROOM_W, 0.1, ROOM_H)
	shape.shape = box
	ground.add_child(shape)
	ground.position = Vector3(ROOM_W / 2.0 - 0.5, -0.05, ROOM_H / 2.0 - 0.5)
	add_child(ground)


func _set_material(mesh: Mesh, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	if _light_mode == "vertex":
		# Lighting comes from the per-instance colour, so skip per-pixel lighting entirely.
		mat.albedo_color = Color.WHITE
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.surface_set_material(0, mat)


func _add_multimesh(mesh: Mesh, color: Color, xforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = _light_mode == "vertex"
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	var positions := PackedVector3Array()
	for i: int in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		positions.append(xforms[i].origin)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	if _light_mode == "vertex":
		_vertex_meshes.append(mm)
		_vertex_positions.append(positions)
		_vertex_base.append(color)


## Tints every tile from ambient plus each torch's flickering falloff. Runs at VERTEX_LIGHT_HZ, not per frame.
func _update_vertex_light() -> void:
	var ambient: float = 0.25
	var energies := PackedFloat32Array()
	for i: int in _torch_positions.size():
		energies.append(0.9 + 0.2 * sin(_elapsed * 9.0 + i * 1.7) + 0.08 * sin(_elapsed * 23.0 + i))
	var warm := Color(1.0, 0.65, 0.35)
	var range_sq: float = TORCH_RANGE * TORCH_RANGE
	for m: int in _vertex_meshes.size():
		var mm: MultiMesh = _vertex_meshes[m]
		var positions: PackedVector3Array = _vertex_positions[m]
		var base: Color = _vertex_base[m]
		for i: int in positions.size():
			var p: Vector3 = positions[i]
			var r: float = ambient
			var g: float = ambient
			var b: float = ambient
			for t: int in _torch_positions.size():
				var d_sq: float = p.distance_squared_to(_torch_positions[t])
				if d_sq < range_sq:
					var k: float = (1.0 - d_sq / range_sq) * energies[t]
					r += warm.r * k
					g += warm.g * k
					b += warm.b * k
			mm.set_instance_color(i, Color(base.r * r, base.g * g, base.b * b))


func _box(size: Vector3) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = size
	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, box.get_mesh_arrays())
	return arr_mesh


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	_torch_count = int(cfg.get_value("spike", "torches", _torch_count))
	_debris_count = int(cfg.get_value("spike", "debris", _debris_count))
	_fx_enabled = bool(cfg.get_value("spike", "fx", _fx_enabled))
	_render_scale = float(cfg.get_value("spike", "render_scale", _render_scale))
	_sample_seconds = float(cfg.get_value("spike", "sample_seconds", _sample_seconds))
	_chunk = int(cfg.get_value("spike", "chunk", _chunk))
	_light_mode = str(cfg.get_value("spike", "light_mode", _light_mode))


func _config_summary() -> String:
	return "torches=%d debris=%d fx=%s scale=%.2f chunk=%d light=%s" % [
		_torch_count, _debris_count, _fx_enabled, _render_scale, _chunk, _light_mode]


func _build_torches() -> void:
	for i: int in _torch_count:
		var col: int = i % 4
		var row: int = i / 4
		var pos := Vector3(4.0 + col * 8.0, 1.6, 6.0 + row * 12.0)
		_torch_positions.append(Vector3(pos.x, 0.0, pos.z))
		if _light_mode == "omni":
			var light := OmniLight3D.new()
			light.position = pos
			light.light_color = Color(1.0, 0.65, 0.35)
			light.omni_range = TORCH_RANGE
			light.shadow_enabled = false
			add_child(light)
			_torches.append(light)
		if _fx_enabled:
			PixelFx.spawn(self, "torch", Vector3(pos.x, 0.0, pos.z))
	if _light_mode == "vertex":
		_update_vertex_light()


func _build_debris() -> void:
	var mesh := _box(Vector3(0.25, 0.25, 0.25))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.42, 0.34)
	mesh.surface_set_material(0, mat)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.25, 0.25, 0.25)
	for i: int in _debris_count:
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


func _spawn_burst() -> void:
	_burst_count += 1
	var fx_name: String = "sparkle" if _burst_count % 2 == 0 else "dust"
	var pos := Vector3(_rng.randi_range(2, ROOM_W - 3), 0.0, _rng.randi_range(2, ROOM_H - 3))
	PixelFx.spawn(self, fx_name, pos)


func _build_camera() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 22.0
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

## `-- --screenshot=<path>` saves one frame after the warm-up (for checking the look without a device).
func _maybe_screenshot() -> void:
	if _elapsed < WARMUP_SECONDS or has_meta(&"shot_taken"):
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="):
			set_meta(&"shot_taken", true)
			get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--screenshot="))

func _timing_summary() -> String:
	var vp: RID = get_viewport().get_viewport_rid()
	return "fps=%d gpu_ms=%.1f render_cpu_ms=%.1f process_ms=%.1f physics_ms=%.1f draws=%d %s" % [
		Engine.get_frames_per_second(),
		RenderingServer.viewport_get_measured_render_time_gpu(vp),
		RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu(),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		_config_summary(),
	]


func _update_overlay() -> void:
	_stats.text = "%s\n%s  |  %s" % [
		_timing_summary().replace(" torches", "\ntorches"),
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
	var line: String = "PERF_SPIKE renderer=%s device=%s avg_fps=%.1f low1_fps=%.1f draw_calls=%d frames=%d %s" % [
		RenderingServer.get_current_rendering_method(), OS.get_model_name(), avg_fps, low_fps,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), sorted.size(), _config_summary()]
	print(line)
	var file := FileAccess.open("user://perf_spike.log", FileAccess.READ_WRITE if FileAccess.file_exists("user://perf_spike.log") else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line("%s %s" % [Time.get_datetime_string_from_system(), line])
	# For scripted runs: `godot --path game res://scenes/spikes/perf_spike.tscn -- --quit-on-report`
	if "--quit-on-report" in OS.get_cmdline_user_args():
		get_tree().quit()

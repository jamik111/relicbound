class_name LevelView
extends Node3D
## Draws a SimState as grey-box geometry and moves it smoothly between ticks. It only reads states;
## it never changes them. One sim cell = one 1 m tile: cell (x, y) is at world (x, 0, y), so gravity
## (+y in the sim) points toward the camera (+z).
##
## Terrain: one MultiMesh per terrain type, rebuilt only when terrain changes (dirt dug, door opened,
## exit opened). Lighting is per-tile instance colour (ambient + a warm glow around the player),
## recomputed once per tick: no dynamic lights (docs/06_TECH_STACK.md, device results).
## Objects and the player: one MeshInstance3D each, keyed by the sim's stable object id.

const AMBIENT: float = 0.82
const GLOW_RADIUS: float = 4.5
const GLOW_STRENGTH: float = 0.35
const GLOW_COLOR: Color = Color(1.0, 0.82, 0.6)

const TERRAIN_COLORS: Dictionary = {
	Tiles.Terrain.FLOOR: Color(0.70, 0.62, 0.46),
	Tiles.Terrain.WALL: Color(0.24, 0.28, 0.36),
	Tiles.Terrain.ANCIENT_WALL: Color(0.50, 0.38, 0.22),
	Tiles.Terrain.DIRT: Color(0.42, 0.27, 0.14),
	Tiles.Terrain.EXIT: Color(0.38, 0.36, 0.40),
	Tiles.Terrain.CHECKPOINT: Color(0.45, 0.50, 0.46),
	Tiles.Terrain.CHECKPOINT_LIT: Color(0.30, 1.0, 0.65),
	Tiles.Terrain.PIT: Color.WHITE,  # colours are baked into the mesh
	Tiles.Terrain.CRACKED: Color(0.70, 0.62, 0.46),
	Tiles.Terrain.CRACKED_COLLAPSING: Color(0.85, 0.35, 0.20),
	Tiles.Terrain.SPIKES_A: Color(0.40, 0.40, 0.42),
	Tiles.Terrain.SPIKES_B: Color(0.40, 0.40, 0.42),
	Tiles.Terrain.DART_EAST: Color.WHITE,
	Tiles.Terrain.DART_WEST: Color.WHITE,
	Tiles.Terrain.PLATE: Color(0.85, 0.62, 0.15),
	Tiles.Terrain.GATE: Color(0.60, 0.66, 0.78),
	Tiles.Terrain.DOOR_RED: Color(0.80, 0.22, 0.20),
	Tiles.Terrain.DOOR_BLUE: Color(0.22, 0.42, 0.85),
	Tiles.Terrain.DOOR_GOLD: Color(0.90, 0.72, 0.20),
	Tiles.Terrain.DOOR_JADE: Color(0.20, 0.68, 0.52),
}
const EXIT_OPEN_COLOR: Color = Color(1.0, 0.85, 0.35)
## Events after which the terrain MultiMeshes are rebuilt.
const TERRAIN_EVENTS: Array[SimEvent.Type] = [
	SimEvent.Type.DIRT_DUG, SimEvent.Type.DOOR_OPENED, SimEvent.Type.EXIT_OPENED, SimEvent.Type.CHECKPOINT_LIT,
	SimEvent.Type.PIT_FILLED, SimEvent.Type.FLOOR_CRACKING, SimEvent.Type.FLOOR_COLLAPSED,
]
const SPIKE_COLORS: Array[Color] = [Color(0.50, 0.50, 0.54), Color(1.0, 0.65, 0.15), Color(1.0, 0.15, 0.10)]
## Spike height for each RuleHazards.SpikePhase: they visibly rise through the warning.
const SPIKE_SCALES: Array[float] = [0.25, 0.55, 1.0]
## Shapes on keys and doors, so colour is never the only cue (GDD): red, blue, gold, jade.
const KEY_SHAPES: Array[String] = ["♦", "●", "▲", "■"]
const PLAYER_DEAD_TINT: Color = Color(1.0, 0.25, 0.2)
const GEM_SPIN_SPEED: float = 2.5
## The step is a hop (Crossy Road-like feel): a small arc, a stretch in the air and a squash on landing. View only.
const HOP_HEIGHT: float = 0.18
const HOP_STRETCH: float = 0.14
const HOP_SQUASH: float = 0.2
## How long the landing squash lasts, in ticks after touching down.
const LAND_TICKS: float = 0.8
const GEM_BOB_HEIGHT: float = 0.06
const PLATE_ACTIVE_COLOR: Color = Color(1.0, 0.95, 0.4)
const ECHO_COLOR: Color = Color(0.5, 1.0, 1.0, 0.8)
## A failed attempt replaying, and the statue left where you died: red, so they never read as your helpful echoes.
const REMNANT_COLOR: Color = Color(1.0, 0.35, 0.3, 0.8)
const SCAR_COLOR: Color = Color(0.62, 0.16, 0.14)
const VIPER_PATH_COLOR: Color = Color(0.55, 0.95, 0.2)
const BAT_PATH_COLOR: Color = Color(0.8, 0.45, 1.0)
const VIPER_SCALE: float = 1.5
const BAT_SCALE: float = 1.4
const PATH_DOT_HEIGHT: float = 0.02
## An echo fades out over its last ticks, so you can see the plate is about to let go.
const ECHO_FADE_TICKS: float = 20.0
const DART_COLOR: Color = Color(1.0, 0.25, 0.15)
const DART_FLASH_SECONDS: float = 0.15
const DART_WARNING_SECONDS: float = 0.5
const KEY_COLORS: Array[Color] = [
	Color(0.90, 0.25, 0.22), Color(0.30, 0.50, 0.95), Color(0.95, 0.78, 0.25), Color(0.25, 0.78, 0.58),
]

var _prev: SimState
var _cur: SimState
## terrain id -> MultiMeshInstance3D
var _terrain_nodes: Dictionary = {}
## terrain id -> PackedInt32Array of cell indices (instance order)
var _terrain_cells: Dictionary = {}
var _floor: MultiMeshInstance3D
var _floor_cells: PackedInt32Array = PackedInt32Array()
## object id -> MeshInstance3D
var _objects: Dictionary = {}
var _player: MeshInstance3D
## object id -> cell, for the previous and current state
var _prev_cells: Dictionary = {}
var _cur_cells: Dictionary = {}
var _meshes: Dictionary = {}
## object id -> Tiles.Obj, for per-kind animation
var _kinds: Dictionary = {}
## Name tags on the exit and doors; rebuilt with the terrain.
var _labels: Array[Label3D] = []
var _player_mat: StandardMaterial3D = GreyboxMeshes.material(Color.WHITE)
var _player_dead_mat: StandardMaterial3D = GreyboxMeshes.material(PLAYER_DEAD_TINT)
## Ticks one step of the player's walk takes on screen (Game.MOVE_INTERVAL_TICKS): keeps walking continuous.
var player_move_ticks: int = 2
var _player_from: Vector3 = Vector3.ZERO
var _player_move_tick: int = 0
## echo id -> {node, from, to, tick, material}
var _echo_views: Dictionary = {}
## enemy id -> {node, from, to, tick}
var _enemy_views: Dictionary = {}
## Dots showing where enemies go, so they read as patterns rather than chance. One draw call.
var _enemy_path_dots: MultiMeshInstance3D


func _ready() -> void:
	_meshes = _build_meshes()


## All shapes are code-built placeholders (art pipeline: no final art before Gate B), but each kind of thing
## has its own silhouette so it can be told apart at phone size.
static func _build_meshes() -> Dictionary:
	var dark := Color(0.35, 0.35, 0.35)
	var band := Color(0.55, 0.55, 0.55)
	var rim := Color(0.55, 0.20, 0.10)
	var crack := Color(0.15, 0.15, 0.15)
	var hat := Color(0.55, 0.36, 0.16)
	var shadow: Dictionary = GreyboxMeshes.part_cyl(0.30, 0.30, 0.01, Vector3(0.0, 0.01, 0.0), Color(0.36, 0.31, 0.24), 12)
	return {
		&"floor": GreyboxMeshes.box(Vector3(1.0, 0.1, 1.0)),
		&"wall": GreyboxMeshes.box(Vector3(1.0, 0.6, 1.0)),
		&"dirt": GreyboxMeshes.assemble([
			GreyboxMeshes.part_box(Vector3(1.0, 0.25, 1.0), Vector3(0.0, 0.125, 0.0)),
			GreyboxMeshes.part_ball(0.13, Vector3(-0.22, 0.26, -0.18), Color(0.8, 0.8, 0.8), 6, 3),
			GreyboxMeshes.part_ball(0.10, Vector3(0.25, 0.26, 0.05), Color(1.3, 1.3, 1.3), 6, 3),
			GreyboxMeshes.part_ball(0.09, Vector3(-0.05, 0.26, 0.28), Color(0.8, 0.8, 0.8), 6, 3),
		] as Array[Dictionary]),
		&"door": GreyboxMeshes.assemble([
			GreyboxMeshes.part_box(Vector3(0.9, 0.75, 0.5), Vector3(0.0, 0.375, 0.0)),
			GreyboxMeshes.part_box(Vector3(0.08, 0.75, 0.04), Vector3(-0.25, 0.375, 0.26), dark),
			GreyboxMeshes.part_box(Vector3(0.08, 0.75, 0.04), Vector3(0.25, 0.375, 0.26), dark),
		] as Array[Dictionary]),
		&"exit": GreyboxMeshes.assemble([
			GreyboxMeshes.part_box(Vector3(0.9, 0.06, 0.9), Vector3(0.0, 0.03, 0.0)),
			GreyboxMeshes.part_box(Vector3(0.16, 1.0, 0.2), Vector3(-0.37, 0.5, 0.0)),
			GreyboxMeshes.part_box(Vector3(0.16, 1.0, 0.2), Vector3(0.37, 0.5, 0.0)),
			GreyboxMeshes.part_box(Vector3(0.95, 0.18, 0.25), Vector3(0.0, 1.05, 0.0)),
		] as Array[Dictionary]),
		&"idol": GreyboxMeshes.assemble([
			GreyboxMeshes.part_cyl(0.32, 0.26, 0.12, Vector3(0.0, 0.06, 0.0)),
			GreyboxMeshes.part_cyl(0.13, 0.11, 0.5, Vector3(0.0, 0.37, 0.0)),
			GreyboxMeshes.part_ball(0.17, Vector3(0.0, 0.74, 0.0)),
		] as Array[Dictionary]),
		&"pit": GreyboxMeshes.assemble([
			GreyboxMeshes.part_box(Vector3(1.0, 0.02, 1.0), Vector3(0.0, -0.1, 0.0), Color(0.02, 0.02, 0.03)),
			GreyboxMeshes.part_box(Vector3(1.0, 0.05, 0.09), Vector3(0.0, -0.03, -0.455), rim),
			GreyboxMeshes.part_box(Vector3(1.0, 0.05, 0.09), Vector3(0.0, -0.03, 0.455), rim),
			GreyboxMeshes.part_box(Vector3(0.09, 0.05, 1.0), Vector3(-0.455, -0.03, 0.0), rim),
			GreyboxMeshes.part_box(Vector3(0.09, 0.05, 1.0), Vector3(0.455, -0.03, 0.0), rim),
		] as Array[Dictionary]),
		&"cracked": GreyboxMeshes.assemble([
			GreyboxMeshes.part_box(Vector3(0.98, 0.04, 0.98), Vector3(0.0, 0.0, 0.0)),
			GreyboxMeshes.part_box(Vector3(0.5, 0.02, 0.05), Vector3(-0.2, 0.03, -0.2), crack),
			GreyboxMeshes.part_box(Vector3(0.05, 0.02, 0.45), Vector3(0.05, 0.03, 0.0), crack),
			GreyboxMeshes.part_box(Vector3(0.45, 0.02, 0.05), Vector3(0.25, 0.03, 0.22), crack),
		] as Array[Dictionary]),
		&"spikes": GreyboxMeshes.assemble([
			GreyboxMeshes.part_cyl(0.13, 0.0, 0.5, Vector3(-0.25, 0.25, -0.25), Color.WHITE, 6),
			GreyboxMeshes.part_cyl(0.13, 0.0, 0.5, Vector3(0.25, 0.25, -0.25), Color.WHITE, 6),
			GreyboxMeshes.part_cyl(0.13, 0.0, 0.5, Vector3(0.0, 0.25, 0.0), Color.WHITE, 6),
			GreyboxMeshes.part_cyl(0.13, 0.0, 0.5, Vector3(-0.25, 0.25, 0.25), Color.WHITE, 6),
			GreyboxMeshes.part_cyl(0.13, 0.0, 0.5, Vector3(0.25, 0.25, 0.25), Color.WHITE, 6),
		] as Array[Dictionary]),
		&"path_dot": GreyboxMeshes.assemble([
			GreyboxMeshes.part_cyl(0.09, 0.09, 0.02, Vector3.ZERO, Color.WHITE, 8),
		] as Array[Dictionary]),
		&"viper": GreyboxMeshes.assemble([
			GreyboxMeshes.part_box(Vector3(0.2, 0.14, 0.26), Vector3(0.0, 0.07, -0.26), Color(0.75, 0.85, 0.2)),
			GreyboxMeshes.part_box(Vector3(0.22, 0.16, 0.26), Vector3(0.0, 0.08, 0.0), Color(0.45, 0.75, 0.15)),
			GreyboxMeshes.part_box(Vector3(0.3, 0.2, 0.26), Vector3(0.0, 0.1, 0.27), Color(0.8, 0.95, 0.2)),
			GreyboxMeshes.part_box(Vector3(0.06, 0.04, 0.12), Vector3(0.0, 0.1, 0.46), Color(1.0, 0.1, 0.1)),
		] as Array[Dictionary]),
		&"bat": GreyboxMeshes.assemble([
			GreyboxMeshes.part_ball(0.16, Vector3(0.0, 0.0, 0.0), Color(0.45, 0.2, 0.6), 8, 4),
			GreyboxMeshes.part_box(Vector3(0.36, 0.04, 0.26), Vector3(-0.3, 0.05, 0.0), Color(0.3, 0.12, 0.42)),
			GreyboxMeshes.part_box(Vector3(0.36, 0.04, 0.26), Vector3(0.3, 0.05, 0.0), Color(0.3, 0.12, 0.42)),
			GreyboxMeshes.part_ball(0.04, Vector3(-0.06, 0.08, 0.14), Color(1.0, 0.2, 0.2), 6, 3),
			GreyboxMeshes.part_ball(0.04, Vector3(0.06, 0.08, 0.14), Color(1.0, 0.2, 0.2), 6, 3),
		] as Array[Dictionary]),
		&"plate": GreyboxMeshes.assemble([
			GreyboxMeshes.part_cyl(0.42, 0.36, 0.06, Vector3(0.0, 0.03, 0.0), Color.WHITE, 12),
		] as Array[Dictionary]),
		&"gate": GreyboxMeshes.assemble([
			GreyboxMeshes.part_box(Vector3(1.0, 0.12, 0.3), Vector3(0.0, 0.84, 0.0)),
			GreyboxMeshes.part_box(Vector3(0.1, 0.9, 0.12), Vector3(-0.32, 0.45, 0.0)),
			GreyboxMeshes.part_box(Vector3(0.1, 0.9, 0.12), Vector3(0.0, 0.45, 0.0)),
			GreyboxMeshes.part_box(Vector3(0.1, 0.9, 0.12), Vector3(0.32, 0.45, 0.0)),
		] as Array[Dictionary]),
		&"dart_east": _dart_wall(1.0),
		&"dart_west": _dart_wall(-1.0),
		&"boulder": GreyboxMeshes.assemble([
			shadow,
			GreyboxMeshes.part_ball(0.45, Vector3(0.0, 0.45, 0.0), Color.WHITE, 14, 7),
			GreyboxMeshes.part_ball(0.09, Vector3(-0.2, 0.72, 0.2), Color(0.6, 0.6, 0.6), 6, 3),
			GreyboxMeshes.part_ball(0.07, Vector3(0.22, 0.45, 0.33), Color(0.6, 0.6, 0.6), 6, 3),
		] as Array[Dictionary]),
		&"crate": GreyboxMeshes.assemble([
			GreyboxMeshes.part_box(Vector3(0.8, 0.8, 0.8), Vector3(0.0, 0.4, 0.0)),
			GreyboxMeshes.part_box(Vector3(0.84, 0.1, 0.84), Vector3(0.0, 0.76, 0.0), band),
			GreyboxMeshes.part_box(Vector3(0.84, 0.1, 0.84), Vector3(0.0, 0.05, 0.0), band),
			GreyboxMeshes.part_box(Vector3(0.1, 0.8, 0.84), Vector3(-0.37, 0.4, 0.0), band),
			GreyboxMeshes.part_box(Vector3(0.1, 0.8, 0.84), Vector3(0.37, 0.4, 0.0), band),
		] as Array[Dictionary]),
		&"gem": GreyboxMeshes.assemble([
			GreyboxMeshes.part_ball(0.34, Vector3(0.0, 0.5, 0.0), Color.WHITE, 6, 2),
		] as Array[Dictionary]),
		&"key": GreyboxMeshes.assemble([
			GreyboxMeshes.part_cyl(0.16, 0.16, 0.08, Vector3(0.0, 0.45, -0.18), Color.WHITE, 10),
			GreyboxMeshes.part_box(Vector3(0.09, 0.08, 0.4), Vector3(0.0, 0.45, 0.1)),
			GreyboxMeshes.part_box(Vector3(0.16, 0.08, 0.07), Vector3(0.1, 0.45, 0.25)),
			GreyboxMeshes.part_box(Vector3(0.16, 0.08, 0.07), Vector3(0.1, 0.45, 0.12)),
		] as Array[Dictionary]),
		&"echo": GreyboxMeshes.assemble([
			GreyboxMeshes.part_box(Vector3(0.36, 0.42, 0.26), Vector3(0.0, 0.33, 0.0)),
			GreyboxMeshes.part_box(Vector3(0.3, 0.32, 0.14), Vector3(0.0, 0.38, -0.2)),
			GreyboxMeshes.part_ball(0.17, Vector3(0.0, 0.7, 0.0), Color.WHITE, 10, 5),
			GreyboxMeshes.part_cyl(0.3, 0.3, 0.04, Vector3(0.0, 0.83, 0.0), Color.WHITE, 12),
			GreyboxMeshes.part_cyl(0.17, 0.14, 0.17, Vector3(0.0, 0.92, 0.0), Color.WHITE, 10),
		] as Array[Dictionary]),
		&"player": GreyboxMeshes.assemble([
			shadow,
			GreyboxMeshes.part_box(Vector3(0.36, 0.42, 0.26), Vector3(0.0, 0.33, 0.0), Color(0.95, 0.35, 0.15)),
			GreyboxMeshes.part_box(Vector3(0.3, 0.32, 0.14), Vector3(0.0, 0.38, -0.2), Color(0.45, 0.28, 0.12)),
			GreyboxMeshes.part_ball(0.17, Vector3(0.0, 0.7, 0.0), Color(0.95, 0.75, 0.58), 10, 5),
			GreyboxMeshes.part_cyl(0.3, 0.3, 0.04, Vector3(0.0, 0.83, 0.0), hat, 12),
			GreyboxMeshes.part_cyl(0.17, 0.14, 0.17, Vector3(0.0, 0.92, 0.0), hat, 10),
		] as Array[Dictionary]),
	}


static func _dart_wall(dir_x: float) -> ArrayMesh:
	return GreyboxMeshes.assemble([
		GreyboxMeshes.part_box(Vector3(1.0, 0.6, 1.0), Vector3(0.0, 0.3, 0.0), Color(0.24, 0.28, 0.36)),
		GreyboxMeshes.part_box(Vector3(0.2, 0.26, 0.5), Vector3(0.55 * dir_x, 0.32, 0.0), Color(0.8, 0.12, 0.1)),
		GreyboxMeshes.part_box(Vector3(0.06, 0.12, 0.2), Vector3(0.66 * dir_x, 0.32, 0.0), Color(0.05, 0.05, 0.05)),
	] as Array[Dictionary])


## Rebuilds everything for a freshly loaded level.
func build(state: SimState) -> void:
	for child: Node in get_children():
		child.queue_free()
	_terrain_nodes.clear()
	_terrain_cells.clear()
	_objects.clear()
	_kinds.clear()
	_labels.clear()
	_echo_views.clear()
	_enemy_views.clear()
	_enemy_path_dots = null
	_floor = null
	_prev = state
	_cur = state
	_cur_cells = _object_cells(state)
	_prev_cells = _cur_cells
	_build_terrain()
	for id: int in _cur_cells:
		_spawn_object(id, state.object_at(_cur_cells[id]))
	_player = MeshInstance3D.new()
	_player.mesh = _meshes[&"player"]
	_player.material_override = _player_mat
	add_child(_player)
	_player_from = cell_to_world(state.player)
	_player_move_tick = state.tick - player_move_ticks
	_sync_enemies()
	_sync_echoes()
	_apply_light()
	interpolate(1.0)


## Called once per sim tick with the states on either side of it.
func show_state(prev: SimState, cur: SimState, events: Array) -> void:
	_prev = prev
	_cur = cur
	_prev_cells = _cur_cells
	_cur_cells = _object_cells(cur)
	if prev.player != cur.player:
		_player_from = Vector3(_player.position.x, 0.0, _player.position.z)
		_player_move_tick = cur.tick
	var terrain_changed: bool = false
	for e: Variant in events:
		var ev: SimEvent = e as SimEvent
		if ev.type in TERRAIN_EVENTS:
			terrain_changed = true
		elif ev.type == SimEvent.Type.DART_FIRED:
			_flash_dart(ev.cell, ev.to)
		elif ev.type == SimEvent.Type.DART_WARNING:
			_flash_dart_warning(ev.cell)
	if terrain_changed:
		_build_terrain()
	# Objects that are gone (collected) disappear; new ids (none yet in Sprint 2) appear.
	for id: int in _objects.keys():
		if not _cur_cells.has(id):
			(_objects[id] as Node).queue_free()
			_objects.erase(id)
			_kinds.erase(id)
	for id: int in _cur_cells:
		if not _objects.has(id):
			_spawn_object(id, cur.object_at(_cur_cells[id]))
	_player.material_override = _player_mat if cur.alive else _player_dead_mat
	_sync_enemies()
	_sync_echoes()
	_apply_light()


## Places moving things between the previous and current tick (alpha 0..1). Called every frame.
func interpolate(alpha: float) -> void:
	if _cur == null:
		return
	for id: int in _objects:
		var to: Vector2i = _cur_cells[id]
		var from: Vector2i = _prev_cells.get(id, to)
		var node: Node3D = _objects[id]
		node.position = cell_to_world(from).lerp(cell_to_world(to), alpha)
		if _kinds[id] == Tiles.Obj.GEM:
			# Cosmetic only: draws the eye to what you're here to collect.
			var t: float = Time.get_ticks_msec() / 1000.0
			node.rotation.y = t * GEM_SPIN_SPEED
			node.position.y += sin(t * 3.0 + id) * GEM_BOB_HEIGHT
	_hop(_player, _player_from, cell_to_world(_cur.player), (_cur.tick - _player_move_tick + alpha) / player_move_ticks)
	_player.rotation.y = atan2(float(_cur.facing.x), float(_cur.facing.y))
	if not _cur.alive:
		_player.scale = Vector3(1.2, 0.25, 1.2)
	for e: SimEnemy in _cur.enemies:
		var enemy_view: Dictionary = _enemy_views[e.id]
		var ticks: float = float(RuleEnemies.BAT_MOVE_TICKS if e.kind == SimEnemy.Kind.BAT else RuleEnemies.VIPER_MOVE_TICKS)
		var along: float = clampf((_cur.tick - int(enemy_view["tick"]) + alpha) / ticks, 0.0, 1.0)
		var enemy_node: Node3D = enemy_view["node"]
		enemy_node.position = (enemy_view["from"] as Vector3).lerp(_enemy_world(e), along)
		enemy_node.rotation.y = atan2(float(e.dir.x), float(e.dir.y))
	for e: SimEcho in _cur.echoes:
		var view: Dictionary = _echo_views[e.id]
		var node: Node3D = view["node"]
		_hop(node, view["from"] as Vector3, cell_to_world(e.cell), (_cur.tick - int(view["tick"]) + alpha) / player_move_ticks)
		node.rotation.y = atan2(float(e.facing.x), float(e.facing.y))


## Places a walker `p` of the way through a step (0..1, more while landing). Ease out across, so most of the step shows
## at once and the character reacts the moment you press (playtest 6).
static func _hop(node: Node3D, from: Vector3, to: Vector3, p: float) -> void:
	var t: float = clampf(p, 0.0, 1.0)
	node.position = from.lerp(to, 1.0 - (1.0 - t) * (1.0 - t))
	if from.is_equal_approx(to):
		node.scale = Vector3.ONE
		return
	node.position.y += HOP_HEIGHT * 4.0 * t * (1.0 - t)
	var land: float = clampf((p - 1.0) / LAND_TICKS, 0.0, 1.0)
	var k: float = HOP_STRETCH * sin(PI * t) - (HOP_SQUASH * sin(PI * land) if p > 1.0 else 0.0)
	node.scale = Vector3(1.0 - k * 0.5, 1.0 + k, 1.0 - k * 0.5)


static func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0.0, c.y)


func player_world_position() -> Vector3:
	return _player.position if _player else Vector3.ZERO


# --- Terrain ------------------------------------------------------------------

func _build_terrain() -> void:
	for node: Node in _terrain_nodes.values():
		node.queue_free()
	for label: Label3D in _labels:
		label.queue_free()
	_labels.clear()
	if _floor:
		_floor.queue_free()
	_terrain_nodes.clear()
	_terrain_cells.clear()
	_floor_cells = PackedInt32Array()
	var s: SimState = _cur
	for i: int in s.terrain.size():
		var t: int = s.terrain[i]
		if not _is_solid_block(t) and t != Tiles.Terrain.PIT:
			_floor_cells.append(i)
		if t == Tiles.Terrain.FLOOR:
			continue
		# Packed arrays are copied out of a Dictionary, so append to a local and store it back.
		var cells: PackedInt32Array = _terrain_cells.get(t, PackedInt32Array())
		cells.append(i)
		_terrain_cells[t] = cells
		var cell := Vector2i(i % s.width, i / s.width)
		if t == Tiles.Terrain.EXIT:
			_add_label("EXIT", cell, 1.5, EXIT_OPEN_COLOR if s.exit_open else Color(0.75, 0.75, 0.8))
		elif Tiles.is_door(t):
			_add_label(KEY_SHAPES[Tiles.door_color(t)], cell, 1.15, Color.WHITE)
	_floor = _make_multimesh(_meshes[&"floor"], _floor_cells, -0.1)
	for t: int in _terrain_cells:
		var mesh: Mesh = _meshes[_terrain_mesh_key(t)]
		_terrain_nodes[t] = _make_multimesh(mesh, _terrain_cells[t], 0.0)


func _terrain_mesh_key(t: int) -> StringName:
	if t == Tiles.Terrain.DART_EAST:
		return &"dart_east"
	if t == Tiles.Terrain.DART_WEST:
		return &"dart_west"
	if _is_solid_block(t):
		return &"wall"
	if t == Tiles.Terrain.PIT:
		return &"pit"
	if Tiles.is_spikes(t):
		return &"spikes"
	if t == Tiles.Terrain.CRACKED or t == Tiles.Terrain.CRACKED_COLLAPSING:
		return &"cracked"
	if t == Tiles.Terrain.DIRT:
		return &"dirt"
	if t == Tiles.Terrain.EXIT:
		return &"exit"
	if t == Tiles.Terrain.CHECKPOINT or t == Tiles.Terrain.CHECKPOINT_LIT:
		return &"idol"
	if t == Tiles.Terrain.PLATE:
		return &"plate"
	if t == Tiles.Terrain.GATE:
		return &"gate"
	return &"door"


func _add_label(text: String, cell: Vector2i, height: float, color: Color) -> void:
	var label: Label3D = _make_label(text, color)
	label.position = cell_to_world(cell) + Vector3(0.0, height, 0.0)
	add_child(label)
	_labels.append(label)


static func _make_label(text: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.font_size = 48
	label.outline_size = 10
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	return label


## Full-height blocks with no floor slab under them.
static func _is_solid_block(t: int) -> bool:
	return (t == Tiles.Terrain.WALL or t == Tiles.Terrain.ANCIENT_WALL
		or t == Tiles.Terrain.DART_EAST or t == Tiles.Terrain.DART_WEST)


func _make_multimesh(mesh: Mesh, cells: PackedInt32Array, y: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = cells.size()
	for n: int in cells.size():
		var c := Vector2i(cells[n] % _cur.width, cells[n] / _cur.width)
		mm.set_instance_transform(n, Transform3D(Basis(), cell_to_world(c) + Vector3(0.0, y, 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = GreyboxMeshes.material(Color.WHITE)
	add_child(mmi)
	return mmi


## Per-tile light: ambient plus a warm glow around the player. Once per tick, not per frame.
func _apply_light() -> void:
	var p: Vector2 = Vector2(_cur.player)
	_tint(_floor, _floor_cells, TERRAIN_COLORS[Tiles.Terrain.FLOOR], p)
	for t: int in _terrain_nodes:
		var base: Color = TERRAIN_COLORS[t]
		if t == Tiles.Terrain.EXIT and _cur.exit_open:
			base = EXIT_OPEN_COLOR
		elif Tiles.is_spikes(t):
			var phase: RuleHazards.SpikePhase = RuleHazards.spike_phase(_cur.tick, t)
			base = SPIKE_COLORS[phase]
			_scale_cells(_terrain_nodes[t], _terrain_cells[t], SPIKE_SCALES[phase])
		elif t == Tiles.Terrain.GATE:
			_scale_cells(_terrain_nodes[t], _terrain_cells[t], 0.12 if _cur.gates_open else 1.0)
		elif t == Tiles.Terrain.PLATE and _cur.gates_open:
			base = PLATE_ACTIVE_COLOR
		_tint(_terrain_nodes[t], _terrain_cells[t], base, p)


func _scale_cells(node: MultiMeshInstance3D, cells: PackedInt32Array, height: float) -> void:
	var cell_basis: Basis = Basis().scaled(Vector3(1.0, height, 1.0))
	for n: int in cells.size():
		var c := Vector2i(cells[n] % _cur.width, cells[n] / _cur.width)
		node.multimesh.set_instance_transform(n, Transform3D(cell_basis, cell_to_world(c)))


func _tint(node: MultiMeshInstance3D, cells: PackedInt32Array, base: Color, player: Vector2) -> void:
	var mm: MultiMesh = node.multimesh
	var r_sq: float = GLOW_RADIUS * GLOW_RADIUS
	for n: int in cells.size():
		var c := Vector2(cells[n] % _cur.width, cells[n] / _cur.width)
		var d_sq: float = c.distance_squared_to(player)
		var glow: float = GLOW_STRENGTH * maxf(0.0, 1.0 - d_sq / r_sq)
		mm.set_instance_color(n, Color(
			base.r * (AMBIENT + glow * GLOW_COLOR.r),
			base.g * (AMBIENT + glow * GLOW_COLOR.g),
			base.b * (AMBIENT + glow * GLOW_COLOR.b)))


# --- Dart telegraph and shot (the sim's hit is instant; this is what makes it readable) ---

func _flash_dart(wall: Vector2i, stopped_at: Vector2i) -> void:
	var from: Vector3 = cell_to_world(wall)
	var to: Vector3 = cell_to_world(stopped_at)
	var box := BoxMesh.new()
	box.size = Vector3(absf(to.x - from.x), 0.07, 0.07)
	var shot := MeshInstance3D.new()
	shot.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = DART_COLOR
	shot.material_override = mat
	shot.position = (from + to) / 2.0 + Vector3(0.0, 0.4, 0.0)
	add_child(shot)
	_free_after(shot, DART_FLASH_SECONDS)


func _flash_dart_warning(wall: Vector2i) -> void:
	var label: Label3D = _make_label("!", DART_COLOR)
	label.font_size = 96
	label.position = cell_to_world(wall) + Vector3(0.0, 1.2, 0.0)
	add_child(label)
	_free_after(label, DART_WARNING_SECONDS)


func _free_after(node: Node, seconds: float) -> void:
	node.create_tween().tween_callback(node.queue_free).set_delay(seconds)


# --- Enemies ------------------------------------------------------------------

## Bats fly above walls; vipers stay on the floor.
static func _enemy_world(e: SimEnemy) -> Vector3:
	return cell_to_world(e.cell) + Vector3(0.0, 1.1 if e.kind == SimEnemy.Kind.BAT else 0.0, 0.0)


func _sync_enemies() -> void:
	var alive_ids: Dictionary = {}
	for e: SimEnemy in _cur.enemies:
		alive_ids[e.id] = true
		if not _enemy_views.has(e.id):
			var node := MeshInstance3D.new()
			node.mesh = _meshes[&"bat" if e.kind == SimEnemy.Kind.BAT else &"viper"]
			node.material_override = GreyboxMeshes.material(Color.WHITE)
			node.position = _enemy_world(e)
			node.scale = Vector3.ONE * (BAT_SCALE if e.kind == SimEnemy.Kind.BAT else VIPER_SCALE)
			add_child(node)
			_enemy_views[e.id] = {"node": node, "from": node.position, "to": e.cell, "tick": _cur.tick - 100}
		var view: Dictionary = _enemy_views[e.id]
		if view["to"] != e.cell:
			var at: Vector3 = (view["node"] as Node3D).position
			view["from"] = Vector3(at.x, 0.0, at.z)
			view["to"] = e.cell
			view["tick"] = _cur.tick
	for id: int in _enemy_views.keys():
		if not alive_ids.has(id):
			((_enemy_views[id] as Dictionary)["node"] as Node).queue_free()
			_enemy_views.erase(id)
	_show_enemy_paths()


func _show_enemy_paths() -> void:
	var cells: Array[Vector2i] = []
	var colors: Array[Color] = []
	for e: SimEnemy in _cur.enemies:
		var bat: bool = e.kind == SimEnemy.Kind.BAT
		var path: Array[Vector2i] = RuleEnemies.bat_path(_cur, e, RuleEnemies.BAT_PATH_PREVIEW) if bat else RuleEnemies.patrol_cells(_cur, e)
		for c: Vector2i in path:
			cells.append(c)
			colors.append(BAT_PATH_COLOR if bat else VIPER_PATH_COLOR)
	if _enemy_path_dots == null:
		if cells.is_empty():
			return
		_enemy_path_dots = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[&"path_dot"]
		_enemy_path_dots.multimesh = mm
		_enemy_path_dots.material_override = GreyboxMeshes.material(Color.WHITE)
		add_child(_enemy_path_dots)
	var dots: MultiMesh = _enemy_path_dots.multimesh
	dots.instance_count = cells.size()
	for i: int in cells.size():
		dots.set_instance_transform(i, Transform3D(Basis(), cell_to_world(cells[i]) + Vector3(0.0, PATH_DOT_HEIGHT, 0.0)))
		dots.set_instance_color(i, colors[i])


# --- Echoes -------------------------------------------------------------------

## Matches echo nodes to the current state: starts a step when one moved, fades it near the end, removes gone ones.
func _sync_echoes() -> void:
	var alive_ids: Dictionary = {}
	for e: SimEcho in _cur.echoes:
		alive_ids[e.id] = true
		if not _echo_views.has(e.id):
			_echo_views[e.id] = _make_echo_view(e)
		var view: Dictionary = _echo_views[e.id]
		if view["to"] != e.cell:
			view["from"] = (view["node"] as Node3D).position
			view["to"] = e.cell
			view["tick"] = _cur.tick
		var fade: float = clampf(e.linger / ECHO_FADE_TICKS, 0.0, 1.0)
		var base_alpha: float = REMNANT_COLOR.a if e.remnant else ECHO_COLOR.a
		(view["material"] as StandardMaterial3D).albedo_color.a = base_alpha * fade
	for id: int in _echo_views.keys():
		if not alive_ids.has(id):
			((_echo_views[id] as Dictionary)["node"] as Node).queue_free()
			_echo_views.erase(id)


func _make_echo_view(e: SimEcho) -> Dictionary:
	var mat: StandardMaterial3D = GreyboxMeshes.material(REMNANT_COLOR if e.remnant else ECHO_COLOR)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var node := MeshInstance3D.new()
	node.mesh = _meshes[&"echo"]
	node.material_override = mat
	node.position = cell_to_world(e.cell)
	add_child(node)
	return {"node": node, "from": node.position, "to": e.cell, "tick": _cur.tick - player_move_ticks, "material": mat}


# --- Objects ------------------------------------------------------------------

func _object_cells(s: SimState) -> Dictionary:
	var out: Dictionary = {}
	for i: int in s.ids.size():
		var id: int = s.ids[i]
		if id != 0:
			out[id] = Vector2i(i % s.width, i / s.width)
	return out


func _spawn_object(id: int, obj: int) -> void:
	var mi := MeshInstance3D.new()
	var color: Color
	match obj:
		Tiles.Obj.BOULDER:
			mi.mesh = _meshes[&"boulder"]
			color = Color(0.72, 0.70, 0.68)
		Tiles.Obj.CRATE:
			mi.mesh = _meshes[&"crate"]
			color = Color(0.85, 0.55, 0.22)
		Tiles.Obj.GEM:
			mi.mesh = _meshes[&"gem"]
			color = Color(0.25, 1.0, 0.95)
		Tiles.Obj.SCAR:
			mi.mesh = _meshes[&"echo"]
			color = SCAR_COLOR
		_:
			mi.mesh = _meshes[&"key"]
			color = KEY_COLORS[Tiles.key_color(obj)] if Tiles.is_key(obj) else Color.MAGENTA
	mi.material_override = GreyboxMeshes.material(color)
	if Tiles.is_key(obj):
		var label: Label3D = _make_label(KEY_SHAPES[Tiles.key_color(obj)], Color.WHITE)
		label.position = Vector3(0.0, 0.85, 0.0)
		mi.add_child(label)
	add_child(mi)
	_objects[id] = mi
	_kinds[id] = obj

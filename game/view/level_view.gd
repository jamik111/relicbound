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

const AMBIENT: float = 0.62
const GLOW_RADIUS: float = 4.5
const GLOW_STRENGTH: float = 0.55
const GLOW_COLOR: Color = Color(1.0, 0.82, 0.6)

const TERRAIN_COLORS: Dictionary = {
	Tiles.Terrain.FLOOR: Color(0.52, 0.48, 0.40),
	Tiles.Terrain.WALL: Color(0.42, 0.44, 0.40),
	Tiles.Terrain.ANCIENT_WALL: Color(0.55, 0.50, 0.36),
	Tiles.Terrain.DIRT: Color(0.45, 0.33, 0.22),
	Tiles.Terrain.EXIT: Color(0.25, 0.22, 0.18),
	Tiles.Terrain.CHECKPOINT: Color(0.35, 0.38, 0.33),
	Tiles.Terrain.CHECKPOINT_LIT: Color(0.35, 1.0, 0.70),
	Tiles.Terrain.DOOR_RED: Color(0.80, 0.22, 0.20),
	Tiles.Terrain.DOOR_BLUE: Color(0.22, 0.42, 0.85),
	Tiles.Terrain.DOOR_GOLD: Color(0.90, 0.72, 0.20),
	Tiles.Terrain.DOOR_JADE: Color(0.20, 0.68, 0.52),
}
const EXIT_OPEN_COLOR: Color = Color(1.0, 0.85, 0.35)
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
var _player_mat: StandardMaterial3D = GreyboxMeshes.material(Color(0.85, 0.62, 0.30))
var _player_dead_mat: StandardMaterial3D = GreyboxMeshes.material(Color(0.75, 0.15, 0.12))


func _ready() -> void:
	_meshes = {
		&"floor": GreyboxMeshes.box(Vector3(1.0, 0.1, 1.0)),
		&"wall": GreyboxMeshes.box(Vector3(1.0, 1.0, 1.0)),
		&"dirt": GreyboxMeshes.box(Vector3(1.0, 0.45, 1.0)),
		&"door": GreyboxMeshes.box(Vector3(0.9, 0.9, 0.9)),
		&"exit": GreyboxMeshes.box(Vector3(0.9, 0.12, 0.9)),
		&"idol": GreyboxMeshes.box(Vector3(0.35, 0.75, 0.35)),
		&"boulder": GreyboxMeshes.ball(0.44),
		&"crate": GreyboxMeshes.box(Vector3(0.8, 0.8, 0.8)),
		&"gem": GreyboxMeshes.gem(0.3),
		&"key": GreyboxMeshes.box(Vector3(0.3, 0.3, 0.5)),
		&"player": GreyboxMeshes.box(Vector3(0.55, 0.9, 0.55)),
	}


## Rebuilds everything for a freshly loaded level.
func build(state: SimState) -> void:
	for child: Node in get_children():
		child.queue_free()
	_terrain_nodes.clear()
	_terrain_cells.clear()
	_objects.clear()
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
	_apply_light()
	interpolate(1.0)


## Called once per sim tick with the states on either side of it.
func show_state(prev: SimState, cur: SimState, events: Array) -> void:
	_prev = prev
	_cur = cur
	_prev_cells = _cur_cells
	_cur_cells = _object_cells(cur)
	var terrain_changed: bool = false
	for e: Variant in events:
		var ev: SimEvent = e as SimEvent
		match ev.type:
			SimEvent.Type.DIRT_DUG, SimEvent.Type.DOOR_OPENED, SimEvent.Type.EXIT_OPENED, 					SimEvent.Type.CHECKPOINT_LIT:
				terrain_changed = true
	if terrain_changed:
		_build_terrain()
	# Objects that are gone (collected) disappear; new ids (none yet in Sprint 2) appear.
	for id: int in _objects.keys():
		if not _cur_cells.has(id):
			(_objects[id] as Node).queue_free()
			_objects.erase(id)
	for id: int in _cur_cells:
		if not _objects.has(id):
			_spawn_object(id, cur.object_at(_cur_cells[id]))
	_player.material_override = _player_mat if cur.alive else _player_dead_mat
	_apply_light()


## Places moving things between the previous and current tick (alpha 0..1). Called every frame.
func interpolate(alpha: float) -> void:
	if _cur == null:
		return
	for id: int in _objects:
		var to: Vector2i = _cur_cells[id]
		var from: Vector2i = _prev_cells.get(id, to)
		(_objects[id] as Node3D).position = cell_to_world(from).lerp(cell_to_world(to), alpha)
	_player.position = cell_to_world(_prev.player).lerp(cell_to_world(_cur.player), alpha)
	_player.scale = Vector3(1.2, 0.25, 1.2) if not _cur.alive else Vector3.ONE


static func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x, 0.0, c.y)


func player_world_position() -> Vector3:
	return _player.position if _player else Vector3.ZERO


# --- Terrain ------------------------------------------------------------------

func _build_terrain() -> void:
	for node: Node in _terrain_nodes.values():
		node.queue_free()
	if _floor:
		_floor.queue_free()
	_terrain_nodes.clear()
	_terrain_cells.clear()
	_floor_cells = PackedInt32Array()
	var s: SimState = _cur
	for i: int in s.terrain.size():
		var t: int = s.terrain[i]
		if t != Tiles.Terrain.WALL and t != Tiles.Terrain.ANCIENT_WALL:
			_floor_cells.append(i)
		if t == Tiles.Terrain.FLOOR:
			continue
		# Packed arrays are copied out of a Dictionary, so append to a local and store it back.
		var cells: PackedInt32Array = _terrain_cells.get(t, PackedInt32Array())
		cells.append(i)
		_terrain_cells[t] = cells
	_floor = _make_multimesh(_meshes[&"floor"], _floor_cells, -0.1)
	for t: int in _terrain_cells:
		var mesh: Mesh = _meshes[_terrain_mesh_key(t)]
		_terrain_nodes[t] = _make_multimesh(mesh, _terrain_cells[t], 0.0)


func _terrain_mesh_key(t: int) -> StringName:
	if t == Tiles.Terrain.WALL or t == Tiles.Terrain.ANCIENT_WALL:
		return &"wall"
	if t == Tiles.Terrain.DIRT:
		return &"dirt"
	if t == Tiles.Terrain.EXIT:
		return &"exit"
	if t == Tiles.Terrain.CHECKPOINT or t == Tiles.Terrain.CHECKPOINT_LIT:
		return &"idol"
	return &"door"


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
		_tint(_terrain_nodes[t], _terrain_cells[t], base, p)


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
			color = Color(0.62, 0.60, 0.56)
		Tiles.Obj.CRATE:
			mi.mesh = _meshes[&"crate"]
			color = Color(0.70, 0.50, 0.28)
		Tiles.Obj.GEM:
			mi.mesh = _meshes[&"gem"]
			color = Color(0.35, 0.95, 0.75)
		_:
			mi.mesh = _meshes[&"key"]
			color = KEY_COLORS[Tiles.key_color(obj)] if Tiles.is_key(obj) else Color.MAGENTA
	mi.material_override = GreyboxMeshes.material(color)
	add_child(mi)
	_objects[id] = mi

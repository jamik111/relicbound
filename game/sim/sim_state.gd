class_name SimState
extends RefCounted
## The whole game state for one level: plain data only, so it can be copied (rewind), hashed (replays)
## and saved. Cells are indexed `y * width + x`; +y is south, the direction gravity pulls.

## Bits in `flags`.
const FLAG_MOVING: int = 1

var width: int = 0
var height: int = 0
var terrain: PackedInt32Array = PackedInt32Array()
var objects: PackedInt32Array = PackedInt32Array()
var flags: PackedByteArray = PackedByteArray()
## Stable object ids (0 = no object) so the view can follow an object between ticks.
var ids: PackedInt32Array = PackedInt32Array()
var next_id: int = 1

var player: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.DOWN
var alive: bool = true
var won: bool = false

var gems_collected: int = 0
var gems_required: int = 0
var exit_open: bool = false
## Keys held, indexed by Tiles.KeyColor.
var keys: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])

var tick: int = 0
var rng_state: int = 1

## Active echoes of the player's past self, oldest first (RuleEcho).
var echoes: Array[SimEcho] = []
var enemies: Array[SimEnemy] = []
## True while every pressure plate in the level is active.
var gates_open: bool = false
## meta.remembers: dying here leaves a scar and a remnant (RuleMemory).
var remembers: bool = false
## Cell indices of the scars, oldest first.
var scars: PackedInt32Array = PackedInt32Array()
## Hourglass uses this level gives (meta.rewinds).
var hourglass_uses: int = 3


static func create(p_width: int, p_height: int, p_seed: int = 1) -> SimState:
	var s := SimState.new()
	s.width = p_width
	s.height = p_height
	var n: int = p_width * p_height
	s.terrain.resize(n)
	s.terrain.fill(Tiles.Terrain.FLOOR)
	s.objects.resize(n)
	s.objects.fill(Tiles.Obj.NONE)
	s.flags.resize(n)
	s.flags.fill(0)
	s.ids.resize(n)
	s.ids.fill(0)
	s.seed_rng(p_seed)
	return s


func copy() -> SimState:
	var s := SimState.new()
	s.width = width
	s.height = height
	s.terrain = terrain.duplicate()
	s.objects = objects.duplicate()
	s.flags = flags.duplicate()
	s.ids = ids.duplicate()
	s.next_id = next_id
	s.player = player
	s.facing = facing
	s.alive = alive
	s.won = won
	s.gems_collected = gems_collected
	s.gems_required = gems_required
	s.exit_open = exit_open
	s.keys = keys.duplicate()
	s.tick = tick
	s.rng_state = rng_state
	s.gates_open = gates_open
	s.remembers = remembers
	s.scars = scars.duplicate()
	s.hourglass_uses = hourglass_uses
	for e: SimEcho in echoes:
		s.echoes.append(e.copy())
	for e: SimEnemy in enemies:
		s.enemies.append(e.copy())
	return s


## For the save file. Only for a settled state in a level with no enemies: echoes and enemies aren't stored.
func to_dict() -> Dictionary:
	return {
		"terrain": Array(terrain), "objects": Array(objects), "flags": Array(flags), "ids": Array(ids),
		"next_id": next_id, "player": [player.x, player.y], "facing": [facing.x, facing.y],
		"gems_collected": gems_collected, "exit_open": exit_open, "keys": Array(keys), "tick": tick,
		"rng_state": rng_state, "gates_open": gates_open, "scars": Array(scars),
	}


## This state (a fresh level start) with a saved one laid over it, or null if the save doesn't fit the level.
func restored(d: Dictionary) -> SimState:
	if (d.get("terrain", []) as Array).size() != terrain.size():
		return null
	var s: SimState = copy()
	s.terrain = PackedInt32Array(d["terrain"] as Array)
	s.objects = PackedInt32Array(d["objects"] as Array)
	s.flags = PackedByteArray(d["flags"] as Array)
	s.ids = PackedInt32Array(d["ids"] as Array)
	s.next_id = int(d["next_id"])
	s.player = Vector2i(int(d["player"][0]), int(d["player"][1]))
	s.facing = Vector2i(int(d["facing"][0]), int(d["facing"][1]))
	s.gems_collected = int(d["gems_collected"])
	s.exit_open = bool(d["exit_open"])
	s.keys = PackedInt32Array(d["keys"] as Array)
	s.tick = int(d["tick"])
	s.rng_state = int(d["rng_state"])
	s.gates_open = bool(d["gates_open"])
	s.scars = PackedInt32Array(d["scars"] as Array)
	return s


# --- Cells -------------------------------------------------------------------

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func idx(c: Vector2i) -> int:
	return c.y * width + c.x


## Out-of-bounds reads as wall, so rules never need a separate bounds check.
func terrain_at(c: Vector2i) -> int:
	return terrain[idx(c)] if in_bounds(c) else Tiles.Terrain.WALL


func object_at(c: Vector2i) -> int:
	return objects[idx(c)] if in_bounds(c) else Tiles.Obj.NONE


func is_moving(c: Vector2i) -> bool:
	return in_bounds(c) and (flags[idx(c)] & FLAG_MOVING) != 0


func set_moving(c: Vector2i, moving: bool) -> void:
	var i: int = idx(c)
	flags[i] = (flags[i] | FLAG_MOVING) if moving else (flags[i] & ~FLAG_MOVING)


## Places a new object with a fresh id. Returns the id.
func spawn_object(c: Vector2i, obj: int) -> int:
	var i: int = idx(c)
	objects[i] = obj
	flags[i] = 0
	ids[i] = next_id
	next_id += 1
	return ids[i]


func remove_object(c: Vector2i) -> void:
	var i: int = idx(c)
	objects[i] = Tiles.Obj.NONE
	flags[i] = 0
	ids[i] = 0


## Moves an object with its flags and id. The destination must be empty.
func move_object(from: Vector2i, to: Vector2i) -> void:
	var a: int = idx(from)
	var b: int = idx(to)
	objects[b] = objects[a]
	flags[b] = flags[a]
	ids[b] = ids[a]
	objects[a] = Tiles.Obj.NONE
	flags[a] = 0
	ids[a] = 0


## True if an object may move into `c`: floor-like terrain or a pit, no object, no (living) player.
func is_open_for_object(c: Vector2i) -> bool:
	var t: int = terrain_at(c)
	return (Tiles.object_can_enter(t) or (t == Tiles.Terrain.GATE and gates_open)) and object_at(c) == Tiles.Obj.NONE and (c != player or not alive)


func echo_at(c: Vector2i) -> SimEcho:
	for e: SimEcho in echoes:
		if e.cell == c:
			return e
	return null


func count_objects(obj: int) -> int:
	return objects.count(obj)


# --- RNG (xorshift32; never use randi()/randf() in the sim) -----------------

func seed_rng(p_seed: int) -> void:
	rng_state = p_seed & 0xFFFFFFFF
	if rng_state == 0:
		rng_state = 0x9E3779B9


## Uniform int in [0, n).
func rand_int(n: int) -> int:
	var x: int = rng_state
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	rng_state = x
	return x % n


# --- Hash ----------------------------------------------------------------------

## SHA-256 over a fixed little-endian byte layout: identical on every platform and Godot build.
func hash() -> String:
	var header := PackedInt32Array([
		width, height, next_id, player.x, player.y, facing.x, facing.y, int(alive), int(won),
		gems_collected, gems_required, int(exit_open), tick, rng_state,
	])
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(header.to_byte_array())
	ctx.update(keys.to_byte_array())
	ctx.update(terrain.to_byte_array())
	ctx.update(objects.to_byte_array())
	ctx.update(flags)
	ctx.update(ids.to_byte_array())
	# Only when in use, so hashes of older replays don't change.
	if gates_open:
		ctx.update(PackedByteArray([1]))
	if not scars.is_empty():
		ctx.update(scars.to_byte_array())
	for e: SimEcho in echoes:
		ctx.update(e.to_ints().to_byte_array())
	for e: SimEnemy in enemies:
		ctx.update(e.to_ints().to_byte_array())
	return ctx.finish().hex_encode()

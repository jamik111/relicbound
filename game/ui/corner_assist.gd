class_name CornerAssist
extends RefCounted
## Forgiving turns while walking (playtest 4: corners were hard to manage on touch). Only decides which input to
## send: the sim never knows, so replays and rules are unaffected.
## - A turn into a wall made too early keeps you walking, up to TURN_AHEAD_TILES, to the opening ahead. Then it happens.
## - is_new_opening() finds the tiles where Game pauses a held walk, so you get time to turn instead of passing them.
## It never walks onto anything that could hurt you or change the room (a pit, spikes, cracked floor, dirt, an object),
## and never turns into a pit. It never moves you backwards: an automatic step back felt chaotic (playtest 5).

const TURN_AHEAD_TILES: int = 2


## The input to send now. Walking is the direction of the last real step, or NONE when standing still. If the result
## isn't `want`, the caller keeps `want` queued for the next step.
static func resolve(s: SimState, want: SimStep.Intent, walking: SimStep.Intent) -> SimStep.Intent:
	if walking == SimStep.Intent.NONE or want == walking:
		return want
	var turn: Vector2i = SimStep.DIRECTIONS[want]
	var ahead: Vector2i = SimStep.DIRECTIONS[walking]
	if turn == -ahead or not is_blocked(s, s.player + turn):
		return want
	var c: Vector2i = s.player
	for i: int in TURN_AHEAD_TILES:
		c += ahead
		if not _safe_to_walk(s, c):
			break
		if _is_opening(s, c + turn):
			return walking
	return want


## True if a side way opens at the player's tile that wasn't there one tile back: a real choice, so walking along a
## wall or across an open room doesn't count. Only on plain floor or a plate, never while standing on a hazard.
static func is_new_opening(s: SimState, walking: SimStep.Intent) -> bool:
	var t: int = s.terrain_at(s.player)
	if t != Tiles.Terrain.FLOOR and t != Tiles.Terrain.PLATE:
		return false
	var ahead: Vector2i = SimStep.DIRECTIONS[walking]
	var side := Vector2i(ahead.y, ahead.x)
	for dir: Vector2i in [side, -side]:
		if _is_opening(s, s.player + dir) and is_blocked(s, s.player - ahead + dir):
			return true
	return false


## True if the player can't step into `c` at all.
static func is_blocked(s: SimState, c: Vector2i) -> bool:
	if s.object_at(c) == Tiles.Obj.SCAR:
		return true
	var t: int = s.terrain_at(c)
	match t:
		Tiles.Terrain.WALL, Tiles.Terrain.ANCIENT_WALL, Tiles.Terrain.DART_EAST, Tiles.Terrain.DART_WEST:
			return true
		Tiles.Terrain.GATE:
			return not s.gates_open
		Tiles.Terrain.EXIT:
			return not s.exit_open
	return Tiles.is_door(t) and s.keys[Tiles.door_color(t)] <= 0


static func _safe_to_walk(s: SimState, c: Vector2i) -> bool:
	var t: int = s.terrain_at(c)
	return (t == Tiles.Terrain.FLOOR or t == Tiles.Terrain.PLATE) and s.object_at(c) == Tiles.Obj.NONE


static func _is_opening(s: SimState, c: Vector2i) -> bool:
	return not is_blocked(s, c) and s.terrain_at(c) != Tiles.Terrain.PIT

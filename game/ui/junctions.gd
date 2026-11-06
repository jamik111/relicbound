class_name Junctions
extends RefCounted
## Finds the tiles where a held walk pauses (Game.JUNCTION_PAUSE_TICKS), so you get time to turn instead of passing
## them (playtest 5). Only decides when to hold back an input: it never sends one. The game must never move the player
## unasked: an automatic step back and an automatic walk to the next opening were both tried and rejected for that.


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


static func _is_opening(s: SimState, c: Vector2i) -> bool:
	return not is_blocked(s, c) and s.terrain_at(c) != Tiles.Terrain.PIT

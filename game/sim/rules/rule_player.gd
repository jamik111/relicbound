class_name RulePlayer
extends RefCounted
## Tick phase 1: the player's intent. Walk, dig dirt, push boulders/crates, collect gems and keys,
## open doors with a matching key, and leave through the open exit.


## `dir` is one of the four unit vectors (or ZERO for no input). `done` marks cells whose object
## already moved this tick, so gravity won't move a just-pushed object again.
static func apply(s: SimState, dir: Vector2i, done: PackedByteArray, events: Array[SimEvent]) -> void:
	if dir == Vector2i.ZERO:
		return
	s.facing = dir
	var to: Vector2i = s.player + dir
	var obj: int = s.object_at(to)

	if obj != Tiles.Obj.NONE:
		if obj == Tiles.Obj.GEM:
			var gem_id: int = s.ids[s.idx(to)]
			s.remove_object(to)
			s.gems_collected += 1
			events.append(SimEvent.make(SimEvent.Type.GEM_COLLECTED, to, to, obj, gem_id, s.gems_collected))
			_move(s, to, events)
		elif Tiles.is_key(obj):
			var key_id: int = s.ids[s.idx(to)]
			var color: int = Tiles.key_color(obj)
			s.remove_object(to)
			s.keys[color] += 1
			events.append(SimEvent.make(SimEvent.Type.KEY_COLLECTED, to, to, obj, key_id, color))
			_move(s, to, events)
		elif _try_push(s, to, dir, done, events):
			_move(s, to, events)
		else:
			events.append(SimEvent.make(SimEvent.Type.PLAYER_BLOCKED, to))
		return

	var t: int = s.terrain_at(to)
	if t == Tiles.Terrain.FLOOR:
		_move(s, to, events)
	elif t == Tiles.Terrain.DIRT:
		s.terrain[s.idx(to)] = Tiles.Terrain.FLOOR
		events.append(SimEvent.make(SimEvent.Type.DIRT_DUG, to))
		_move(s, to, events)
	elif t == Tiles.Terrain.EXIT and s.exit_open:
		_move(s, to, events)
		s.won = true
		events.append(SimEvent.make(SimEvent.Type.LEVEL_COMPLETED, to))
	elif Tiles.is_door(t) and s.keys[Tiles.door_color(t)] > 0:
		var color: int = Tiles.door_color(t)
		s.keys[color] -= 1
		s.terrain[s.idx(to)] = Tiles.Terrain.FLOOR
		events.append(SimEvent.make(SimEvent.Type.DOOR_OPENED, to, to, Tiles.Obj.NONE, 0, color))
		_move(s, to, events)
	else:
		events.append(SimEvent.make(SimEvent.Type.PLAYER_BLOCKED, to))


static func _move(s: SimState, to: Vector2i, events: Array[SimEvent]) -> void:
	events.append(SimEvent.make(SimEvent.Type.PLAYER_MOVED, s.player, to))
	s.player = to


## Boulders push sideways only; crates push in all four directions. A moving (falling or rolling)
## object can't be pushed, and the far side must be open floor.
static func _try_push(s: SimState, at: Vector2i, dir: Vector2i, done: PackedByteArray,
		events: Array[SimEvent]) -> bool:
	var obj: int = s.object_at(at)
	if obj == Tiles.Obj.BOULDER and dir.y != 0:
		return false
	if obj != Tiles.Obj.BOULDER and obj != Tiles.Obj.CRATE:
		return false
	if s.is_moving(at):
		return false
	var dest: Vector2i = at + dir
	if not s.is_open_for_object(dest):
		return false
	var id: int = s.ids[s.idx(at)]
	s.move_object(at, dest)
	done[s.idx(dest)] = 1
	events.append(SimEvent.make(SimEvent.Type.OBJECT_PUSHED, at, dest, obj, id))
	return true

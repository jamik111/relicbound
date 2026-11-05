class_name RuleGravity
extends RefCounted
## Tick phase 3: falling and rolling. Gravity pulls south (+y). Cells are scanned bottom-to-top,
## left-to-right, so a column of objects falls together and nothing moves twice in one tick.
##
## - An object falls into open floor below it and becomes `moving`.
## - A round object (boulder, gem) resting on another resting round object rolls off: west first, then east,
##   if both the side tile and the tile below it are open. Crates never roll, and nothing rolls off a crate.
## - A falling object that enters the player's tile while `moving` crushes the player (a gem is caught
##   instead). A resting object above the player is safe.
## - A moving object that can't move any more comes to rest (OBJECT_LANDED).


## Returns the object that crushed the player this tick, or Tiles.Obj.NONE.
static func apply(s: SimState, done: PackedByteArray, events: Array[SimEvent]) -> int:
	var crushed_by: int = Tiles.Obj.NONE
	for y: int in range(s.height - 1, -1, -1):
		for x: int in s.width:
			var c := Vector2i(x, y)
			var i: int = s.idx(c)
			var obj: int = s.objects[i]
			if not Tiles.falls(obj) or done[i] != 0:
				continue
			var below: Vector2i = c + Vector2i.DOWN

			# Idols and the exit are safe spots: objects can't enter them, so nothing falls on a player there.
			if below == s.player and s.alive and Tiles.object_can_enter(s.terrain_at(below)):
				if s.is_moving(c):
					if obj == Tiles.Obj.GEM:
						var gem_id: int = s.ids[i]
						s.remove_object(c)
						s.gems_collected += 1
						events.append(SimEvent.make(SimEvent.Type.GEM_COLLECTED, below, below, obj, gem_id,
							s.gems_collected))
					elif crushed_by == Tiles.Obj.NONE:
						crushed_by = obj
						_fall(s, c, below, done, events)
				continue

			if s.is_open_for_object(below):
				_fall(s, c, below, done, events)
				continue

			if Tiles.is_round(obj) and Tiles.is_round(s.object_at(below)) and not s.is_moving(below):
				if _try_roll(s, c, Vector2i.LEFT, done, events) or _try_roll(s, c, Vector2i.RIGHT, done, events):
					continue

			if s.is_moving(c):
				s.set_moving(c, false)
				events.append(SimEvent.make(SimEvent.Type.OBJECT_LANDED, c, c, obj, s.ids[i]))
	return crushed_by


static func _fall(s: SimState, c: Vector2i, below: Vector2i, done: PackedByteArray, events: Array[SimEvent]) -> void:
	var obj: int = s.object_at(c)
	var id: int = s.ids[s.idx(c)]
	s.move_object(c, below)
	s.set_moving(below, true)
	done[s.idx(below)] = 1
	events.append(SimEvent.make(SimEvent.Type.OBJECT_FELL, c, below, obj, id))
	RuleHazards.settle(s, below, events)


static func _try_roll(s: SimState, c: Vector2i, side: Vector2i, done: PackedByteArray,
		events: Array[SimEvent]) -> bool:
	var to: Vector2i = c + side
	if not s.is_open_for_object(to) or not s.is_open_for_object(to + Vector2i.DOWN):
		return false
	var obj: int = s.object_at(c)
	var id: int = s.ids[s.idx(c)]
	s.move_object(c, to)
	s.set_moving(to, true)
	done[s.idx(to)] = 1
	events.append(SimEvent.make(SimEvent.Type.OBJECT_ROLLED, c, to, obj, id))
	RuleHazards.settle(s, to, events)
	return true

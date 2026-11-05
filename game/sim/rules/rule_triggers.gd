class_name RuleTriggers
extends RefCounted
## Tick phase 6: triggers. The exit opens once the gem quota is met; gates follow the pressure plates.


static func apply(s: SimState, events: Array[SimEvent]) -> void:
	_update_gates(s, events)
	if not s.exit_open and s.gems_collected >= s.gems_required:
		s.exit_open = true
		var exit_index: int = s.terrain.find(Tiles.Terrain.EXIT)
		var cell := Vector2i(-1, -1)
		if exit_index >= 0:
			cell = Vector2i(exit_index % s.width, exit_index / s.width)
		events.append(SimEvent.make(SimEvent.Type.EXIT_OPENED, cell))


## A remnant has no weight (playtest 3: one holding a plate turned level 7 into a timed run instead of a puzzle).
static func _echo_weighs_on(s: SimState, c: Vector2i) -> bool:
	for e: SimEcho in s.echoes:
		if e.cell == c and not e.remnant:
			return true
	return false


## Gates are open while every plate is weighed down, and stay open while someone is standing in one.
static func _update_gates(s: SimState, events: Array[SimEvent]) -> void:
	var plates: int = 0
	var plates_held: int = 0
	var gate_occupied: bool = false
	for i: int in s.terrain.size():
		var t: int = s.terrain[i]
		if t != Tiles.Terrain.PLATE and t != Tiles.Terrain.GATE:
			continue
		var c := Vector2i(i % s.width, i / s.width)
		var obj: int = s.objects[i]
		var occupied: bool = (obj == Tiles.Obj.BOULDER or obj == Tiles.Obj.CRATE or obj == Tiles.Obj.SCAR
			or _echo_weighs_on(s, c) or (c == s.player and s.alive))
		if t == Tiles.Terrain.PLATE:
			plates += 1
			plates_held += int(occupied)
		else:
			gate_occupied = gate_occupied or occupied
	var open: bool = (plates > 0 and plates_held == plates) or (s.gates_open and gate_occupied)
	if open != s.gates_open:
		s.gates_open = open
		events.append(SimEvent.make(SimEvent.Type.GATE_OPENED if open else SimEvent.Type.GATE_CLOSED, s.player))

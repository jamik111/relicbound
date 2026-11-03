class_name RuleTriggers
extends RefCounted
## Tick phase 6: triggers. For now: the exit opens once the gem quota is met.


static func apply(s: SimState, events: Array[SimEvent]) -> void:
	if not s.exit_open and s.gems_collected >= s.gems_required:
		s.exit_open = true
		var exit_index: int = s.terrain.find(Tiles.Terrain.EXIT)
		var cell := Vector2i(-1, -1)
		if exit_index >= 0:
			cell = Vector2i(exit_index % s.width, exit_index / s.width)
		events.append(SimEvent.make(SimEvent.Type.EXIT_OPENED, cell))

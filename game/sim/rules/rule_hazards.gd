class_name RuleHazards
extends RefCounted
## Hazards: pits, cracked floor, timed spikes and dart walls. All timing comes from `state.tick`,
## so there's no hidden per-tile state and replays stay exact.
##
## - Pit: walking in kills. A boulder/crate/gem that enters fills it (it becomes floor).
## - Cracked floor: when the player steps off it, it starts collapsing; at the start of the next tick it's a pit
##   (an object resting on it drops in and fills it).
## - Spikes: a SPIKE_CYCLE-tick loop: down, then SPIKE_WARN ticks of warning (GDD: telegraph >= 0.4 s), then
##   SPIKE_UP ticks up. Standing on them while up kills. Phase B runs half a cycle after phase A.
## - Dart walls: every DART_PERIOD ticks, after DART_WARN ticks of warning, a dart flies along the row until it hits
##   a solid tile or any object. The player in its path before that dies.

const SPIKE_CYCLE: int = 30
const SPIKE_WARN: int = 5
const SPIKE_UP: int = 5
const DART_PERIOD: int = 30
const DART_WARN: int = 5

enum SpikePhase { DOWN, WARNING, UP }


## Tick phase 0: effects scheduled by the previous tick (cracked floor marked last tick collapses now).
static func collapse(s: SimState, events: Array[SimEvent]) -> void:
	for i: int in s.terrain.size():
		if s.terrain[i] != Tiles.Terrain.CRACKED_COLLAPSING:
			continue
		var c := Vector2i(i % s.width, i / s.width)
		s.terrain[i] = Tiles.Terrain.PIT
		events.append(SimEvent.make(SimEvent.Type.FLOOR_COLLAPSED, c))
		settle(s, c, events)


## Called by the player rule when the player leaves `from`.
static func on_player_left(s: SimState, from: Vector2i, events: Array[SimEvent]) -> void:
	if s.terrain_at(from) == Tiles.Terrain.CRACKED:
		s.terrain[s.idx(from)] = Tiles.Terrain.CRACKED_COLLAPSING
		events.append(SimEvent.make(SimEvent.Type.FLOOR_CRACKING, from))


## Called after an object moves into `c`: if it's a pit, the object fills it.
static func settle(s: SimState, c: Vector2i, events: Array[SimEvent]) -> void:
	if s.terrain_at(c) != Tiles.Terrain.PIT or s.object_at(c) == Tiles.Obj.NONE:
		return
	var obj: int = s.object_at(c)
	var id: int = s.ids[s.idx(c)]
	s.remove_object(c)
	s.terrain[s.idx(c)] = Tiles.Terrain.FLOOR
	events.append(SimEvent.make(SimEvent.Type.PIT_FILLED, c, c, obj, id))


static func spike_phase(tick: int, terrain: int) -> SpikePhase:
	var offset: int = SPIKE_CYCLE / 2 if terrain == Tiles.Terrain.SPIKES_B else 0
	var t: int = (tick + offset) % SPIKE_CYCLE
	if t >= SPIKE_CYCLE - SPIKE_UP:
		return SpikePhase.UP
	if t >= SPIKE_CYCLE - SPIKE_UP - SPIKE_WARN:
		return SpikePhase.WARNING
	return SpikePhase.DOWN


## Tick phase 6 (hazards part): spikes and darts change state, and the player is checked against every hazard.
## Returns the SimEvent.Cause that kills the player this tick, or -1.
static func apply(s: SimState, events: Array[SimEvent]) -> int:
	var cause: int = -1
	var tick: int = s.tick
	var dart_t: int = tick % DART_PERIOD
	for i: int in s.terrain.size():
		var t: int = s.terrain[i]
		if Tiles.is_spikes(t):
			var c := Vector2i(i % s.width, i / s.width)
			var phase: SpikePhase = spike_phase(tick, t)
			var before: SpikePhase = spike_phase(tick + SPIKE_CYCLE - 1, t)
			if phase != before:
				var types: Array[SimEvent.Type] = [
					SimEvent.Type.SPIKES_DOWN, SimEvent.Type.SPIKES_WARNING, SimEvent.Type.SPIKES_UP]
				events.append(SimEvent.make(types[phase], c))
		elif t == Tiles.Terrain.DART_EAST or t == Tiles.Terrain.DART_WEST:
			var wall := Vector2i(i % s.width, i / s.width)
			if dart_t == DART_PERIOD - 1 - DART_WARN:
				events.append(SimEvent.make(SimEvent.Type.DART_WARNING, wall))
			elif dart_t == DART_PERIOD - 1:
				if _fire_dart(s, wall, Vector2i.RIGHT if t == Tiles.Terrain.DART_EAST else Vector2i.LEFT, events):
					cause = SimEvent.Cause.DART
	if s.alive and cause < 0:
		var under: int = s.terrain_at(s.player)
		if under == Tiles.Terrain.PIT:
			cause = SimEvent.Cause.PIT
		elif Tiles.is_spikes(under) and spike_phase(tick, under) == SpikePhase.UP:
			cause = SimEvent.Cause.SPIKES
	return cause


## Returns true if the dart hits the (living) player.
static func _fire_dart(s: SimState, wall: Vector2i, dir: Vector2i, events: Array[SimEvent]) -> bool:
	var c: Vector2i = wall + dir
	var hit: bool = false
	while s.in_bounds(c):
		if not _dart_passes(s.terrain_at(c)):
			break  # solid tiles, and idols, which shelter a player standing on them
		if c == s.player and s.alive:
			hit = true
			break
		var echo: SimEcho = s.echo_at(c)
		if echo:
			RuleEcho.destroy(s, echo, events)  # the echo takes the hit
			break
		if s.object_at(c) != Tiles.Obj.NONE:
			break
		c += dir
	events.append(SimEvent.make(SimEvent.Type.DART_FIRED, wall, c))
	return hit


static func _dart_passes(t: int) -> bool:
	return Tiles.object_can_enter(t) or t == Tiles.Terrain.EXIT

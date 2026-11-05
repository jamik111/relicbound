class_name RuleEcho
extends RefCounted
## Echoes, Relicbound's signature mechanic. Using the hourglass rewinds time, and the player's past self
## replays the recorded inputs as a ghost while the player acts freely.
##
## An echo walks, pushes boulders and crates, digs dirt and weighs down pressure plates. It's a ghost: it
## passes through gems and keys without taking them, can't open keyed doors or the exit, doesn't light idols,
## doesn't hold objects up, and the player walks through it. If the world has changed, it blindly
## keeps replaying its inputs. After the inputs run out it holds still for LINGER_TICKS, then fades.
## A boulder or crate landing on it, a dart, a pit or risen spikes destroy it: it can take a hit for you.

const LINGER_TICKS: int = 50


## The state after an hourglass use: `rewound` plus a new echo that will replay `inputs`.
static func spawned(rewound: SimState, inputs: PackedInt32Array) -> SimState:
	var s: SimState = rewound.copy()
	var e := SimEcho.new()
	e.id = s.next_id
	s.next_id += 1
	e.cell = s.player
	e.facing = s.facing
	e.inputs = inputs.duplicate()
	e.linger = LINGER_TICKS
	s.echoes.append(e)
	return s


## Tick phase 2: every echo plays its next input, or waits, or fades.
static func apply(s: SimState, done: PackedByteArray, events: Array[SimEvent]) -> void:
	for e: SimEcho in s.echoes.duplicate():
		if e.cursor < e.inputs.size():
			var dir: Vector2i = SimStep.DIRECTIONS[e.inputs[e.cursor]]
			e.cursor += 1
			_step(s, e, dir, done, events)
		else:
			e.linger -= 1
			if e.linger <= 0:
				s.echoes.erase(e)
				events.append(SimEvent.make(SimEvent.Type.ECHO_FADED, e.cell, e.cell, Tiles.Obj.NONE, e.id))


static func _step(s: SimState, e: SimEcho, dir: Vector2i, done: PackedByteArray, events: Array[SimEvent]) -> void:
	if dir == Vector2i.ZERO:
		return
	e.facing = dir
	var to: Vector2i = e.cell + dir
	var obj: int = s.object_at(to)
	if (obj == Tiles.Obj.BOULDER or obj == Tiles.Obj.CRATE) and not RulePlayer.try_push(s, to, dir, done, events):
		return
	var t: int = s.terrain_at(to)
	if t == Tiles.Terrain.DIRT:
		s.terrain[s.idx(to)] = Tiles.Terrain.FLOOR
		events.append(SimEvent.make(SimEvent.Type.DIRT_DUG, to))
	elif not _can_walk(s, t):
		return
	events.append(SimEvent.make(SimEvent.Type.ECHO_MOVED, e.cell, to, Tiles.Obj.NONE, e.id))
	e.cell = to


static func _can_walk(s: SimState, t: int) -> bool:
	return (Tiles.is_floor_like(t) or t == Tiles.Terrain.PIT or t == Tiles.Terrain.CHECKPOINT
		or t == Tiles.Terrain.CHECKPOINT_LIT or (t == Tiles.Terrain.GATE and s.gates_open))


## Tick phase 6: removes echoes hit by a fallen or pushed object, a pit or risen spikes.
static func resolve(s: SimState, events: Array[SimEvent]) -> void:
	for e: SimEcho in s.echoes.duplicate():
		var obj: int = s.object_at(e.cell)
		var t: int = s.terrain_at(e.cell)
		var spiked: bool = Tiles.is_spikes(t) and RuleHazards.spike_phase(s.tick, t) == RuleHazards.SpikePhase.UP
		if obj == Tiles.Obj.BOULDER or obj == Tiles.Obj.CRATE or t == Tiles.Terrain.PIT or spiked:
			destroy(s, e, events)


static func destroy(s: SimState, e: SimEcho, events: Array[SimEvent]) -> void:
	s.echoes.erase(e)
	events.append(SimEvent.make(SimEvent.Type.ECHO_DESTROYED, e.cell, e.cell, Tiles.Obj.NONE, e.id))

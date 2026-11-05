class_name Tiles
extends RefCounted
## Tile and object ids used by SimState. The numeric values are stored in saves and replays: never renumber.

## Terrain layer (SimState.terrain).
enum Terrain {
	FLOOR = 0,
	WALL = 1,
	ANCIENT_WALL = 2,
	DIRT = 3,
	EXIT = 4,
	## Checkpoint idol: the player can stand on it; objects can't enter. Lights when the player steps on it.
	CHECKPOINT = 5,
	CHECKPOINT_LIT = 6,
	## Deadly to walk into. A boulder or crate that enters it fills it (becomes FLOOR).
	PIT = 7,
	## Walkable; one tick after the player steps off it, it collapses into a PIT.
	CRACKED = 8,
	CRACKED_COLLAPSING = 9,
	## Timed spike traps (two phases half a cycle apart). Floor-like when down.
	SPIKES_A = 20,
	SPIKES_B = 21,
	## Dart walls: solid; fire along their row (east / west) on a timer.
	DART_EAST = 22,
	DART_WEST = 23,
	## Pressure plate: active while weighed down by the player, an echo, a boulder or a crate. Walkable.
	PLATE = 24,
	## Gate: open while every plate is active (SimState.gates_open). Won't close on someone standing in it.
	GATE = 25,
	DOOR_RED = 10,
	DOOR_BLUE = 11,
	DOOR_GOLD = 12,
	DOOR_JADE = 13,
}

## Object layer (SimState.objects).
enum Obj {
	NONE = 0,
	BOULDER = 1,
	CRATE = 2,
	GEM = 3,
	## Statue on a cell where the player died (RuleMemory). Solid, never moves, holds a plate down.
	SCAR = 4,
	KEY_RED = 10,
	KEY_BLUE = 11,
	KEY_GOLD = 12,
	KEY_JADE = 13,
}

## Key/door colours. Each also has a shape for colour-blind players: red ♦, blue ●, gold ▲, jade ■.
enum KeyColor { RED = 0, BLUE = 1, GOLD = 2, JADE = 3 }

const KEY_COLOR_COUNT: int = 4


static func is_door(t: int) -> bool:
	return t >= Terrain.DOOR_RED and t <= Terrain.DOOR_JADE


static func door_color(t: int) -> int:
	return t - Terrain.DOOR_RED


static func is_key(o: int) -> bool:
	return o >= Obj.KEY_RED and o <= Obj.KEY_JADE


static func key_color(o: int) -> int:
	return o - Obj.KEY_RED


## Terrain the player walks on like floor (hazards decide separately whether it hurts).
static func is_floor_like(t: int) -> bool:
	return (t == Terrain.FLOOR or t == Terrain.CRACKED or t == Terrain.CRACKED_COLLAPSING
		or t == Terrain.SPIKES_A or t == Terrain.SPIKES_B or t == Terrain.PLATE)


## Terrain a boulder/crate/gem may move into (a PIT swallows it and becomes floor).
static func object_can_enter(t: int) -> bool:
	return is_floor_like(t) or t == Terrain.PIT


static func is_spikes(t: int) -> bool:
	return t == Terrain.SPIKES_A or t == Terrain.SPIKES_B


## Objects that gravity moves.
static func falls(o: int) -> bool:
	return o == Obj.BOULDER or o == Obj.CRATE or o == Obj.GEM


## Round objects: things roll off them, and they roll off other round things.
static func is_round(o: int) -> bool:
	return o == Obj.BOULDER or o == Obj.GEM

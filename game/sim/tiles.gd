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


## Objects that gravity moves.
static func falls(o: int) -> bool:
	return o == Obj.BOULDER or o == Obj.CRATE or o == Obj.GEM


## Round objects: things roll off them, and they roll off other round things.
static func is_round(o: int) -> bool:
	return o == Obj.BOULDER or o == Obj.GEM

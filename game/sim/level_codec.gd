class_name LevelCodec
extends RefCounted
## Level format (JSON): text rows per layer, one character per tile.
##
## {
##   "id": "test_01", "size": [w, h],
##   "meta": {"name": "...", "gems_required": 3, "seed": 1},
##   "layers": {"terrain": ["#####", ...], "objects": [".@.O.", ...]}
## }
##
## `gems_required` defaults to every gem in the level. Objects may only sit on floor.
## Character legend (unique across both layers, so a combined map can be split unambiguously):

const TERRAIN_CHARS: Dictionary = {
	".": Tiles.Terrain.FLOOR,
	"#": Tiles.Terrain.WALL,
	"%": Tiles.Terrain.ANCIENT_WALL,
	":": Tiles.Terrain.DIRT,
	"E": Tiles.Terrain.EXIT,
	"I": Tiles.Terrain.CHECKPOINT,
	"R": Tiles.Terrain.DOOR_RED,
	"B": Tiles.Terrain.DOOR_BLUE,
	"G": Tiles.Terrain.DOOR_GOLD,
	"J": Tiles.Terrain.DOOR_JADE,
}

const OBJECT_CHARS: Dictionary = {
	"O": Tiles.Obj.BOULDER,
	"X": Tiles.Obj.CRATE,
	"*": Tiles.Obj.GEM,
	"r": Tiles.Obj.KEY_RED,
	"b": Tiles.Obj.KEY_BLUE,
	"g": Tiles.Obj.KEY_GOLD,
	"j": Tiles.Obj.KEY_JADE,
}

const PLAYER_CHAR: String = "@"
const EMPTY_CHAR: String = "."


## Builds the starting state. Problems are appended to `errors`; returns null if there are any.
static func parse(data: Dictionary, errors: PackedStringArray) -> SimState:
	var size: Array = data.get("size", []) as Array
	if size.size() != 2:
		errors.append("size must be [width, height]")
		return null
	var w: int = int(size[0])
	var h: int = int(size[1])
	var layers: Dictionary = data.get("layers", {}) as Dictionary
	var terrain_rows: Array = layers.get("terrain", []) as Array
	var object_rows: Array = layers.get("objects", []) as Array
	if w <= 0 or h <= 0:
		errors.append("size must be positive")
		return null
	_check_rows("terrain", terrain_rows, w, h, errors)
	_check_rows("objects", object_rows, w, h, errors)
	if not errors.is_empty():
		return null

	var meta: Dictionary = data.get("meta", {}) as Dictionary
	var s: SimState = SimState.create(w, h, int(meta.get("seed", 1)))
	var players: int = 0
	for y: int in h:
		var t_row: String = terrain_rows[y] as String
		var o_row: String = object_rows[y] as String
		for x: int in w:
			var c := Vector2i(x, y)
			var tc: String = t_row[x]
			var oc: String = o_row[x]
			if not TERRAIN_CHARS.has(tc):
				errors.append("terrain: unknown char '%s' at %s" % [tc, c])
				continue
			s.terrain[s.idx(c)] = TERRAIN_CHARS[tc]
			if oc == EMPTY_CHAR:
				continue
			if tc != EMPTY_CHAR:
				errors.append("objects: '%s' at %s must be on floor, not '%s'" % [oc, c, tc])
			elif oc == PLAYER_CHAR:
				players += 1
				s.player = c
			elif OBJECT_CHARS.has(oc):
				s.spawn_object(c, OBJECT_CHARS[oc])
			else:
				errors.append("objects: unknown char '%s' at %s" % [oc, c])
	if players != 1:
		errors.append("need exactly one player '@', found %d" % players)
	if not errors.is_empty():
		return null

	s.gems_required = int(meta.get("gems_required", s.count_objects(Tiles.Obj.GEM)))
	s.exit_open = s.gems_required <= 0
	return s


static func _check_rows(layer: String, rows: Array, w: int, h: int, errors: PackedStringArray) -> void:
	if rows.size() != h:
		errors.append("%s: expected %d rows, got %d" % [layer, h, rows.size()])
		return
	for y: int in h:
		var row: String = str(rows[y])
		if row.length() != w:
			errors.append("%s: row %d has %d chars, expected %d" % [layer, y, row.length(), w])


## Splits a single combined map (terrain chars plus object/player chars on floor) into the two layers.
## Handy for hand-written test rooms; level files store both layers.
static func from_combined(rows: PackedStringArray, meta: Dictionary = {}) -> Dictionary:
	var terrain: Array[String] = []
	var objects: Array[String] = []
	for row: String in rows:
		var t_row: String = ""
		var o_row: String = ""
		for ch: String in row:
			if ch == PLAYER_CHAR or OBJECT_CHARS.has(ch):
				t_row += EMPTY_CHAR
				o_row += ch
			else:
				t_row += ch
				o_row += EMPTY_CHAR
		terrain.append(t_row)
		objects.append(o_row)
	var width: int = rows[0].length() if rows.size() > 0 else 0
	return {"size": [width, rows.size()], "meta": meta, "layers": {"terrain": terrain, "objects": objects}}

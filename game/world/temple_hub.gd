class_name TempleHub
extends RefCounted
## The temple hub (2026-11-12: "a small 3D world"): a walk-only grid level whose exits are doors to the chambers.
## A door opens once the chamber before it is solved; a seal (a passage) opens once its chamber is solved, so the
## temple grows as you play. Locked doors and closed seals are walls in the starting state, so the sim needs nothing
## new: walking through an open door is just leaving through an exit. Pure: the state comes from the file and the
## set of solved chambers.

const PATH: String = "res://levels/hub/temple.json"


static func data() -> Dictionary:
	return LevelLoader.load_data(PATH)


static func rooms(d: Dictionary) -> Array:
	return (d.get("meta", {}) as Dictionary).get("rooms", []) as Array


## The hub's starting state. `solved` has the solved chambers as keys. If `from_room` is given, the player stands
## just outside its door, so leaving a chamber puts you back where you went in.
static func start_state(solved: Dictionary, from_room: String = "", d: Dictionary = data()) -> SimState:
	var errors := PackedStringArray()
	var s: SimState = LevelCodec.parse(d, errors)
	for e: String in errors:
		push_error("TempleHub: %s" % e)
	if s == null:
		return null
	var list: Array = rooms(d)
	for i: int in list.size():
		var room: Dictionary = list[i]
		var door: Vector2i = _cell(room["door"])
		if i > 0 and not solved.has((list[i - 1] as Dictionary)["level"]):
			s.terrain[s.idx(door)] = Tiles.Terrain.WALL
		if room["level"] == from_room:
			s.player = door + Vector2i.DOWN
	for seal: Dictionary in (d.get("meta", {}) as Dictionary).get("seals", []) as Array:
		if not solved.has(seal["after"]):
			for c: Variant in seal["cells"] as Array:
				s.terrain[s.idx(_cell(c))] = Tiles.Terrain.WALL
	return s


## The chamber whose door is at `cell`, or "".
static func room_at(cell: Vector2i, d: Dictionary = data()) -> String:
	for room: Dictionary in rooms(d):
		if _cell(room["door"]) == cell:
			return room["level"] as String
	return ""


static func _cell(v: Variant) -> Vector2i:
	var a: Array = v as Array
	return Vector2i(int(a[0]), int(a[1]))

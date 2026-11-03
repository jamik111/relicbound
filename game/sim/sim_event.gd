class_name SimEvent
extends RefCounted
## One thing that happened during a tick. The view, VFX, audio and haptics react to these;
## they never read the sim's internals to find out what changed.

enum Type {
	PLAYER_MOVED,      ## cell -> to
	PLAYER_BLOCKED,    ## cell = tile the player bumped into
	DIRT_DUG,          ## cell
	OBJECT_PUSHED,     ## cell -> to, object, id
	OBJECT_FELL,       ## cell -> to (one tile south), object, id
	OBJECT_ROLLED,     ## cell -> to (one tile sideways), object, id
	OBJECT_LANDED,     ## cell, object, id: a moving object came to rest
	GEM_COLLECTED,     ## cell, id, value = gems collected so far
	KEY_COLLECTED,     ## cell, id, value = key colour
	DOOR_OPENED,       ## cell, value = key colour
	EXIT_OPENED,       ## cell = exit tile
	LEVEL_COMPLETED,   ## cell = exit tile
	PLAYER_CRUSHED,    ## cell, object = what fell on the player
}

var type: Type
var cell: Vector2i
var to: Vector2i
var object: int = Tiles.Obj.NONE
var id: int = 0
var value: int = 0


static func make(p_type: Type, p_cell: Vector2i, p_to: Vector2i = p_cell, p_object: int = Tiles.Obj.NONE,
		p_id: int = 0, p_value: int = 0) -> SimEvent:
	var e := SimEvent.new()
	e.type = p_type
	e.cell = p_cell
	e.to = p_to
	e.object = p_object
	e.id = p_id
	e.value = p_value
	return e


func _to_string() -> String:
	return "%s %s->%s obj=%d id=%d v=%d" % [Type.keys()[type], cell, to, object, id, value]

class_name SimEnemy
extends RefCounted
## One enemy: plain data inside SimState, so it's copied, hashed and replayed like everything else.

enum Kind { VIPER = 0, BAT = 1 }

var id: int = 0
var kind: Kind = Kind.VIPER
var cell: Vector2i = Vector2i.ZERO
var dir: Vector2i = Vector2i.RIGHT
## Ticks until the next move.
var timer: int = 0


func copy() -> SimEnemy:
	var e := SimEnemy.new()
	e.id = id
	e.kind = kind
	e.cell = cell
	e.dir = dir
	e.timer = timer
	return e


func to_ints() -> PackedInt32Array:
	return PackedInt32Array([id, kind, cell.x, cell.y, dir.x, dir.y, timer])

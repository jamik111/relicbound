class_name SimEcho
extends RefCounted
## An echo: the ghost of the player's past self, replaying the inputs recorded before an hourglass use.
## Plain data inside SimState, so it's copied, hashed and replayed like everything else.

var id: int = 0
var cell: Vector2i = Vector2i.ZERO
var facing: Vector2i = Vector2i.DOWN
## SimStep.Intent per tick, recorded by the hourglass.
var inputs: PackedInt32Array = PackedInt32Array()
var cursor: int = 0
## Ticks left to hold still after the inputs run out.
var linger: int = 0


func copy() -> SimEcho:
	var e := SimEcho.new()
	e.id = id
	e.cell = cell
	e.facing = facing
	e.inputs = inputs.duplicate()
	e.cursor = cursor
	e.linger = linger
	return e


func to_ints() -> PackedInt32Array:
	var out := PackedInt32Array([id, cell.x, cell.y, facing.x, facing.y, cursor, linger])
	out.append_array(inputs)
	return out

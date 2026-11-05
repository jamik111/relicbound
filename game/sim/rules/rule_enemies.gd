class_name RuleEnemies
extends RefCounted
## Tick phase 5: enemies. No randomness, so they replay exactly.
##
## - Pit viper: patrols a line and turns at anything it can't enter (walls, objects, dirt, pits, idols).
##   A boulder or crate landing on it kills it.
## - Cave bat: flies diagonally straight through walls and objects and bounces off the edges of the map.
##   It can't be killed (the lantern will scare it, later).
## - Touching the player kills, except on an idol, which is a safe spot.
## - Touching an echo destroys the echo and turns the enemy back: an echo can buy time or block a corridor.

const VIPER_MOVE_TICKS: int = 4
const BAT_MOVE_TICKS: int = 3


static func spawn(s: SimState, kind: SimEnemy.Kind, cell: Vector2i, dir: Vector2i) -> void:
	var e := SimEnemy.new()
	e.id = s.next_id
	s.next_id += 1
	e.kind = kind
	e.cell = cell
	e.dir = dir
	e.timer = _period(kind)
	s.enemies.append(e)


static func _period(kind: SimEnemy.Kind) -> int:
	return BAT_MOVE_TICKS if kind == SimEnemy.Kind.BAT else VIPER_MOVE_TICKS


## Returns true if an enemy killed the player this tick.
static func apply(s: SimState, events: Array[SimEvent]) -> bool:
	var killed: bool = false
	for e: SimEnemy in s.enemies.duplicate():
		if e.kind == SimEnemy.Kind.VIPER and _crushed(s, e):
			s.enemies.erase(e)
			events.append(SimEvent.make(SimEvent.Type.ENEMY_CRUSHED, e.cell, e.cell, s.object_at(e.cell), e.id))
			continue
		# Checked before and after moving: the player moves first, so walking into an enemy overlaps here.
		killed = _touches_player(s, e) or killed
		e.timer -= 1
		if e.timer <= 0:
			e.timer = _period(e.kind)
			var from: Vector2i = e.cell
			if e.kind == SimEnemy.Kind.BAT:
				_move_bat(s, e, events)
			else:
				_move_viper(s, e, events)
			if e.cell != from:
				events.append(SimEvent.make(SimEvent.Type.ENEMY_MOVED, from, e.cell, Tiles.Obj.NONE, e.id))
			killed = _touches_player(s, e) or killed
	return killed


static func _crushed(s: SimState, e: SimEnemy) -> bool:
	var obj: int = s.object_at(e.cell)
	return obj == Tiles.Obj.BOULDER or obj == Tiles.Obj.CRATE


static func _touches_player(s: SimState, e: SimEnemy) -> bool:
	if e.cell != s.player or not s.alive:
		return false
	var t: int = s.terrain_at(s.player)
	return t != Tiles.Terrain.CHECKPOINT and t != Tiles.Terrain.CHECKPOINT_LIT


static func _move_viper(s: SimState, e: SimEnemy, events: Array[SimEvent]) -> void:
	if _hit_echo(s, e, e.cell + e.dir, events):
		return
	if not _viper_can_enter(s, e.cell + e.dir):
		e.dir = -e.dir
		if not _viper_can_enter(s, e.cell + e.dir) or _hit_echo(s, e, e.cell + e.dir, events):
			return
	e.cell += e.dir


static func _viper_can_enter(s: SimState, c: Vector2i) -> bool:
	var t: int = s.terrain_at(c)
	return (Tiles.is_floor_like(t) or (t == Tiles.Terrain.GATE and s.gates_open)) and s.object_at(c) == Tiles.Obj.NONE


static func _move_bat(s: SimState, e: SimEnemy, events: Array[SimEvent]) -> void:
	var to: Vector2i = e.cell + e.dir
	if to.x < 0 or to.x >= s.width:
		e.dir.x = -e.dir.x
	if to.y < 0 or to.y >= s.height:
		e.dir.y = -e.dir.y
	if not _hit_echo(s, e, e.cell + e.dir, events):
		e.cell += e.dir


## If an echo is in the way it's destroyed and the enemy turns back. Returns true if so.
static func _hit_echo(s: SimState, e: SimEnemy, c: Vector2i, events: Array[SimEvent]) -> bool:
	var echo: SimEcho = s.echo_at(c)
	if echo == null:
		return false
	RuleEcho.destroy(s, echo, events)
	e.dir = -e.dir
	return true

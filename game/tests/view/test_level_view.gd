extends GutTest
## Task 2.1: LevelView follows the sim (positions, interpolation, collected objects, terrain changes).

const H = preload("res://tests/sim/sim_helpers.gd")

var _view: LevelView


func before_each() -> void:
	_view = LevelView.new()
	_view.player_move_ticks = 1
	add_child_autofree(_view)


func _instances(terrain: int) -> int:
	var node: MultiMeshInstance3D = _view._terrain_nodes.get(terrain) as MultiMeshInstance3D
	return node.multimesh.instance_count if node else 0


func test_build_places_player_and_objects() -> void:
	var s: SimState = H.state(["######", "#@O*.#", "######"])
	_view.build(s)
	assert_eq(_view.player_world_position(), Vector3(1, 0, 1))
	assert_eq(_view._objects.size(), 2)
	assert_eq(_instances(Tiles.Terrain.WALL), 14)


func test_interpolates_between_ticks() -> void:
	var s: SimState = H.state(["#####", "#@..#", "#####"])
	_view.build(s)
	var r: StepResult = H.step(s, H.R)
	_view.show_state(s, r.state, r.events)
	_view.interpolate(0.0)
	assert_eq(_view.player_world_position(), Vector3(1, 0, 1))
	_view.interpolate(0.5)
	assert_almost_eq(_view.player_world_position().x, 1.5, 0.001)
	_view.interpolate(1.0)
	assert_eq(_view.player_world_position(), Vector3(2, 0, 1))


func test_walk_step_spans_the_move_interval() -> void:
	_view.player_move_ticks = 2
	var s: SimState = H.state(["#####", "#@..#", "#####"])
	_view.build(s)
	var moved: StepResult = H.step(s, H.R)
	_view.show_state(s, moved.state, moved.events)
	_view.interpolate(1.0)
	assert_almost_eq(_view.player_world_position().x, 1.5, 0.001, "halfway after one of two ticks")
	var idle: StepResult = H.step(moved.state)
	_view.show_state(moved.state, idle.state, idle.events)
	_view.interpolate(1.0)
	assert_almost_eq(_view.player_world_position().x, 2.0, 0.001)


func test_player_faces_its_direction() -> void:
	var s: SimState = H.state(["#####", "#@..#", "#####"])
	_view.build(s)
	var r: StepResult = H.step(s, H.R)
	_view.show_state(s, r.state, r.events)
	_view.interpolate(1.0)
	assert_almost_eq(_view._player.rotation.y, PI / 2.0, 0.001)


func test_exit_and_doors_get_labels() -> void:
	_view.build(H.state(["######", "#@RE.#", "######"]))
	assert_eq(_view._labels.size(), 2)


func test_falling_object_moves_by_id() -> void:
	var s: SimState = H.state(["#####", "#@O.#", "#...#", "#####"])
	_view.build(s)
	var id: int = s.ids[s.idx(Vector2i(2, 1))]
	var r: StepResult = H.step(s)
	_view.show_state(s, r.state, r.events)
	_view.interpolate(1.0)
	assert_eq((_view._objects[id] as Node3D).position, Vector3(2, 0, 2))


func test_collected_gem_is_removed() -> void:
	var s: SimState = H.state(["#####", "#@*.#", "#####"])
	_view.build(s)
	var r: StepResult = H.step(s, H.R)
	_view.show_state(s, r.state, r.events)
	assert_eq(_view._objects.size(), 0)


func test_dug_dirt_rebuilds_terrain() -> void:
	var s: SimState = H.state(["#####", "#@::#", "#####"])
	_view.build(s)
	assert_eq(_instances(Tiles.Terrain.DIRT), 2)
	var r: StepResult = H.step(s, H.R)
	_view.show_state(s, r.state, r.events)
	assert_eq(_instances(Tiles.Terrain.DIRT), 1)

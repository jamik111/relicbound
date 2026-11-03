extends GutTest
## Task 1.1: SimState create / copy / hash / RNG, and SimStep purity.

const H = preload("res://tests/sim/sim_helpers.gd")


func test_create_defaults() -> void:
	var s: SimState = SimState.create(5, 4)
	assert_eq(s.terrain.size(), 20)
	assert_eq(s.objects.count(Tiles.Obj.NONE), 20)
	assert_eq(s.terrain.count(Tiles.Terrain.FLOOR), 20)
	assert_true(s.alive)
	assert_eq(s.tick, 0)


func test_out_of_bounds_reads_as_wall() -> void:
	var s: SimState = SimState.create(3, 3)
	assert_eq(s.terrain_at(Vector2i(-1, 0)), Tiles.Terrain.WALL)
	assert_eq(s.terrain_at(Vector2i(0, 3)), Tiles.Terrain.WALL)


func test_copy_is_independent() -> void:
	var a: SimState = H.state(["#####", "#@O.#", "#####"])
	var b: SimState = a.copy()
	b.terrain[0] = Tiles.Terrain.FLOOR
	b.move_object(Vector2i(2, 1), Vector2i(3, 1))
	b.keys[0] = 5
	assert_eq(a.terrain[0], Tiles.Terrain.WALL)
	assert_eq(H.obj(a, 2, 1), Tiles.Obj.BOULDER)
	assert_eq(a.keys[0], 0)


func test_hash_equal_for_equal_states() -> void:
	var a: SimState = H.state(["#####", "#@O*#", "#####"])
	assert_eq(a.hash(), a.copy().hash())
	assert_eq(a.hash(), H.state(["#####", "#@O*#", "#####"]).hash())


func test_hash_changes_with_state() -> void:
	var a: SimState = H.state(["#####", "#@O.#", "#####"])
	var b: SimState = a.copy()
	b.tick += 1
	var c: SimState = a.copy()
	c.set_moving(Vector2i(2, 1), true)
	assert_ne(a.hash(), b.hash())
	assert_ne(a.hash(), c.hash())


func test_rng_is_seeded_and_copied() -> void:
	var a: SimState = SimState.create(1, 1, 42)
	var b: SimState = SimState.create(1, 1, 42)
	var seq_a: Array[int] = []
	var seq_b: Array[int] = []
	for i: int in 5:
		seq_a.append(a.rand_int(1000))
		seq_b.append(b.rand_int(1000))
	assert_eq(seq_a, seq_b)
	var c: SimState = a.copy()
	assert_eq(a.rand_int(1000), c.rand_int(1000))
	assert_ne(SimState.create(1, 1, 7).rand_int(1_000_000), SimState.create(1, 1, 8).rand_int(1_000_000))


func test_step_does_not_modify_input() -> void:
	var s: SimState = H.state(["#####", "#@:O#", "#...#", "#####"])
	var before: String = s.hash()
	H.step(s, H.R)
	assert_eq(s.hash(), before)


func test_step_is_deterministic() -> void:
	var s: SimState = H.state(["#######", "#@:O..#", "#.:...#", "#######"])
	assert_eq(H.run(s, "RDRRU.L").hash(), H.run(s, "RDRRU.L").hash())


func test_tick_advances_every_step() -> void:
	var s: SimState = H.state(["###", "#@#", "###"])
	assert_eq(H.run(s, "...").tick, 3)

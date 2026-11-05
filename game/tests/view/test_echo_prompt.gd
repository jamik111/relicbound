extends GutTest
## The hourglass prompt appears only at the teaching moment: holding a plate, in a room that teaches it.

const H = preload("res://tests/sim/sim_helpers.gd")
const Level = preload("res://scenes/level.gd")


func _on_plate() -> SimState:
	return H.step(H.state(["#####", "#@P.#", "#####"]), H.R).state


func test_prompts_on_a_plate_in_a_teaching_room() -> void:
	assert_true(Level.should_prompt_echo(_on_plate(), true, 3))


func test_no_prompt_off_the_plate() -> void:
	assert_false(Level.should_prompt_echo(H.state(["#####", "#@P.#", "#####"]), true, 3))


func test_no_prompt_outside_teaching_rooms() -> void:
	assert_false(Level.should_prompt_echo(_on_plate(), false, 3))


func test_no_prompt_without_charges() -> void:
	assert_false(Level.should_prompt_echo(_on_plate(), true, 0))


func test_no_prompt_once_an_echo_is_active() -> void:
	var s: SimState = RuleEcho.spawned(_on_plate(), PackedInt32Array())
	assert_false(Level.should_prompt_echo(s, true, 3))

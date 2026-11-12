extends GutTest
## The temple hub: doors open as chambers are solved, seals open the next gallery, and walking through a door
## enters its chamber. Leaving a chamber puts you back outside its door.

const SAVE_PATH: String = "user://test_hub_save.json"
const GREYBOX: String = "res://levels/greybox/"


func before_each() -> void:
	Save.path = SAVE_PATH
	Save.load_save()
	Game.hold_delay_ticks = 0


func after_each() -> void:
	Game.hold_delay_ticks = Game.HOLD_DELAY_TICKS
	Game.hub_return_room = ""
	Game.release_all()
	Game.stop()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	Save.path = Save.PATH
	Save.load_save()


func _room(i: int) -> String:
	return (TempleHub.rooms(TempleHub.data())[i] as Dictionary)["level"] as String


func _door(i: int) -> Vector2i:
	var a: Array = (TempleHub.rooms(TempleHub.data())[i] as Dictionary)["door"] as Array
	return Vector2i(int(a[0]), int(a[1]))


func test_every_chamber_has_one_door_in_order() -> void:
	var levels: PackedStringArray = LevelLoader.levels_in(GREYBOX)
	var rooms: Array = TempleHub.rooms(TempleHub.data())
	assert_eq(rooms.size(), levels.size())
	for i: int in rooms.size():
		assert_eq((rooms[i] as Dictionary)["level"], levels[i])
		assert_not_null(LevelLoader.load_state(levels[i]))


func test_a_new_temple_opens_only_the_first_door() -> void:
	var s: SimState = TempleHub.start_state({})
	assert_eq(s.terrain_at(_door(0)), Tiles.Terrain.EXIT)
	assert_eq(s.terrain_at(_door(1)), Tiles.Terrain.WALL)
	assert_eq(s.terrain_at(Vector2i(9, 7)), Tiles.Terrain.WALL, "the passage to the next gallery is sealed")


func test_solving_a_chamber_opens_the_next_door() -> void:
	var s: SimState = TempleHub.start_state({_room(0): true})
	assert_eq(s.terrain_at(_door(1)), Tiles.Terrain.EXIT)
	assert_eq(s.terrain_at(_door(2)), Tiles.Terrain.WALL)


func test_the_third_chamber_unseals_the_next_gallery() -> void:
	var solved: Dictionary = {_room(0): true, _room(1): true, _room(2): true}
	var s: SimState = TempleHub.start_state(solved)
	assert_eq(s.terrain_at(Vector2i(9, 7)), Tiles.Terrain.FLOOR)
	assert_eq(s.terrain_at(_door(3)), Tiles.Terrain.EXIT)
	assert_eq(Replay.run(s, "UU UUU").player, Vector2i(9, 5), "up into the second gallery, and the next seal holds")


func test_leaving_a_chamber_puts_you_outside_its_door() -> void:
	assert_eq(TempleHub.start_state({_room(0): true}, _room(1)).player, _door(1) + Vector2i.DOWN)


func test_walking_through_the_first_door_enters_it() -> void:
	var s: SimState = Replay.run(TempleHub.start_state({}), "LLLLLLU")
	assert_true(s.won)
	assert_eq(TempleHub.room_at(s.player), _room(0))


func test_game_enters_the_chamber_and_marks_it_solved_on_a_win() -> void:
	assert_true(Game.load_level(TempleHub.PATH))
	Game.stop()
	for intent: SimStep.Intent in [SimStep.Intent.LEFT, SimStep.Intent.LEFT, SimStep.Intent.LEFT,
			SimStep.Intent.LEFT, SimStep.Intent.LEFT, SimStep.Intent.LEFT, SimStep.Intent.UP]:
		Game.press(intent)
		Game.release(intent)
		Game._advance()
	await get_tree().process_frame
	assert_eq(Game.level_path, _room(0))
	assert_false(Save.is_solved(_room(0)))
	assert_true(Game.load_hub())
	assert_eq(Game.state.player, _door(0) + Vector2i.DOWN, "back outside the door")
	assert_eq(Game.state.terrain_at(_door(1)), Tiles.Terrain.WALL, "not solved yet")
	Save.mark_solved(_room(0))
	assert_true(Game.load_hub())
	assert_eq(Game.state.terrain_at(_door(1)), Tiles.Terrain.EXIT)

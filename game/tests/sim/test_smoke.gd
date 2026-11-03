extends GutTest
## Sprint 0 smoke test: proves the headless GUT pipeline runs. Replaced by real sim tests in Sprint 1.


func test_project_settings() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")
	assert_eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "mobile")


func test_autoloads_present() -> void:
	for autoload_name: String in ["Events", "Settings", "Save", "Game"]:
		assert_not_null(get_tree().root.get_node_or_null(autoload_name), autoload_name)


func test_tick_rate() -> void:
	assert_eq(Game.TICK_RATE_HZ, 10)

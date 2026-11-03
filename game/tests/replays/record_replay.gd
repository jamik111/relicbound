extends SceneTree
## Re-records a golden replay's expected hash after an intended rule change.
## Usage: godot --headless --path game -s res://tests/replays/record_replay.gd -- res://tests/replays/<file>.json
## Check the printed final state before committing: a changed hash means the rules changed behaviour.


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: ... -s res://tests/replays/record_replay.gd -- <replay.json>")
		quit(1)
		return
	for path: String in args:
		var replay: Dictionary = LevelLoader.load_data(path)
		var start: SimState = LevelLoader.load_state(replay["level"] as String)
		if start == null:
			quit(1)
			return
		var final_state: SimState = Replay.run(start, replay["inputs"] as String)
		var old_hash: String = replay.get("hash", "") as String
		replay["hash"] = final_state.hash()
		var expect: Dictionary = replay.get("expect", {}) as Dictionary
		for key: String in expect:
			if expect[key] is float:
				expect[key] = int(expect[key])  # keep "tick": 22, not 22.0
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(replay, "\t", false) + "\n")
		file.close()
		print("%s\n  tick=%d won=%s alive=%s gems=%d player=%s\n  hash %s -> %s" % [
			path, final_state.tick, final_state.won, final_state.alive, final_state.gems_collected,
			final_state.player, old_hash if old_hash != "" else "(none)", final_state.hash()])
	quit(0)

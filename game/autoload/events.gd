extends Node
## Global signal bus. The sim never emits here directly: Game forwards each tick's
## event array, and the view/VFX/audio layers listen. Nothing listening may change sim state.

## Emitted once per sim tick with that tick's events (Array of sim event objects).
signal sim_events(tick: int, events: Array)

## Emitted after the sim advances one tick (after sim_events).
signal sim_ticked(tick: int)

## Emitted when Game loads or restarts a level: views rebuild from Game.state.
signal level_loaded()

signal quality_tier_changed(tier: int)
signal settings_changed()

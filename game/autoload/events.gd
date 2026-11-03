extends Node
## Global signal bus. The sim never emits here directly: Game forwards each tick's
## event array, and the view/VFX/audio layers listen. Nothing listening may change sim state.

## Emitted once per sim tick with that tick's events (Array of sim event objects).
signal sim_events(tick: int, events: Array)

## Emitted after the sim advances, with the interpolation alpha left for rendering.
signal sim_ticked(tick: int)

signal quality_tier_changed(tier: int)
signal settings_changed()

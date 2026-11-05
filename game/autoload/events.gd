extends Node
## Global signal bus. The sim never emits here directly: Game forwards each tick's
## event array, and the view/VFX/audio layers listen. Nothing listening may change sim state.

## Emitted once per sim tick with that tick's events (Array of sim event objects).
signal sim_events(tick: int, events: Array)

## Emitted after the sim advances one tick (after sim_events).
signal sim_ticked(tick: int)

## Emitted when Game loads or restarts a level: views rebuild from Game.state.
signal level_loaded()

## Game.state was swapped for an earlier one (rewind or respawn): views rebuild without ticking.
signal state_replaced()
## The hourglass was used (RewindUsed in the art pipeline's VFX table).
signal rewound(charges_left: int)
## The player respawned at the last checkpoint after being crushed.
signal respawned()

signal quality_tier_changed(tier: int)
signal settings_changed()

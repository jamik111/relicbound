# 01 — Genre Analysis: what we are making (and what we are not)

## The reference point
*Diamond Rush* (2006, J2ME phones) is a **top-down, tile-based action-puzzle adventure**. Its DNA:

| Pillar | How it worked | Lineage |
|---|---|---|
| Grid movement | Hero moves tile-by-tile in 4 directions, real-time | Boulder Dash, Chip's Challenge |
| Falling-object physics | Boulders/diamonds "fall" toward the bottom of the screen, roll off round objects, crush the player | Boulder Dash |
| Pushing | Push one boulder sideways if the far tile is empty | Sokoban |
| Lock-and-key | Colored keys, doors, switches, pressure plates | Zelda dungeons |
| Hazards | Spikes, fire jets, arrow traps, collapsing floors, water | Tomb-raider pulp |
| Enemies | Simple pattern enemies (snakes, spiders, bats), a boss per world | Arcade |
| Collect & secrets | Diamonds open the exit; hidden rooms hold rare gems | Metroidvania-lite |
| Settings | Exotic real-world ruins (temple, castle, mountain) | Indiana Jones pulp |

**Why it was fun:** you could read every level as a puzzle, but it was played in real time, so you got the
"*the ceiling is coming down, RUN*" adventure feeling. Short levels with checkpoints suited phones well.

## The genre we're making
> **Pulp-adventure action-puzzler**: a top-down 2.5D game where you explore and discover things in hand-built
> ruins. The puzzles come from a grid simulation that always behaves the same way, and the pacing feels like
> an adventure film.

Neighbours: Diamond Rush, Boulder Dash, *Lara Croft GO*, *Tunic* (secrets and how they're shown), *Link's
Awakening* (dungeon flow), *Spelunky* (dangers built from the systems).

## What we keep (genre contract with the player)
1. Grid-locked movement and a **simulation that always resolves the same way.** Every death is your fault and can be learned from.
2. Falling/rolling objects as the core verb set: push, dig, drop, crush, chain-react.
3. Short levels (3–8 min) with checkpoints, so it plays well on phones.
4. Secrets everywhere, plus a reason to come back and finish a level 100%.
5. Exotic ancient places and a pulp adventure tone.

## What we change (so it is ours, and better)
| Area | Old way | Relicbound |
|---|---|---|
| Visuals | 128×160 sprites | 2.5D dioramas: low-poly 3D tiles, dynamic torch light, pixel-art VFX layer, tilt-shift camera |
| Settings | Temple / castle / mountain | 5 original sites (jungle cenote, desert necropolis, glacier barrow, volcanic forge, sunken clockwork city), each with **its own simulation element** (water, sand, ice, lava, gears) |
| Tools | Few items | **Relic Kit**: grapple whip, lantern, pick, chalk, decoy idol. Each one adds a new verb and new puzzles |
| Story | Barely any | A full pulp story with characters, journal entries and cutscenes between worlds |
| Mistakes | Restart from checkpoint | Checkpoints **plus** a limited *Hourglass Rewind* that undoes the last 3 seconds. The sim always resolves the same way, so this is cheap to build |
| Discovery | Collect diamonds | A **Cartographer's Journal**: rooms map themselves as you explore, glyph clues hint at secrets, and lore pages fill in the history |
| Controls | Phone keypad | Swipe/hold virtual stick on touch, keyboard, gamepad. Movement is buffered so tight timing feels fair |
| Replay | Gem count | Gem %, secrets, a par time, a "no rewind" badge, and a daily challenge room built from rules |

## What we will NOT do
- No copying of the original's levels, sprites, names, music or maps.
- No energy timers or pay-to-win (see BRD).
- No free-form physics in the puzzles. Jolt is used **only for cosmetic** debris and ragdolls, never for rules.

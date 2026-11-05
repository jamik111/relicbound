# 05 — Game Design: Mechanics & Systems

## Camera & view
Top-down 2.5D. Orthographic camera tilted 35° away from straight down (55° below the horizon) and slightly
rotated (5°), so walls have visible faces. (35° above the horizon was tried: 1-tile walls then hid the tiles behind them.)
"Gravity" in the sim points **south (screen-down)**. The 3D tilt makes this read as "rolling down a slope" into
the room. Levels are 16×12 to 64×48 tiles, split into rooms joined by doors and checkpoints.

## Simulation tick (the heart of the game)
- 10 ticks/s by default (assist mode: 6). The player walks at most 1 tile per 2 ticks (5 tiles/s; playtest 1: 10 tiles/s
  was too fast near hazards). Falling and rolling objects still move 1 tile per tick (10 tiles/s).
- Order within one tick: **1) player intent → 2) tools → 3) falling/rolling objects (scanned bottom-to-top,
  left-to-right) → 4) element flows (water/sand/lava) → 5) enemies → 6) triggers → 7) damage resolve.**
- Each object has a `moving` flag. A falling object kills only if `moving == true` when it enters the
  player's tile. Standing under a resting boulder is safe, as genre veterans expect.
- The state is plain data, so it can be hashed, serialized for rewind and saves, and replayed in CI.

### Rule details (settled in Sprint 1; the GUT tests in `game/tests/sim/` are the reference)
- **Pushing:** boulders push sideways only; crates push in all 4 directions. One object at a time (no chain
  pushes). A moving object can't be pushed, and the far tile must be open floor (not dirt). A pushed object
  doesn't also fall in the same tick; it falls on the next one.
- **Rolling:** a round object (boulder, gem) on a resting round object rolls **west first, then east**, only if
  the side tile and the tile below it are both open. Nothing rolls off crates, and crates never roll.
- **Gems:** walking into a gem collects it; a falling gem landing on the player is caught (never deadly).
  The quota defaults to every gem in the level.
- **Keys & doors:** red ♦, blue ●, gold ▲, jade ■. Walking into a door with a matching key opens it and uses
  up the key. Keys don't fall.
- **Exit:** opens on the tick the quota is met (one `EXIT_OPENED` event); stepping onto it completes the level.
- **Checkpoint idol:** lights when the player steps on it (stays lit). The room is saved only once nothing in it is
  moving, so a respawn can't drop a boulder on you. Idols are safe spots: objects can't enter them, nothing falls on
  a player standing on one, and they stop darts. 1.0 s after dying, the player respawns into the last save (or the level start).
- **Hourglass:** one use jumps back up to 30 ticks (3 s) before the last move, even mid-fall or after being crushed, and leaves an echo. 3 uses per level;
  dying gives back the uses you had at your last checkpoint (the echoes they made are gone, and a room needing an echo
  would otherwise become unwinnable).
- **Hazard timing** (all derived from the tick, 10 ticks/s): spikes cycle every 3 s (2 s down, 0.5 s warning, 0.5 s up),
  with a second phase half a cycle later; dart walls fire every 3 s after a 0.5 s warning, along their row until a
  solid tile or any object. Cracked floor collapses at the start of the tick after you step off. A boulder, crate
  or gem entering a pit fills it. Walking into a pit kills.

## Echoes: the signature mechanic (prototype, chosen after playtest 1)
**Rewinding doesn't erase what you did. Your past self keeps doing it.** Using the hourglass jumps time back up to
3 seconds before your last move, and your earlier self replays those exact inputs as a ghost while you act freely. You cooperate with
yourself: this is what makes Relicbound more than another boulder puzzler.
- **An echo can:** walk, push boulders and crates, dig dirt, weigh down pressure plates.
- **An echo can't:** take gems or keys (it passes through them), open keyed doors or the exit, light idols, or hold
  objects up. The player walks through it.
- **Blind replay:** if the world has changed, it replays its inputs anyway and may bump into things.
- **Lifetime:** after its replay it holds still for 5 s, then fades. A boulder or crate landing on it, a dart, a pit or
  risen spikes destroy it, so it can take a hit for you.
- **Limit:** 3 hourglass uses per level; each one leaves an echo, so up to 3 can overlap.
- **Pressure plates and gates:** gates are open only while every plate in the level is weighed down (player, echo, boulder
  or crate), and won't close on someone standing in one.
- **Thinking is free:** time spent standing still doesn't count, so you can stop and plan before tapping (found in
  playtest: pausing 3 s used to leave a ghost with nothing to replay). History lasts 60 s of standing still.
- **Not proven yet:** the numbers (3 s back, 5 s hold) are starting values to tune in playtests.

## The temple remembers (prototype, from playtest 2)
**Dying isn't a clean retry.** You get to play first, but the room remembers how you failed and won't let the same
attempt happen twice. Levels opt in with `meta.remembers`; levels 1–6 stay clean teachers. `meta.rewinds` sets a level's
hourglass uses.
- **Scar:** a solid red statue stands on the cell where you died. It blocks you, echoes and falling objects, stops darts
  and holds down a plate for good. At most 3 last; the oldest goes first. Using the hourglass before you respawn undoes
  the death, so it leaves no scar.
- **Remnant:** a red ghost replays your failed attempt from the moment you respawn, without your long pauses. It follows
  echo rules, so it pushes what you pushed and briefly holds plates. It can also end up somewhere new: a scar can stop it
  short of where you died.
- **Where you die is a move.** Scars can open a gate, shield a corridor from darts or block your only route. Level 7 is
  built on this: both plates must be held, and dying on the near one first walls off the far one.
- **Scars stay (playtest 3: a free wipe was too easy, and the cost has to help retention):** they're saved, so Restart,
  leaving the level and closing the game all keep them. An unfinished room waiting for you is the reason to come back.
  Winning the level clears them.
- **Forget, the way out:** spending one wipes a level's scars, so scars can't trap you for good. You start with 1 and
  hold at most 3. Winning any level earns 1, replays included, so a player with none can always earn one. No timers or
  payments: the BRD rejects energy systems, and a daily refill would be one. **Not proven yet:** an early level is a
  cheap source of Forgets, so this cost may prove too low.
- **Fairness:** a level that remembers has to be checked for dead ends. Tests search level 7 exhaustively without
  remnants, and a separate test confirms a second route where a remnant holds the near plate. The system doesn't yet check that an arbitrary room stays winnable, so it can't be turned on for every level.
- **Not built yet:** rooms that change their own layout in response to how you fail. That needs a solver that can
  prove each changed room is still winnable.

## Core tiles & objects
| Tile/Object | Behaviour |
|---|---|
| Floor | Walkable |
| Wall / Ancient wall | Solid; ancient walls break with the Pick |
| Dirt / Moss | Walkable; disappears when stepped on (dig). Supports objects above it |
| Boulder (round) | Falls; rolls off round things; pushable sideways |
| Crate (square) | Falls; does **not** roll; pushable; floats in water; burns in lava |
| Gem (round) | Falls/rolls like a boulder, is collected on touch, and is safe to catch (it never kills) |
| Red Sunshard | Rare gem in secrets; counts toward 100% |
| Key / Door | 4 colours, each with a unique shape (♦ ● ▲ ■) for colour-blind players |
| Pressure plate | Active while weighed down (by the player, an echo, a crate, a boulder or the decoy idol). Opens gates |
| Spike trap | Timed or proximity; telegraphs for 0.5 s |
| Dart wall | Fires along a row on a timer; blocked by any object |
| Cracked floor | Collapses one tick after you step off it; becomes a pit |
| Pit | Fill it with a boulder or crate to make floor |
| Checkpoint idol | Lights up; saves room state |
| Secret wall | Faint crack; opens with the Pick or a falling boulder |

## Relic Kit (story-gated tools)
| Tool | Unlock | Verb | Puzzle uses |
|---|---|---|---|
| Satchel | Start | Carry keys/gems | — |
| **Grapple-whip** | W1 L3 | Pull an object 1 tile toward you, or swing over a pit to an anchor post | Pulling boulders off ledges, crossing gaps |
| **Lantern** | W1 L8 | Lights a radius in dark rooms; scares bats; lights braziers | Dark mazes, light puzzles (W2 mirrors) |
| **Pick** | W2 L4 | Breaks ancient walls/secret walls in front of you (1 s use) | Digging new paths, triggering cave-ins |
| **Chalk** | W2 L9 | Mark a tile (max 5) — persists in journal map | Player-made notes; required for one memory puzzle per world |
| **Decoy Idol** | W3 L5 | Drop it to weigh down a plate or lure an enemy, then pick it back up | Classic plate puzzles, enemy routing |

## World elements (one new sim layer per world)
| World | Element | Rules |
|---|---|---|
| 1 Jade Cenote | **Water** | Water spreads into empty tiles one tile per tick from sources. Crates float and drift with the current. The player can wade 1 deep and drowns at 2 deep after 3 s. Floodgate levers |
| 2 Qadir | **Sand** | Sand falls like gems but piles at 45°. It flows through grates. Quicksand slows the player to half speed and sinks crates. Mirrors + light beams open sun doors |
| 3 Hrimfjall | **Ice** | Anything on ice slides until blocked. Freezing braziers turn water into ice bridges. Thin ice breaks after 2 crossings |
| 4 Ember Forge | **Lava** | Lava flows like slow water (1 tile / 3 ticks). Lava + water → basalt floor. Crates burn. Heat tiles pulse on a rhythm |
| 5 Meridian Core | **Gears/Time** | Rotating room sections turn 90° when a lever is pulled, and gravity is relative to the room. Some tiles move only on the beat (every 4 ticks). Inside time bubbles, falling objects hang until the bubble pops |

## Enemies
> **Open design problem (playtest 1):** the viper and bat work, but they're "not impressive" and "feel like a distraction".
> **Rule: no level uses an enemy until it has a real puzzle purpose tied to Echoes.** The table below is the original plan and
> is not a commitment. Ideas to try, none chosen yet:
> - **Bait:** enemies chase the nearest echo rather than you, so you lure them with your past self.
> - **Living switch:** a viper's weight holds a plate as it passes, making a moving timer you plan echoes around.
> - **Time-blind guard:** a sentinel that only sees the present, so it reacts to echoes in a way you can exploit.

| Enemy | World | Behaviour | Counter |
|---|---|---|---|
| Pit viper | 1+ | Patrols a line at half walking speed, turns at walls and objects | Crush it, block it with a crate, or sacrifice an echo to turn it back |
| Cave bat | 1+ | Flies diagonally, ignores walls and objects, bounces off the map edge | Lantern scares it away; an echo in its path turns it back |
| Scarab swarm | 2 | Follows your trail 5 tiles behind | Lead it under falling sand |
| Mummified sentinel | 2 | Wakes when you're in line of sight, then chases (A* on the grid) | Doors, boulders, decoy |
| Ice wolf | 3 | Slides on ice toward you | Make it slide into spikes or water |
| Magma slug | 4 | Leaves a lava trail | Water, crushing |
| Gilded Compass agent | 2–5 | Races you for the exit gems (an NPC "rival run") | Outsmart it: block its route |
| Clockwork sentry | 5 | Moves only on the beat | Read the rhythm |

Paths are always shown (playtest 1: without them enemies felt random): dots along a viper's patrol line and a bat's next
cells. Bats move slower than walking. Enemies kill on touch, except on an idol. An enemy that touches an echo destroys it and turns back.

## Level beat structure (template)
1. **Hook room:** see the exit or treasure, but you can't reach it.
2. **Teach:** a safe room that shows the new mechanic.
3. **Test:** use it under light pressure.
4. **Twist:** combine it with an older mechanic.
5. **Trap/chase:** a timed escape (rolling boulder, flood, collapse).
6. **Reward:** exit. A secret branch is hidden in step 3 or 4.

## Difficulty & fairness rules
- **Logic before looks (playtest 1):** the wow has to come from what you figure out. Early levels teach one idea each;
  later ones make you plan 2–3 steps ahead, and the order of your actions is the puzzle.
- Everything that can kill you telegraphs for ≥ 0.4 s, or is visible before it becomes a threat.
- No "leap of faith" off-screen. The camera always shows the tiles you could move to.
- No unwinnable state without an obvious signal. When the sim detects that the exit gems can't be reached, a
  "Rewind or Restart room?" prompt appears.
- Every level has a solution checked by the solver plus a human-written solution video kept internally.

## Scoring & rewards
Per level: Gems (x/y) · Sunshards · Relic (if any) · Time vs par · Rewinds used.
Badges: *Untouched* (no rewind), *Cartographer* (every room seen), *Swift* (under par).
Stars aren't used. Collectibles drive progress: 60% of gems across a world unlocks its boss.

## Controls
- **Touch:** swipe-and-hold (default) or a floating virtual stick. Tool and Hourglass buttons under the right thumb (playtest 1: the Hourglass is the core verb, and players missed it at the top of the screen). Menu buttons stay at the top.
- **Keyboard:** WASD/arrows, Space = tool, Q/E = switch tool, R = rewind, Backspace = restart room, Esc = pause.
- **Gamepad:** stick/D-pad, A = tool, LB/RB = switch, Y = rewind.
- Input buffer: the last direction pressed before the next allowed step wins, so a quick tap is never lost.

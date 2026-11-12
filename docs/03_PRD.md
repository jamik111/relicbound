# 03 — Product Requirements Document (PRD)
**Product:** Twicefall (Steam) · **Version:** 0.2 (platform and audience updated 2026-11-12) · **Owner:** Product · **Status:** Draft

## 1. Problem statement
Players who loved quick-session puzzle-adventure games on feature phones have no modern, fair, beautiful
equivalent that works in one tap on today's phones. Existing puzzle games are either slow-paced (turn-based
GO games) or built around energy systems and paid boosts.

## 2. Goals
- G1: A 5-minute level should feel like a scene from an adventure film: explore, a puzzle, a trap, an escape.
- G2: Every death is readable and fair, because the simulation always behaves the same way.
- G3: A polished Steam game (Windows, Steam Deck): first level within 5 s of launch, full offline play, keyboard and gamepad first.
- G4: Discovery is rewarded: secrets, lore and a journal that fills in as you play.

## 3. Non-goals (v1.0)
Mobile (any platform) · web demo · multiplayer · user-made levels (post-launch) · open world · free-form physics puzzles · gacha or energy systems.

## 4. Personas
| Persona | Need | Design response |
|---|---|---|
| **Puzzle fan Kamila** (31, PC, loved Baba Is You) | Puzzles that make her think 2–3 steps ahead | Echoes, the temple remembers, no filler levels |
| **Completionist Arda** (24, Steam Deck) | 100% everything | Achievements, secrets, par times |
| **Curious Leo** (19, PC, new to the genre) | Not get stuck | Clear rules, hints, Forgets, assist mode |

## 5. User stories & acceptance criteria (P0 = launch-blocking)

### Core play
| ID | Story | Priority | Acceptance criteria |
|---|---|---|---|
| CP-1 | As a player I move tile-by-tile in 4 directions | P0 | Holding a direction repeats at 5 tiles/s (one step per 2 ticks; tuned in playtest 1); inputs are buffered for 120 ms; one move per sim tick |
| CP-2 | I can push a boulder or crate | P0 | It pushes only if the far tile is empty; there's a 0.15 s "lean" before the first push so taps don't push by accident |
| CP-3 | Boulders and gems fall and roll | P0 | Gravity follows the GDD rules; stacked rocks roll off round objects; a falling object kills the player only when it was already moving |
| CP-4 | I collect gems to open the exit | P0 | The HUD shows gems/required; the exit animates when the quota is met |
| CP-5 | I die and respawn quickly | P0 | Death to control takes ≤ 1.2 s; I restart at the last checkpoint with that room's state restored |
| CP-6 | I rewind mistakes | P0 | Hourglass undoes 3 s of sim; 3 charges per level (+1 with a rewarded ad on the web); the "Untouched" badge requires 0 uses |
| CP-7 | I use Relic Kit tools | P0 | Tools unlock as the story goes; contextual button on touch; tool rules in the GDD |
| CP-8 | I fight bosses | P0 | Each boss is a puzzle arena with 3 phases, a telegraph ≥ 0.6 s before each attack, and a checkpoint per phase |

### Discovery & progression
| ID | Story | Priority | Acceptance criteria |
|---|---|---|---|
| DP-1 | The map fills in as I explore | P0 | Rooms are revealed on entry; secret walls show a faint crack |
| DP-2 | I find secrets and relics | P0 | 3 relics per world; level select shows ✓ per collectible |
| DP-3 | I read Thorne's notes as hints | P1 | One per level; can be opened any time from the pause menu |
| DP-4 | I see my stats per level | P1 | Gems %, secrets, time vs par, rewinds used |
| DP-5 | I play a daily challenge room | P2 | Built from rules using a date seed and the FastNoise2 layout; solver-verified; local leaderboard |

### Platform & meta
| ID | Story | Priority | Acceptance criteria |
|---|---|---|---|
| PM-1 | I install it from Google Play and play offline | P0 | Base `.aab` ≤ 150 MB; cold start to level 1 ≤ 8 s on the reference phone; no network needed after install |
| PM-2 | I can try a demo in my browser | P2 | World 1 web demo (Compatibility renderer) ≤ 40 MB; ends with a "Get it on Google Play" button |
| PM-3 | My progress syncs | P1 | Local save is the source of truth; optional account sync; conflicts resolve by most progress |
| PM-4 | I buy the full game once | P0 | Native IAP on the stores; Stripe or a portal SDK on the web; restore purchase works |
| PM-5 | I control it my way | P0 | Keyboard and gamepad first; touch (joystick, swipe or stick) kept only as an option; keyboard; gamepad. Every control can be remapped |
| PM-6 | It's accessible | P1 | Colour-blind safe key colours (shape + colour), subtitles, reduce-motion, assist mode (slower sim, more rewinds) |
| PM-7 | It's in my language | P1 | All strings in an i18n table; 9 launch languages |

## 6. Functional requirements by system
1. **Simulation:** fixed tick (default 10 Hz), integer grid. Updating it is a pure function: `step(state, inputs) → state`. It keeps a ring buffer of the last 30 states for rewind. No floats in the rules.
2. **Renderer:** draws the sim with smoothing between ticks. 2.5D orthographic camera at 35°, dynamic lights, VFX layer.
3. **Level format:** JSON or a text grid with layers (terrain, objects, triggers, scripts). It loads from versioned asset packs.
4. **Level editor (internal):** a browser tool with paint, place, test, and a "solve" check using a BFS solver on simplified rules.
5. **Save:** IndexedDB on the device, plus an optional cloud endpoint.
6. **Analytics:** events `level_start`, `death{cause,x,y}`, `rewind`, `level_complete{time,gems,secrets}`, `purchase`. Privacy-first: no personal data, and consent required in the EU.

## 7. Non-functional requirements
| Area | Requirement |
|---|---|
| Performance | 60 fps on Snapdragon 7-series / iPhone 11; 30 fps "Lite" tier; ≤ 150 draw calls per frame |
| Memory | ≤ 400 MB RAM on Android |
| Size | Base `.aab` ≤ 150 MB; extra worlds via Play Asset Delivery if needed; web demo ≤ 40 MB |
| Load | Switching worlds ≤ 3 s once cached |
| Reliability | Crash-free sessions ≥ 99.5% |
| Determinism | The same inputs give the same state hash on every platform (CI replay test) |

## 8. Success metrics
North star: **levels completed per weekly active player**. Supporting metrics: per-level completion funnel
(alert if < 70%), deaths per level, rewind usage, demo→unlock conversion, D1/D7/D30.

## 9. Release plan
See `08_ROADMAP.md`: prototype → vertical slice → content alpha → beta (soft launch) → 1.0.

## 10. Open questions
- Q1: Touch default? D-pad for now (playtest 5: swipe made moves the player didn't intend). Confirm with Gate B testers.
- Q2: Real-time only, or an optional "turn mode" for accessibility? (Leaning towards assist mode: the sim waits for input.)
- Q3: Web storefront: our own (Stripe) vs portals (Poki/CrazyGames revenue share)?

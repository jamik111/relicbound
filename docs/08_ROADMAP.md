# 08 — Build Roadmap: how we start building
**Platform:** Android first (Godot 4) → iOS → web demo · **Team assumption:** 1–3 people · Sprints are 2 weeks.

Durations are estimates for a small team working on this full time. Halve the speed if it's part time.

## Overview
```
Month:   1        2        3        4    5    6    7    8    9    10   11   12   13
       [S0][S1 ][S2 ][S3 ][S4 ][S5 ][S6 ]
        Setup  Grey-box   Vertical slice  |---- Production (Worlds 2–5) ----|Beta|Launch
        ▲ Gate A        ▲ Gate B        ▲ Gate C                         ▲ D   ▲ E
```
| Gate | When | Question it answers | Pass criteria |
|---|---|---|---|
| **A: Tech** | end of Sprint 0 | Can our stack hit mobile targets? | Test scene at 60 fps on a mid-range Android; APK installs; CI is green |
| **B: Fun** | end of Sprint 2 | Is it fun with plain cubes? | 5 testers play the grey-box levels; average fun ≥ 7/10; they want "one more level" |
| **C: Slice** | end of Sprint 6 | Does it look and feel like the real game? | 3 polished levels + boss; external fun ≥ 8/10; ≥ 70% finish |
| **D: Content complete** | ~month 11 | Is the whole game in? | All 60 levels + 5 bosses playable; solver CI is green |
| **E: Launch** | ~month 13 | Is the market ready? | Soft-launch D1 ≥ 35%, conversion ≥ 3%, crash-free ≥ 99.5% |

---

## Before Sprint 0: things to get ready (1–3 days)
| Item | Notes |
|---|---|
| Godot 4.x (latest stable, ≥ 4.4) | Also download the **export templates** for the same version |
| Android Studio or the command-line tools | Android SDK, platform-tools (adb), build-tools, OpenJDK 17 |
| A real Android phone | Mid-range (e.g. Snapdragon 7-series or similar). Turn on USB debugging. The real phone is the truth, not the emulator |
| Blender 4.x | Tiles and characters |
| Node 18+ | For pixelfx sprite-sheet baking (already installed and checked) |
| GitHub repo | Push this project; enable Actions |
| Google Play Console account | One-time $25. Register early because identity verification can take days |

---

## Sprint 0: Setup & tech spike (weeks 1–2) → Gate A
**Goal:** prove the stack on a real phone before writing game code.

| # | Task | Done when |
|---|---|---|
| 0.1 | Create the Godot project in `game/`, folder layout from `06_TECH_STACK.md`, autoloads (`Game`, `Events`, `Settings`, `Save`) | Project opens and runs an empty scene |
| 0.2 | Set Jolt as the 3D physics engine; set the Mobile renderer; add the Compatibility fallback setting | Settings committed |
| 0.3 | Install the GUT addon; write 1 dummy test; headless test command works | `gut` passes in the terminal |
| 0.4 | Android export preset (debug APK + release AAB), keystore in a secret (not in git) | APK installs and opens on the phone |
| 0.5 | GitHub Actions: headless tests + Android debug export + Web export | CI green on push; APK downloadable as an artifact |
| 0.6 | **Performance spike scene:** a 32×24 tile room (MultiMesh), 8 torch lights, ortho tilted camera, 20 Jolt debris bodies, 10 pixelfx sprites | Holds 60 fps on the mid-range phone, 30+ on Compatibility |
| 0.7 | **Plugin spike:** install Effekseer for Godot 4 and Terrain3D; build a tiny scene with each and export to Android | Each one is marked "works on Android" or "drop" in the tech doc |
| 0.8 | godot_voxel spike (time-boxed to 1 day) | Keep or drop (rule: drop if > 3 MB or > 2 ms/frame) |
| 0.9 | pixelfx bake script: `tools/bake_fx.ps1` / `tools/bake_fx.sh` export every effect in `tools/fx_list.txt` into `game/assets/fx/<id>/` (see `09_ART_PIPELINE.md` §2) | Dust + sparkle play in the spike scene |

---

## Sprints 1–2: Grey-box prototype (weeks 3–6) → Gate B
**Goal:** the core game with cubes. No art, no story, just rules and feel.

### Sprint 1: the simulation (weeks 3–4)
| # | Task | Done when |
|---|---|---|
| 1.1 | `SimState`: grid of tile ids (PackedInt32Array), object list, player, tick, seeded RNG, `hash()` | Tests cover create/copy/hash |
| 1.2 | `SimStep.step()` with tick order from the GDD: player move → falling/rolling → triggers → damage | — |
| 1.3 | Rules: walk, dig dirt, push boulder/crate, gravity, roll off round objects, crush only when moving | ≥ 25 GUT tests for edge cases, all green |
| 1.4 | Gems, exit quota, keys/doors (4 colours plus shapes) | Tests green |
| 1.5 | Level format: JSON with `size`, `layers[terrain, objects]` as text rows, `meta` | 5 test rooms load |
| 1.6 | Golden replay system: record inputs → save → replay → compare hash | 1 replay in CI |

### Sprint 2: playable on a phone (weeks 5–6)
| # | Task | Done when |
|---|---|---|
| 2.1 | `LevelView`: sync cubes to the sim with smooth interpolation between ticks; camera follow | Movement looks smooth at 10 Hz sim / 60 fps render |
| 2.2 | Touch input: swipe-and-hold + virtual stick option, with a 120 ms input buffer; keyboard for desktop testing | Controls feel tight on the phone |
| 2.3 | Death → respawn at checkpoint in ≤ 1.2 s; checkpoint idols | — |
| 2.4 | **Hourglass rewind** (ring buffer of 30 states, 3 charges) | Rewind works mid-fall |
| 2.5 | Hazards: spikes, cracked floor, pits, dart wall; 2 enemies (pit viper, bat) | Tests + 1 room each |
| 2.45 | **Echoes prototype** (signature mechanic, added after playtest 1): hourglass leaves a replaying ghost; pressure plates and gates | One room playable; the player says whether it's exciting |
| 2.6 | 5 grey-box levels following the GDD beat template, **built around Echoes** | Playable start to finish |
| 2.7 | Basic juice: pixelfx dust + sparkle, placeholder sounds, phone vibration | — |
| 2.75 | **Enemies stay out of the main levels** (playtest 1): they exist in Test 08 only, until one has a real puzzle purpose. See the GDD | Not a Gate B requirement |
| 2.8 | **Playtest** with 5 people; fill in a feedback form. Ask directly whether Echoes feel new and fun, not just whether the game is fun | Gate B decision |

> If Gate B fails, we iterate on the rules for 1–2 more weeks. **No art is made until the cubes are fun.**

---

## Sprints 3–6: Vertical slice (weeks 7–14) → Gate C
**Goal:** a 15-minute piece of the final game, World 1 quality.

| Sprint | Focus | Key tasks |
|---|---|---|
| **3** | Art pipeline | World 1 tile kit in Blender (≈ 25 tiles), Material Maker jade/limestone/moss materials, MeshLibrary/MultiMesh swap from cubes, lighting setup, quality tiers |
| **4** | Nadia & tools | Nadia model + rig + 9 animation clips in an AnimationTree; **grapple-whip** rule + tests; **water** element (flow, floating crates, drowning) + tests |
| **5** | Levels & boss | 3 final World 1 levels (teach, twist, chase); **Stone Jaguar** boss (3 phases, telegraphs); Effekseer boss VFX; Jolt debris on boulder smashes |
| **6** | Wrapping | Main menu, level select, HUD, pause, journal v1 (map pages + 1 Thorne note), save/load, music theme + world stems, SFX pass, analytics events, **external playtest** |

---

## Production: Worlds 2–5 (months 4–11) → Gate D
Each world takes about **6–7 weeks** using the same recipe:
1. **Week 1:** element rules + GUT tests (sand / ice / lava / gears) + new tool.
2. **Week 2:** tile kit + materials + new enemies.
3. **Weeks 3–5:** 12 levels (≈ 4 per week) in the level editor; solver CI on each.
4. **Week 6:** boss + cutscenes + journal pages + music.
5. **Week 7:** playtest + tune the difficulty from the analytics funnels.

Runs alongside throughout: **in-game level editor** (month 4, speeds everything up), **solver** (month 4),
localisation string table (month 6), accessibility options (month 8), the iOS export preset (month 9).

## Beta & launch (months 12–13) → Gate E
- Google Play Billing (full-game unlock), restore purchase, Play Games cloud save.
- **Closed testing on Play** (required: ≥ 12 testers for 14 days for new personal developer accounts), then soft launch in 2–3 countries.
- Web demo (World 1, Compatibility renderer) on itch.io/our site with a "Get it on Google Play" button.
- Store page, trailer, screenshots, press kit. Then iOS submission.

---

## How we work
- **Branching:** `main` is always shippable; one branch per feature; open a PR → CI must pass before merging.
  Nobody pushes straight to `main`. GitHub branch protection needs a paid plan on private repos, so a local
  hook enforces it: run `git config core.hooksPath .githooks` once per clone.
- **Definition of done:** tests pass, works on the reference phone, no new warnings, docs updated if the rules changed.
- **Weekly:** build on the phone every Friday + a 15-minute playtest + a short note in `docs/devlog/`.
- **Claude Code:** use the `relicbound-stack` skill for code and the `pixelfx` skill for effects. Ask for one roadmap task ID at a time (e.g. "do task 1.3").

## Next 3 actions
1. Install Godot + the Android SDK, plug in a phone (checklist above).
2. Push this repo to GitHub.
3. Start **Sprint 0, task 0.1**.

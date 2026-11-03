---
name: relicbound-stack
description: How to build Relicbound (a pulp-adventure grid action-puzzler, Android-first, Godot 4 + GDScript, web demo export) and how to use the ten third_party libraries in it (JoltPhysics, recastnavigation, meshoptimizer, pixelfx, Effekseer, Material Maker, FastNoise2, Terrain3D, godot_voxel, ozz-animation). Use when writing game code, the sim, levels, scenes, the asset pipeline, VFX, Android export or CI for this project, or when deciding whether one of those libraries fits a task.
---

# Relicbound stack (Godot 4, Android-first)

Read `docs/06_TECH_STACK.md` (architecture), `docs/05_GDD_MECHANICS.md` (rules) and `docs/08_ROADMAP.md`
(the current sprint) before you change code. The Godot project root is `game/`.
For any art, UI or VFX work, also read and follow `docs/09_ART_PIPELINE.md`.

## Hard rules
1. **The sim is pure and always resolves the same way.** `game/sim/` holds `RefCounted` classes and static funcs
   only: no `Node`, no `get_tree()`, no `randf()`/`randi()` (use the seeded RNG stored in `SimState`), and
   integers only for positions and timing. `SimStep.step(state, intent) -> StepResult` returns the new state and an events array.
2. **Every new rule needs a GUT test** in `game/tests/sim/`, and all golden replays must still pass.
3. **Juice hangs off events.** `VfxRouter`, `AudioRouter`, `Haptics` and `LevelView` react to sim events and never change the sim state.
4. **Physics and navmesh never decide gameplay.** Jolt is for cosmetic debris/ragdolls only. Navigation (Recast) is for hub/cutscene NPCs only.
5. **Static typing everywhere** in GDScript (`var hp: int`, `func f(a: Vector2i) -> bool`).
6. Budgets: 60 fps on mid-range Android, ≤ 120 draw calls, ≤ 400 MB RAM, base `.aab` ≤ 150 MB.
7. Everything must also run on the **Compatibility** renderer (low-end Android + web demo).
8. **Art, UI and VFX follow `docs/09_ART_PIPELINE.md`**: placeholder art only until Gate B (cubes, default theme,
   placeholder pixelfx, jsfxr); sheets go to `game/assets/fx/<id>/` with Nearest / no mipmaps / Lossless import and
   `pixel_size` 1/48; UI screens use only `relic_theme.tres` styles; every third-party asset is CC0/CC-BY/OFL/MIT and
   logged in `CREDITS.md`; check each asset against that doc's definition of done.

## Library playbook (sources are in `third_party/`)
| Need | Use | How |
|---|---|---|
| Pixel VFX | pixelfx | Use the `pixelfx` skill. `node third_party/pixelfx/tools/list.mjs <words>` → render, look at the contact sheet → `--sheet` → copy the PNG+JSON to `game/assets/fx/<id>/` (or list it in `tools/fx_list.txt` and run `tools/bake_fx`) → `AnimatedSprite3D` billboard, nearest filter, unshaded, `pixel_size` 1/48, fps from `meta.pixelfx.fps`, offset from the pivot. Start ids per sim event: `docs/09_ART_PIPELINE.md` §2 |
| Debris / ragdoll | Jolt (built in) | `RigidBody3D` chunks spawned by `VfxRouter` on `BoulderShattered`/`EnemyDefeated`; freed after 3 s; disabled on the Lite tier |
| Hub NPC walking | Recast (built in) | `NavigationRegion3D` + `NavigationAgent3D`. Never used in puzzle levels (those use grid A* in `sim/`) |
| Mesh LOD / optimisation | meshoptimizer (built into the importer) | Leave "Generate LODs" on in the import settings; optionally pre-run `gltfpack -si 0.6` |
| Big 3D VFX | Effekseer | `addons/effekseer`; author `.efkefc` in `assets_src/effekseer/`; play via an `EffekseerEmitter3D` node in `vfx/` |
| PBR materials | Material Maker | Sources in `assets_src/materials/*.ptex`; export to `game/assets/materials/` |
| Noise | FastNoise2 / FastNoiseLite | `FastNoiseLite` for simple runtime noise; FastNoise2 (via godot_voxel) or baked textures for heavier work. Always seeded |
| Outdoor vistas / hub terrain | Terrain3D | `addons/terrain_3d`. Never in puzzle levels |
| Destructible backdrop | godot_voxel | Optional (only if the Week-1 spike passed). Never in puzzle rules |
| Character animation | AnimationTree | ozz-animation isn't used |

## Commands
- Run tests: `godot --headless --path game -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Export Android debug: `godot --headless --path game --export-debug "Android" ../build/relicbound.apk`
- Export Play bundle: `godot --headless --path game --export-release "Android AAB" ../build/relicbound.aab`
- Export web demo: `godot --headless --path game --export-release "Web" ../build/web/index.html`
- Install on a phone: `adb install -r build/relicbound.apk`

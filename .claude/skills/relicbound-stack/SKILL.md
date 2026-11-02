---
name: relicbound-stack
description: How to build Relicbound (a pulp-adventure grid action-puzzler, web-first three.js + TypeScript + Capacitor) and how to use the ten third_party libraries in it (pixelfx, meshoptimizer/gltfpack, JoltPhysics.js, Effekseer, Material Maker, FastNoise2, recastnavigation, ozz-animation, Terrain3D, godot_voxel). Use when writing game code, the sim, levels, the asset pipeline or VFX for this project, or when deciding whether one of those libraries fits a task.
---

# Relicbound stack

Read `docs/06_TECH_STACK.md` (architecture) and `docs/05_GDD_MECHANICS.md` (rules) before you change code.

## Hard rules
1. **The sim always resolves the same way and is pure.** `packages/sim` is integer-grid TS with no DOM, no
   three.js and no Math.random (it uses a seeded RNG in the state). `step(state, intent) -> {state, events}`.
   Any new rule needs a unit test and must keep the golden replays passing.
2. **Juice hangs off events.** The renderer, VFX, audio and haptics react to sim events and never change the sim state.
3. **Physics and navmesh never decide gameplay.** Jolt is cosmetic debris/ragdoll only. Recast is for the hub/cutscene NPCs only.
4. Budgets: web core ≤ 15 MB, world pack ≤ 25 MB, ≤ 150 draw calls, 60 fps on mid-range Android.

## Library playbook (sources are in `third_party/`)
| Need | Use | How |
|---|---|---|
| Pixel VFX (dust, sparkle, torch, splash, poof) | pixelfx | Use the `pixelfx` skill. Search with `node third_party/pixelfx/tools/list.mjs <words>`; render and look at `records/.../contact.png`; import `src/core` + effect modules in `packages/vfx`, or bake `--sheet` into `assets/build/fx/` |
| Compress meshes / LODs | meshoptimizer | `gltfpack -i in.glb -o out.glb -cc -tc` (+ `-si 0.6` for LOD). Load with three.js `GLTFLoader.setMeshoptDecoder(MeshoptDecoder)` |
| Debris / ragdoll | JoltPhysics.js (`jolt-physics` npm) | Spawn on `BoulderShattered`/`EnemyDefeated` events; off on the Lite tier; bodies are removed after 3 s |
| Big 3D boss/cinematic VFX | Effekseer | Author `.efkefc` in the Effekseer editor; play via Effekseer for WebGL in `packages/vfx/effekseer.ts` |
| PBR materials | Material Maker | Keep `.ptex` sources in `assets/src/materials`; export → `toktx --t2 --encode etc1s` → KTX2 |
| Noise (wear, moss, daily room) | FastNoise2 | Offline in `tools/noise/` (build with emscripten or use baked textures). The runtime only uses seeded baked output |
| Free-moving NPC paths (hub) | recastnavigation (`recast-navigation` npm) | Never in puzzle levels. Enemies there use grid A* in the sim |
| Skeletal anim at scale | ozz-animation | Deferred. Use three.js AnimationMixer unless profiling proves otherwise |
| Terrain / voxels | Terrain3D, godot_voxel | **Godot only.** Don't use them in the web build. They're for the Godot fallback track only |

## Commands (once scaffolded)
- `pnpm dev`: the game at localhost
- `pnpm test`: sim unit tests + golden replays
- `pnpm levels:check`: solver check on every level
- `pnpm assets`: run the gltfpack/KTX2/pixelfx bake pipeline

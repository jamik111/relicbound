# 06 — Technology Stack & Architecture (ADR-001)

## Decision
**Web-first TypeScript game built on three.js. It ships as a PWA and is wrapped with Capacitor for the iOS and
Android stores.** The rules run as a plain-data grid simulation that always resolves the same way. The
renderer and VFX only draw it.

### Why web-first and not Godot
| Option | Pros | Cons | Verdict |
|---|---|---|---|
| **TS + three.js + Vite + Capacitor** | ~2–6 MB engine, link-to-play in seconds, one codebase for web, iOS and Android, pixelfx is native JS, huge ecosystem | We write more engine glue ourselves | ✅ **Chosen** (the brief prefers a web app) |
| Godot 4 (GDScript) | Great editor; Jolt is built into Godot 4.4+; Terrain3D, godot_voxel and Effekseer plugins | Web export is ~30–40 MB wasm with slow first load on phones; GDExtensions/modules (Terrain3D, voxel) are hard or impossible on web | Keep as **fallback track** if we go native-first |
| Unity | Mature mobile | Licence and runtime fees; heavy web builds | ❌ |

## Stack
| Layer | Choice |
|---|---|
| Language / build | TypeScript (strict), Vite, pnpm, Vitest, Playwright e2e |
| Rendering | three.js (WebGL2; WebGPU renderer as opt-in once stable on mobile) |
| Sim | Our own `@relic/sim` package: pure TS, integer grid, fixed tick, no DOM |
| UI | Lightweight DOM/CSS overlay (Preact or Solid) for menus and journal; in-canvas HUD |
| Audio | Howler.js (or WebAudio directly); adaptive music stems |
| Storage | IndexedDB (idb-keyval); optional cloud sync via a small serverless API |
| Native shell | Capacitor (iOS/Android): IAP via a native plugin, haptics, status bar |
| Hosting | Static CDN (Cloudflare Pages / Netlify); world packs as separate cached bundles |
| Analytics | PostHog or a self-hosted equivalent; consent gate |

## How the 10 requested libraries fit
They're in `third_party/`. Several are C++ or Godot-only, so this table is honest about where each one is used.

| Library | Role in Relicbound | How it gets into a web build | Status |
|---|---|---|---|
| **pixelfx** (patch-gg) | 2D pixel VFX: gem sparkles, dust puffs, torches, impacts, UI juice. Its **Claude skill is installed** | Native JS: import `src/core` + effects directly, or bake sprite sheets that we draw on camera-facing quads | ✅ Core |
| **meshoptimizer** (zeux) | Compress every glTF tile/character (`gltfpack -cc -tc`), LODs, vertex cache optimisation | `gltfpack` CLI in the asset pipeline; three.js has `MeshoptDecoder` built in | ✅ Core (pipeline) |
| **JoltPhysics** (jrouwe) | **Cosmetic only**: boulder-smash debris, crumbling walls, ragdolls for defeated enemies. Never game rules | `jolt-physics` npm (JoltPhysics.js, the official wasm port) | ✅ Polish tier (off on the Lite tier) |
| **Effekseer** | Big 3D VFX moments: boss attacks, Sunstone reveals, lava eruptions. Authored in the Effekseer editor | Effekseer for WebGL runtime (three.js integration); the editor from this repo is used for authoring | ✅ Boss/cinematic VFX |
| **Material Maker** (RodZill4) | Procedural PBR materials (stone, jade, sandstone, ice, basalt, brass) exported as textures, then KTX2 | Offline authoring tool → PNG → `toktx`/basisu → KTX2 | ✅ Art pipeline |
| **FastNoise2** (Auburn) | Procedural variety: tile wear and moss placement, background cave walls, daily-challenge room layouts | Offline Node tool via its C API/emscripten build, **or** baked noise textures; the runtime uses seeded output | ✅ Tools + daily room |
| **recastnavigation** | Navmesh for free-moving NPCs in the **hub camp / cutscenes** (gameplay enemies use grid A*) | `recast-navigation` npm (recast-navigation-js wasm port) | ⚪ Optional (hub only) |
| **ozz-animation** | High-performance skeletal animation and blending | three.js `AnimationMixer` covers v1. Compile ozz to wasm only if profiling shows the skinning CPU cost with many enemies on screen | ⚪ Deferred |
| **Terrain3D** (Tokisan) | Heightmap terrain | **Godot-only GDExtension, not usable in three.js.** Used only if we take the Godot fallback track (e.g. a large overworld) | ⛔ Godot track |
| **godot_voxel** (Zylann) | Voxel/destructible terrain | **Godot C++ module, not usable in three.js.** Godot track only | ⛔ Godot track |

> Note: the core puzzle doesn't need a physics engine or navmesh. Keeping Jolt and Recast out of the rules is
> deliberate: rules that always resolve the same way are what make rewind, replays and fair deaths possible.

## Architecture
```
relicbound/
├─ apps/
│  ├─ game/            # Vite app: boot, scenes, renderer, input, UI, audio
│  └─ editor/          # Internal level editor (same renderer + sim)
├─ packages/
│  ├─ sim/             # Pure TS grid simulation (no three.js), 100% unit tested
│  ├─ levels/          # Level JSON + schema + solver
│  ├─ render/          # three.js scene graph, tile instancing, lights, interpolation
│  ├─ vfx/             # pixelfx bridge + Effekseer bridge + Jolt debris
│  └─ platform/        # save, IAP, analytics, haptics (web vs Capacitor adapters)
├─ assets/
│  ├─ src/             # .blend, Material Maker .ptex, Effekseer .efkefc, audio stems
│  └─ build/           # gltfpack'd .glb, KTX2, sprite sheets (generated, git-ignored)
├─ tools/              # asset pipeline scripts (gltfpack, toktx, pixelfx render, noise bake)
├─ third_party/        # the 10 cloned repos (reference + tooling)
└─ docs/
```

**Data flow per frame:** `Input → (on each tick) sim.step(state, intent) → events[] → render.sync(state, alpha)`
and `vfx.play(events)` / `audio.play(events)`. The sim emits **events** (`BoulderLanded`, `GemCollected`,
`PlayerCrushed`…), and every bit of juice hangs off those events. That keeps the sim free of rendering code.

## Rendering plan (mobile-friendly)
- Tiles are `InstancedMesh` per tile type, so one draw call each. Rooms outside the view are culled.
- Lighting: 1 directional + up to 8 clustered point lights (torches), baked AO in the vertex colour.
- Post-processing (High tier only): tilt-shift DOF, bloom, colour grading LUT per world.
- Quality tiers: **Lite** (no post, no Jolt, half resolution) · **Standard** · **High**, auto-detected from a benchmark that runs on first boot.
- The pixel VFX render at 1/3 resolution on an overlay canvas texture and are upscaled with nearest-neighbour. This gives the "HD-2D" look: crisp pixel effects over a smooth 3D world.

## Testing
- Sim: unit tests per rule, plus **golden replays** (recorded inputs → expected state hash).
- Levels: solver CI job ensures every level is solvable and the gem quota is reachable.
- E2E: Playwright boots the game in mobile emulation, plays the tutorial replay and checks the frame time budget.

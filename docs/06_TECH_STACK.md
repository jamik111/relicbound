# 06 — Technology Stack & Architecture (ADR-002)
**Supersedes ADR-001 (web-first three.js).** · Date: 2026-11-02 · Status: Accepted

## Decision
**Update 2026-11-12: the platform is now Steam (Windows, Steam Deck) only; see the BRD.** The engine, the simulation and
the architecture below are unchanged. The Android and phone-performance parts are kept for history.

~~An Android-first native game built in Godot 4 (GDScript). It ships to Google Play first, then the iOS App
Store. A small web demo of World 1 is exported from the same project for marketing.~~

The rules run as a pure grid simulation that always resolves the same way. The scenes, renderer, VFX and audio
only draw it and react to its events.

### Why
| Factor | Android app (chosen) | Web app |
|---|---|---|
| Audience | The genre's fans played on phones. Android is most phones in our target regions | Mostly desktop and casual portal players |
| Revenue | Google Play Billing; players are used to paying once | Weak unless a portal takes a revenue share |
| Discovery | Store search, charts, featuring | We have to bring every player ourselves |
| Performance | Full GPU and memory → 2.5D lighting, debris, big VFX | Browser memory caps, throttling, audio quirks |
| Offline / feel | Full offline, haptics, gamepad, true fullscreen | Partial |

### Why Godot (and not three.js or Unity)
| Option | Verdict |
|---|---|
| **Godot 4** | ✅ Free (MIT); one-click Android/iOS/Web export; Jolt and Recast built in; 9 of our 10 libraries plug in |
| three.js + Capacitor | ❌ Good for web-first, but Terrain3D and godot_voxel can't be used, and every native library becomes a WASM port |
| Unity | ❌ Licence/runtime fees, heavier builds, less control |

## Engine settings
| Setting | Value |
|---|---|
| Engine | Latest stable **Godot 4.x** (≥ 4.4 for built-in Jolt). Pin the exact version in `project.godot` and CI |
| Language | **GDScript** with static types everywhere (`var x: int`). (C# can't export to the web, and we want the demo) |
| Renderer | **Mobile** renderer (Vulkan) by default; **Compatibility** (OpenGL ES 3) for low-end Android and the web demo |
| Physics | 3D physics engine = **Jolt** (cosmetic only, see rules) |
| Min Android | API 24 (Android 7.0), arm64-v8a + armeabi-v7a; target the latest API that Play requires |
| Packaging | Android App Bundle (`.aab`) for Play; Play Asset Delivery for world packs if the bundle exceeds 150 MB |
| Tests | **GUT** (Godot Unit Test) for headless unit tests |
| CI | GitHub Actions + headless Godot: run tests, check levels, export the `.aab`/`.apk` and the web demo |

## How the 10 libraries fit
| Library | Role in Relicbound | How it gets into Godot | Status |
|---|---|---|---|
| **JoltPhysics** | Cosmetic only: boulder-smash debris, wall crumbles, enemy ragdolls. **Never game rules** | Built into Godot 4.4+ (Project Settings → Physics → 3D → Jolt Physics) | ✅ Core polish |
| **recastnavigation** | Free-walking NPCs in the hub camp and cutscenes. Puzzle enemies use grid A* in the sim | Built into Godot (`NavigationRegion3D` / `NavigationAgent3D` use Recast) | ✅ Hub only |
| **meshoptimizer** | LODs and vertex optimisation at import | Built into Godot's mesh importer (auto LOD). The `gltfpack` CLI is optional for pre-optimising | ✅ Pipeline |
| **pixelfx** | 2D pixel VFX: dust, sparkles, torches, splashes, poofs, UI juice | `node tools/render.mjs <id> --sheet` → PNG + JSON → `AnimatedSprite3D` (billboard, nearest filter). The skill is installed | ✅ Core |
| **Effekseer** | Big 3D VFX: boss attacks, Sunstone reveals, eruptions | **Effekseer for Godot 4** plugin in `addons/effekseer`; author in the Effekseer editor | ✅ Boss/cinematic. **No GPU-particle nodes** (they fail on Compatibility); see spike results |
| **Material Maker** | Procedural PBR materials (jade, sandstone, ice, basalt, brass) | Built with Godot; export Godot materials/textures → `assets/materials/` | ✅ Art pipeline |
| **FastNoise2** | Tile wear and moss scatter, background cave walls, daily-room seeds | Baked offline to textures by a tool (godot_voxel, its runtime route, was dropped). Godot's built-in `FastNoiseLite` covers runtime cases | ✅ Tools/variety |
| **Terrain3D** | Outdoor scenes: world map/flight hub, jungle and desert approach vistas in cutscenes | GDExtension in `addons/terrain_3d`. **Puzzle levels don't use it** | ✅ Hub/cutscenes. Passed the Sprint 0 spike (device check pending) |
| **godot_voxel** | ~~Destructible backdrop rock for chase/collapse levels; cave-in sequences~~ | — | ⛔ **Dropped** in the Sprint 0 spike (7 MB > 3 MB rule, no armv7 build). Use pre-fractured meshes + Jolt debris for cave-ins |
| **ozz-animation** | Not needed | Godot's `AnimationTree` / `AnimationPlayer` cover blending and skinning | ⛔ Not used (kept as reference) |

### Sprint 0 plugin spike results (2026-11-03, Godot 4.7.2)
Each plugin went into a throwaway project with a tiny scene. It was run on desktop with both renderers and exported as an
arm64 release APK. Size is the APK growth over an empty project (25.8 MB). Desktop frame times aren't meaningful, so
the per-frame cost is measured on the reference phone.

| Plugin (version) | Android libs | APK size added | Mobile | Compatibility | Verdict |
|---|---|---|---|---|---|
| Effekseer for Godot 4 (1.80.7) | arm64, armv7, x86 | +3.4 MB per ABI | ✅ | ⚠️ Normal effects OK; **GPU-particle effects fail** (shader needs GLSL > ES 3.0) | **Keep** for bosses/cinematics. Author without GPU-particle nodes. Install it in Sprint 5 |
| Terrain3D (1.1.0) | arm64, armv7 | +2.9 MB per ABI | ✅ | ✅ | **Keep** for the hub/vistas. A headless export logs a harmless `get_version` script error from its disabled export hook |
| godot_voxel (1.7x GDExtension) | arm64, x86_64 only | +7.2 MB | ✅ | ✅ | **Drop**: fails the ≤ 3 MB rule, and no armv7 build for low-end phones |

Device check still to do: `build/spike_efk.apk` and `build/spike_t3d.apk` (debug-signed) on the reference phone, both
renderers. The verdict changes only if one crashes or drops below 60 fps.

> Puzzle levels are made from **grid tiles** (`GridMap` / `MultiMeshInstance3D`), not terrain or voxels. Terrain3D
> and godot_voxel are for scenery around the puzzles, so they're optional and can be cut without hurting the game.

## Architecture
```
relicbound/
├─ game/                         # Godot project root (project.godot)
│  ├─ sim/                       # PURE rules: no Node, no scene, no randf()
│  │  ├─ sim_state.gd            #   RefCounted: per-cell terrain/objects/flags/ids, player, rng, tick, hash()
│  │  ├─ sim_step.gd             #   static func step(state, intent) -> StepResult {state, events}
│  │  ├─ rules/                  #   rule_player.gd, rule_gravity.gd, rule_triggers.gd (+ water, sand, ice...)
│  │  ├─ sim_event.gd            #   OBJECT_LANDED, GEM_COLLECTED, PLAYER_CRUSHED, ...
│  │  ├─ tiles.gd                #   terrain/object ids (stored in saves and replays)
│  │  ├─ level_codec.gd          #   level JSON <-> SimState (legend in the file header)
│  │  └─ replay.gd               #   input strings ".UDLR" -> final state
│  ├─ levels/                    # level .json, level_loader.gd (file I/O), later solver.gd
│  ├─ scenes/                    # boot, main_menu, level, hub, journal, cutscenes
│  ├─ view/                      # LevelView: GridMap/MultiMesh sync, tick interpolation, camera
│  ├─ actors/                    # Nadia, enemies, boss visual scenes (AnimationTree)
│  ├─ vfx/                       # event→VFX router: pixelfx sprites, Effekseer, Jolt debris
│  ├─ audio/                     # event→SFX, adaptive music bus
│  ├─ ui/                        # HUD, touch controls, menus, journal (Control nodes)
│  ├─ platform/                  # save, billing, analytics, haptics (Android/iOS/Web adapters)
│  ├─ autoload/                  # Game.gd, Settings.gd, Save.gd, Events.gd (singletons)
│  ├─ addons/                    # gut, effekseer, terrain_3d
│  ├─ assets/                    # imported .glb, textures, sprite sheets, audio
│  └─ tests/                     # GUT tests + golden replays
├─ assets_src/                   # .blend, Material Maker .ptex, Effekseer .efkefc, audio stems
├─ tools/                        # pixelfx bake, level linter, noise bake scripts
├─ third_party/                  # the 10 cloned repos (reference/tooling; git-ignored)
└─ docs/
```

**Flow per frame:** `TouchInput → Game (fixed 10 Hz tick) → SimStep.step(state, intent) → events[]` →
`LevelView.sync(state, alpha)` + `VfxRouter.play(events)` + `AudioRouter.play(events)` + `Haptics`.
The sim never touches a Node. Nodes never change the sim state.

## Mobile rendering plan
- Each tile type is one `MultiMeshInstance3D` (or `GridMap` with a MeshLibrary), so one draw call each.
  Rooms outside the camera are hidden.
- Orthographic `Camera3D` tilted to 35°. **Torch light is per-tile vertex colour** (MultiMesh instance colours,
  recomputed ~10×/s for flicker), plus baked AO. Dynamic `OmniLight3D`s are a High-tier extra only (see below).
- Quality tiers: **Lite** (Compatibility renderer, vertex lighting) · **Standard** (vertex lighting) ·
  **High** (+ a few real lights, glow, tilt-shift DOF, colour LUT). Picked automatically from a benchmark on first
  boot. Jolt debris is cheap and stays on in every tier (measured below).

### Device results: Sprint 0 perf spike (2026-11-04)
Phone: Redmi 5 Plus (Snapdragon 625 / Adreno 506, 2160×1080, Android 12 custom ROM). Low end, below the
mid-range target. Scene: 32×24 tiles, 8 torches, 20 Jolt debris, pixelfx sprites (`scenes/spikes/perf_spike.gd`).

| Renderer | 8 real lights | 8 real lights, floor in 8×8 chunks | No lights | **Vertex lighting** |
|---|---|---|---|---|
| Compatibility | 7.5 fps | 12 fps | 60 fps | **60 fps** (1% low 60) |
| Mobile (Vulkan) | 7.5 fps (GPU 342 ms) | 7.5 fps | 33 fps (GPU 27 ms even when empty) | 41 fps (1% low 26) |

Takeaways: per-pixel dynamic lights are the cost, not geometry (57 draw calls), debris or effects. On this GPU
Vulkan has a ~27 ms floor, so low-end phones must get the Compatibility renderer. Gate A on a **mid-range**
phone (Mobile renderer) is still to be measured. Re-run with `user://spike.cfg` (keys in the spike header) and
the `Android Compat` export preset (`com.dscvrx.meridian.compat`, installs next to the main app).
- Pixel VFX are `AnimatedSprite3D` billboards with nearest filtering. This gives the "HD-2D" mix of crisp pixel
  effects over a smooth 3D world.
- Budgets: 60 fps on mid-range Android (Snapdragon 7-series), ≤ 120 draw calls, ≤ 400 MB RAM, base `.aab` ≤ 150 MB.

## Platform services
| Need | Android | iOS (later) | Web demo |
|---|---|---|---|
| Purchase | Godot Google Play Billing plugin | StoreKit plugin | "Get it on Google Play" link |
| Save | `user://` + optional Play Games cloud save | `user://` + iCloud | `user://` (IndexedDB) |
| Analytics | GameAnalytics or a self-hosted PostHog endpoint (privacy-first, consent in the EU) | same | same |
| Haptics | `Input.vibrate_handheld()` | same | none |

## Testing
- **Sim unit tests (GUT, headless):** one test per rule edge case.
- **Golden replays:** recorded inputs → expected state hash. They must match on every run and in CI.
- **Level solver:** a CI job proves every level is solvable and its gem quota reachable.
- **Device tests:** a weekly build on 3 reference phones (low, mid, high) with a frame-time log.

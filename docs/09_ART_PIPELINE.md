# 09 — Art Pipeline: which tool makes what, and how

Companion to `07_ART_AUDIO_DIRECTION.md` (what it should look like). This doc covers **how it gets made and
into Godot**.

## Golden rule: timing
| Phase | Art allowed |
|---|---|
| Sprints 0–2 (grey-box, until Gate B) | Cubes, the default Godot theme with one font, **placeholder** pixelfx effects, jsfxr sounds, free CC0 models (only if they help testing) |
| Sprint 3+ (after Gate B passes) | Final UI theme, Figma screens, Blender tiles, Nadia, Material Maker materials, final effects recoloured per world |

Don't polish art for mechanics that might change. Effects are the exception: they're cheap and make testing more fun.

---

## 1. Tool map
| Asset | Tool | Output → Godot |
|---|---|---|
| Pixel VFX (gameplay) | **pixelfx skill** (Sprite Fusion method) | `--sheet` PNG + JSON → `game/assets/fx/<id>/` → `AnimatedSprite3D` billboard |
| UI juice (pops, counters, screen wipes) | **pixelfx** `ui/*`, `transitions/*` + Godot **Tween** | Sprite sheets → `AnimatedSprite2D` / `TextureRect`; motion via Tween |
| Big 3D VFX (bosses, Sunstones) | **Effekseer** editor | `.efkefc` → `game/assets/effekseer/` → `EffekseerEmitter3D` |
| UI layout & flow | **Figma** (optional) → **Godot Control nodes** | One `game/ui/theme/relic_theme.tres` used by every screen |
| UI art (panels, buttons, icons) | **Aseprite** / **LibreSprite** (pixel icons), **Krita** or Figma (parchment) | PNG → `StyleBoxTexture` (9-slice) in the Theme |
| 3D tiles, props, characters | **Blender 4.x** | `.blend` in `assets_src/models/` → export `.glb` → `game/assets/models/` |
| Placeholder 3D | **Kenney.nl**, **Quaternius**, **KayKit** (CC0) | `.glb` straight in; log it in `CREDITS.md` |
| Materials / textures | **Material Maker** (in `third_party/`) | `.ptex` in `assets_src/materials/` → PNG maps → `StandardMaterial3D` |
| Fonts | Google Fonts (OFL): *IM Fell English* (titles), *Inter* (body) | `.ttf` → `game/assets/fonts/` → Theme |
| Placeholder SFX | **jsfxr**, **ChipTone** | `.wav` → `game/assets/audio/sfx/` |
| Final SFX/music | Freesound (CC0/CC-BY), commissioned composer | `.ogg` → `game/assets/audio/` |

Every third-party asset gets a line in `CREDITS.md` (name, author, licence, URL). Only use CC0/CC-BY/OFL/MIT. No "free for personal use" assets.

---

## 2. Effects with pixelfx (the Sprite Fusion method)
**The loop:** find the closest existing effect → render → **look at the contact sheet** → adjust options or code →
render again (2–3 rounds) → export the sheet.

**How to ask Claude Code (template):**
> Using the pixelfx skill: make a **[effect]** for **[event]** in **[world]**. Start from `[closest id]`. Palette:
> **[colours]**. Reference: **[e.g. "like a torch in an old SNES game"]**. Size: about **[N] tiles** wide. Render it,
> look at the contact sheet, refine 2–3 times, then export a sheet to `game/assets/fx/[name]/` and tell me the fps and pivot.

**Godot import rules for every sheet:**
- Texture import: Filter = **Nearest**, Mipmaps = **off**, Compress = **Lossless**.
- `AnimatedSprite3D`: `billboard = enabled`, `texture_filter = nearest`, `pixel_size` = 1/48 (1 VFX pixel = 1/48 tile), fps from `meta.pixelfx.fps`, offset from `meta.pixelfx.pivot`, `shaded = false`.
- Glow is baked into the sheet colours. For bright scenes, use an add blend material or a darker recolour.
- One reusable scene: `game/vfx/pixel_fx.tscn` (plays once, then frees itself). `VfxRouter` maps sim events to it.

### Gameplay effect list (core, used in every world)
| Sim event | Start from pixelfx id | Notes |
|---|---|---|
| `GemCollected` | `pickups/gem-spin` + `pickups/collect-burst` | Recolour per gem; the pitch of the chime rises over a combo |
| `SunshardCollected` (rare) | `pickups/loot-beam` | Red/gold, bigger |
| `KeyCollected` | `pickups/key-glint` | Uses the key's colour |
| `BoulderLanded` | `impacts/heavy-landing` | Earth/stone palette; add a small camera shake |
| `BoulderPushed` | `impacts/blunt-hit` (tiny) | Dust puff at the back edge |
| `DirtDug` | `nature/earth-spike` cut down, or a custom "dirt-crumble" | Make a new one with the skill if nothing fits |
| `PlayerCrushed` / death | `spawn/poof` | Then the respawn uses `spawn/respawn-beam` (gold, short) |
| `CheckpointLit` | `fire/spirit-flame` | Jade-green flame on the idol |
| `ExitOpened` | `pickups/loot-beam` + `weather/god-rays` | Big "you can leave" moment |
| `DartFired` / hit | `projectiles/arrow` + `impacts/hit-spark` | |
| `SpikesUp` | `impacts/hit-flash` (warning) | Telegraph 0.5 s before |
| `SecretWallOpened` | `pickups/chest-open` sparkle + `transitions/pixel-dissolve` (local) | |
| `RewindUsed` | `transitions/glitch-wipe` recoloured gold-sepia | Full screen, 0.3 s |
| Ambient torch / brazier | `fire/torch`, `fire/brazier` | Looping |

### Per-world effects
| World | Effects (start ids) | Palette |
|---|---|---|
| 1 Jade Cenote (water) | `water/splash`, `water/drip`, `water/ripples`, `water/waterfall`, `critters/snake`, `critters/bat`, `weather/fireflies` | `PAL.water` + jade green |
| 2 Qadir (sand) | Custom "sand-pour" (new), `nature/tornado` small as a dust devil, `weather/god-rays` for light beams, `critters/*` scarabs (new) | `PAL.dust`, `PAL.gold`, lapis blue |
| 3 Hrimfjall (ice) | `ice/freeze`, `ice/ice-shatter`, `ice/snowflake-burst`, `weather/snow`, `weather/aurora` (backdrop only: it's slow) | `PAL.ice` |
| 4 Ember Forge (lava) | `fire/flame-pillar`, `fire/meteor` (eruption), `status/burning`, custom "lava-to-basalt" hiss | `PAL.lava`, `PAL.ember` |
| 5 Meridian Core (time) | `arcane/*` time bubbles, `transitions/iris`, custom "gear-tick" sparks | `PAL.gold`, `PAL.metal` + magenta |

**Performance:** pixelfx's check flags some effects as slow (e.g. `weather/aurora`, `ice/frost-breath`). That only
matters for live JS rendering. **We always bake sheets**, so the cost in Godot is just sprite frames. Keep sheets
≤ 2048×2048 and ≤ 48 frames.

---

## 3. UI pipeline
1. **Sprints 0–2:** default Godot theme + one font. Build function, not looks.
2. **Sprint 3:** (optional) design 5 key screens in **Figma**: Title, Level Select (map), HUD, Pause, Journal.
   Ask Claude: "design the Level Select screen in Figma in a parchment field-journal style".
3. Build **`relic_theme.tres`**: fonts, colours, 9-slice `StyleBoxTexture` for parchment panels, stamp buttons
   (normal/hover/pressed/disabled), a 9-slice frame for the journal.
4. **Screens are scenes** in `game/ui/screens/` (`title.tscn`, `level_select.tscn`, `hud.tscn`, `pause.tscn`,
   `journal.tscn`, `settings.tscn`). They only use Theme styles. No per-node colour overrides.
5. **Juice:** every button press scales 0.95 → 1.0 (Tween, 0.08 s) plus a paper "tick" sound. Screen changes use a
   pixelfx transition (`transitions/iris` or `diamond-wipe`) at 0.4 s.
6. **Mobile rules:** touch targets ≥ 48 dp; HUD inside the safe area (notches); one-thumb reach for the tool and
   hourglass buttons (bottom-right and top-right); text ≥ 14 px at 1× scale; lock the game to **landscape** and test on a real phone.

---

## 4. 3D pipeline (Sprint 3+)
1. **Blender scale:** 1 unit = 1 m = 1 tile. Origin at the tile's bottom centre. +Y up; export glTF with "+Y Up".
2. **Tile kit per world (~25 pieces):** floor ×3 variants, wall straight/corner/end/T, ancient wall, cracked wall,
   dirt, pit edge, door ×4, plate, spike base, dart wall, checkpoint idol, exit gate, props ×5.
3. **Budgets:** tile ≤ 300 tris, prop ≤ 800, character ≤ 3k, boss ≤ 12k. One 512² atlas per world (1024² High tier).
4. **Look:** flat-shaded low-poly + Material Maker textures + vertex-colour AO. Strong silhouettes for the gameplay
   objects (boulders, gems, keys); muted decoration.
5. **Characters:** ≤ 40 bones; clips: idle, walk, push, pull, grapple, dig, crushed, drown, celebrate. In Godot:
   `AnimationTree` with a state machine.
6. **Import:** Godot import settings: generate LODs **on** (meshoptimizer), ensure tangents on. Build tiles into a
   `MeshLibrary` for `GridMap`, or use them in `MultiMeshInstance3D`.
7. **Grey-box swap:** every tile type has an id in the sim. The view looks up `tile_id → mesh` in one resource
   (`game/view/tile_set_<world>.tres`), so swapping cubes for real art is a data change, not a code change.

## 5. Materials (Material Maker)
- One `.ptex` per surface: limestone, jade, moss, sandstone, lapis tile, slate, ice, basalt, lava crust, brass, verdigris.
- Export albedo + normal + ORM at 512² (1024² for High), tiled. Keep 2–3 colour knobs exposed so we can make variants fast.
- In Godot: `StandardMaterial3D`, roughness from the ORM map, a little triplanar on big rock walls.

## 6. Folder layout
```
assets_src/                    # source files (big, edited by hand)
  models/<world>/*.blend
  materials/*.ptex
  ui/*.aseprite, *.kra, figma-links.md
  effekseer/*.efkefc
  audio/stems/
game/assets/                   # exported, used by Godot
  fx/<effect>/sheet.png + sheet.json
  models/<world>/*.glb
  materials/<surface>/*.png
  ui/ (panels, icons, theme textures)
  fonts/
  audio/sfx, audio/music
tools/bake_fx.ps1 / bake_fx.sh # re-exports every pixelfx sheet listed in tools/fx_list.txt
CREDITS.md
```

## 7. Definition of done for any asset
- Within budget (tris, texture size, frames).
- Reads clearly at phone size: test on the real phone, not just the PC monitor.
- Works on the Compatibility renderer.
- Licence logged in `CREDITS.md` (if third-party).
- Source file is in `assets_src/` (except pixelfx effects, whose "source" is the id + options in `tools/fx_list.txt`).

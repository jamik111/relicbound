# 08 — Production Roadmap

Assumes a core team of 2–4 people. Durations are estimates. Each phase ends with a **gate review**.

| Phase | Length | Deliverables | Gate |
|---|---|---|---|
| **0. Pre-production** | 2 wks | These docs, a paper prototype of 5 rooms, tech spike (three.js + pixelfx + gltfpack on a mid-range phone) | Docs approved; spike at 60 fps |
| **1. Grey-box prototype** | 4 wks | `sim` package (move, push, fall, roll, gems, exit, keys), cube renderer, touch + keyboard input, 5 grey-box levels, rewind | "Is it fun with cubes?" Internal playtest ≥ 7/10 |
| **2. Vertical slice** | 8 wks | Final art for World 1, Nadia rigged and animated, water element, grapple, 3 levels + Stone Jaguar boss, pixelfx VFX, music theme, save, PWA | External playtest ≥ 8/10, ≥ 70% finish the slice |
| **3. Production / content alpha** | 6 mo | Worlds 2–5 elements and tools, 60 levels + 5 bosses, level editor + solver CI, cutscenes, journal, Effekseer boss VFX, Jolt debris | All content playable start to finish |
| **4. Beta & soft launch** | 6 wks | Capacitor iOS/Android, IAP, analytics, localisation, quality tiers, accessibility; soft launch in 2–3 regions + itch.io/web portal | D1 ≥ 35%, conversion ≥ 3%, crash-free ≥ 99.5% |
| **5. Launch 1.0** | 2 wks | Store pages, trailer, press kit, daily challenge live | — |
| **Post-launch** | ongoing | v1.1 polish, v1.5 player level editor + sharing codes, DLC world 6 "Atlas" | — |

## First 2 weeks: concrete tasks (start here)
1. Scaffold the pnpm monorepo (`apps/game`, `packages/sim`, `packages/levels`).
2. Implement `sim.step()` with move/push/fall/roll and unit tests for the classic edge cases (roll-off order, crush-only-when-moving).
3. Define the level JSON schema + write 5 test rooms as text grids.
4. three.js renderer: instanced cubes + an orthographic tilted camera + tick interpolation.
5. Bridge pixelfx: dust on `BoulderLanded`, sparkle on `GemCollected`.
6. Run `gltfpack` on one sample tile, load it with `MeshoptDecoder`, and measure size and fps on a real phone.
7. Rewind ring buffer + the "R" key.

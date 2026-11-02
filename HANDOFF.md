# Handoff prompt: paste this into Claude Code in VS Code

---
I'm continuing a game project that I started in another Claude Code session. Please read these first, in this order:
`CLAUDE.md`, `docs/00_INDEX.md`, `docs/06_TECH_STACK.md`, `docs/08_ROADMAP.md`, `docs/05_GDD_MECHANICS.md`, and the
skill `.claude/skills/relicbound-stack/SKILL.md`.

**Project:** *Relicbound: The Meridian Expedition*. It's an original pulp-adventure, top-down 2.5D, grid-based
action-puzzler. It's inspired by the *genre* of the old phone game Diamond Rush (boulders that fall and roll,
pushing, gems that open the exit, keys/doors, traps, secrets, bosses), plus an Indiana Jones–style discovery mood.
It's NOT a copy: original story, worlds, characters and mechanics.

**Decisions already made (don't re-open them unless I ask):**
- Platform: **Android-first native app**, then iOS, plus a small World 1 web demo for marketing.
- Engine: **Godot 4 (latest stable, ≥ 4.4) with typed GDScript**. Mobile renderer, Compatibility fallback. Jolt as the 3D physics engine. GUT for tests. GitHub Actions + headless Godot for CI/exports.
- Architecture: a **pure simulation that always resolves the same way** in `game/sim/` (RefCounted, integer grid, fixed 10 Hz tick, seeded RNG, no Nodes). `SimStep.step(state, intent) -> {state, events}`. Rendering, VFX, audio and haptics only react to sim events. Jolt is cosmetic only; navigation (Recast) is for hub NPCs only. Puzzle enemies use grid A*.
- Third-party libraries (in `third_party/`, git-ignored; run `tools/setup_third_party.sh` to clone them):
  pixelfx (pixel VFX → sprite sheets → AnimatedSprite3D; its Claude skill is in `.claude/skills/pixelfx`),
  JoltPhysics + recastnavigation + meshoptimizer (built into Godot), Effekseer (Godot 4 plugin, boss VFX),
  Material Maker (materials), FastNoise2 (noise/variety), Terrain3D + godot_voxel (optional scenery only; keep or
  drop decided in the Sprint 0 spike), ozz-animation (not used, because AnimationTree covers it).
- Business model: free World 1 + $4.99 one-time unlock, cosmetics only, no energy systems or pay-to-win.
- Story: 1936; hero Nadia Varga (a cartographer) hunts five Sunstones of the Meridian Engine and her missing mentor
  Prof. Elias Thorne, racing Baron Vael's Gilded Compass. Worlds: Jade Cenote (water), Necropolis of Qadir (sand),
  Barrow of Hrimfjall (ice), Ember Forge (lava), Meridian Core (gears/time).

**Status:** pre-production docs are done (BRD, PRD, story, GDD, tech stack, art/audio, roadmap). **No game code yet.**
The Godot project goes in `game/` and doesn't exist yet.

**Next:** start `docs/08_ROADMAP.md` → **Sprint 0, task 0.1** (create the Godot project in `game/` with the folder
layout and autoloads from the tech doc). Then 0.2, 0.3… one task at a time. Show me what you did after each task and
how to verify it.
Before coding, check what's installed on my machine (`godot --version`, Android SDK/adb, Java 17, node) and tell me
anything that's missing.
---

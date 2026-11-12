# Twicefall (codename Relicbound)
A premium indie logic puzzler for **Steam** (Windows, Steam Deck; Godot 4 + GDScript). No mobile. It's a grid puzzler inspired by the
genre of feature-phone boulder/treasure puzzlers but fully original.

- Design docs: `docs/` (start with `docs/00_INDEX.md`).
- Skills: `.claude/skills/relicbound-stack` (project rules + library playbook), `.claude/skills/pixelfx` (pixel VFX).
- Third-party sources (cloned, shallow): `third_party/`. They are references and tooling, so don't edit them.
- Godot project root: `game/` (created in Sprint 0). Current work: see `docs/08_ROADMAP.md`.
- Art, UI and VFX work: follow `docs/09_ART_PIPELINE.md` (tool map, art timing per phase, import rules, folder layout,
  asset definition of done). No final art before Gate B.
- Golden rule: the simulation always resolves the same way and is pure. Rendering, VFX and audio react to sim events only.
- Goals (2026-11-11): Steam only, solo user + Claude, no budget, Steamworks at the very end. See `docs/02_BRD.md` and
  `docs/08_ROADMAP.md`. Tokens are the only budget: batch work and read files narrowly.

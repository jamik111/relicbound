# 08 — Roadmap (Steam)
**Platform:** Steam, Windows only (Steam Deck through Proton) · **Team:** the user (product owner, 5–6 h/day) + Claude (most of the work)
· **Budget:** none, so tokens are the constraint · Replaces the Android-first roadmap (in git history before 2026-11-12).

## Where we are
Done so far, Android-first (Sprints 0–2, PRs #1–#26): a pure simulation that always resolves the same way, with
252 GUT tests and golden replays. Grey-box levels 1–9. Echoes. The temple remembers (scars, remnants, Forgets, idol saves). Responsive
controls. The playtests were all done by the user. Everything carries over except the Android and touch work.

## Phases
Estimates assume about 5–6 hours a day of the user's time and careful token use. They're guesses to be revised at each gate.

| Phase | Goal | Gate: pass criteria | Estimate |
|---|---|---|---|
| **1. Validate** | Strangers love the core on PC | **Gate B:** 5–10 new players on a PC build; most reach level 8; average fun ≥ 7/10; they ask for more unprompted | 3–4 weeks |
| **2. Look and feel** | It looks and sounds like a real game | **Gate C:** screenshots a stranger would click on; menus, settings, audio; chapter 1 polished | 6–8 weeks |
| **3. Content** | The whole game is in | **Gate D:** 3 chapters, about 45 puzzles, each solver-checked; full playthrough by 3 testers | 8–10 weeks |
| **4. Polish and beta** | Ready to sell | **Gate E:** no known blocking bugs; Steam Deck plays well; achievements; trailer, capsule art and demo build ready | ~4 weeks |
| **5. Steam release** | On sale | Steamworks set up by the user, store page live, Next Fest demo if the dates fit, then launch | Valve's waiting rules apply |

If Gate B fails, we change the design and test again.

**Decision 2026-11-12:** Twicefall becomes a **small connected 3D world**: an explorable temple hub whose doors lead to the puzzle chambers (The Witness-like, but small). No open world, no engine switch, Windows only. By the user's choice, the 3D look comes before Gate B.

## Phase 1: Validate (now)
| # | Task | Done when |
|---|---|---|
| P1.1 | **PC build:** Windows (and Linux) export preset; CI exports PC instead of Android; keyboard and gamepad first | The user plays the .exe from a CI artifact |
| P1.2 | Remove mobile-only code paths from the critical path (touch controls stay as an option) | No Android steps in CI |
| P1.3 | **Route checks:** every level is searched for every route without the hourglass (a full hourglass search is too slow in GDScript: ~2,600 steps/s) | Each level has tests that its shortcuts are closed |
| P1.3b | **Temple hub:** a walk-only level whose doors open as chambers are solved; seals open the next gallery | Done (levels 1–10) |
| P1.3c | **3D look pass:** Forward+ renderer, real torch lights, a temple tile kit made in code, a person-shaped hero with a walk, a lower and closer camera | Screenshots the user would click on |
| P1.4 | Levels 10–15: harder echo + memory puzzles, each with a recorded solution | Solver-checked; the user has played them |
| P1.5 | Onboarding pass: first-time hints, clear death and statue feedback, no dead ends without a message | A stranger gets through level 3 without help |
| P1.6 | **Playtest kit:** a zip build, a 5-question feedback form, and optional local play logs | Ready to send to friends |
| P1.7 | **Gate B playtest** with 5–10 new players | Decision: go, change, or stop |

## Later phases (planned, not yet broken down)
- **Phase 2:** art direction decided by screenshot tests; real lighting (PC can afford it); a tile kit made in code or Blender;
  menus, level select, settings (rebinding, audio, accessibility); placeholder audio, then free-licence audio.
- **Phase 3:** chapter 2 (the temple remembers) and chapter 3 (a new verb, possibly the grapple-whip); story framing;
  a level editor for our own use if it speeds up making levels.
- **Phase 4:** achievements, Steam Deck checks, performance on low-end PCs, trailer, capsule art and GIFs.
- **Phase 5:** the user decides when to start; then the Steamworks steps.

## How we work
- **Branching:** `main` is protected; one branch per feature, a PR, green CI, then Claude merges (standing permission).
- **Tokens:** batch related changes into one PR, read files narrowly, settle decisions before writing, keep replies short.
- **Testing:** the user plays on PC; feel and fun are judged by people, not by green tests.
- **Definition of done:** tests pass, it works on the user's PC, docs are updated if the rules changed.

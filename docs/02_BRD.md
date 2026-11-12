# 02 — Business Requirements Document (BRD)
**Product:** Twicefall (codename and repo: Relicbound)
**Version:** 0.2 · **Date:** 2026-11-12 · **Status:** Accepted (replaces the Android-first v0.1)

## 1. Executive summary
Twicefall is a **premium indie logic puzzler for Steam** (Windows, Steam Deck). It's a grid puzzler in the boulder and
treasure tradition, built on two original ideas. **Echoes:** rewinding leaves your past self replaying what you did.
**The temple remembers:** where you die leaves a statue, so choosing where to fall is part of the solution. It's
made by one person and Claude, with no budget.

## 2. Why Steam, not mobile (decided 2026-11-11)
- Deep logic puzzlers sell on PC. Baba Is You and Patrick's Parabox found their audience there. Premium mobile puzzle
  games struggle to be seen, and Monument Valley 3 went to Netflix Games, which then dropped the trilogy in 2025.
- Fast-scaling mobile genres (hybrid-casual sort and screw puzzles) grow through paid user acquisition and live ops,
  which we can't fund, and they contradict the game's "logic over looks" identity.
- Keyboard and gamepad remove our biggest risk on mobile, touch controls (six rounds of playtest fixes).

## 3. Business objectives
| # | Objective | Measure | Target |
|---|---|---|---|
| BO1 | People want it | Wishlists at launch | ≥ 8,000 (a "solid" launch); stretch 25,000 |
| BO2 | It sells | First-week sales | ~0.10–0.20 × wishlists (typical median range) |
| BO3 | Players love it | Steam review score | ≥ 90% positive |
| BO4 | Players finish it | Chapter 1 completion (Steam achievement) | ≥ 50% of buyers |
| BO5 | It pays its way | Revenue vs running costs (Claude subscription) | Covers costs within 12 months of launch |

These targets are rules of thumb from published Steam data, not promises: half of all games miss every one of them.

## 4. Audience
- **Primary:** PC puzzle players who love Baba Is You, Patrick's Parabox, Braid and The Witness, and play in longer
  sessions to think.
- **Secondary:** Steam Deck players, and fans of the boulder and treasure genre (Boulder Dash, Diamond Rush).
- **Language:** English at launch; localisation-ready strings.

## 5. Business model
- **Premium, one-time purchase:** about **$9.99** (under $10 tends to convert better; final price is set on the store page).
- **Free demo:** chapter 1 slice, ideally in a Steam Next Fest (February, June, October).
- No ads, no microtransactions, no energy systems, no paid hints. Expansions only after a successful launch.

## 6. Scope (v1.0)
**In:** 3 chapters, about 45 strong puzzles (4–6 hours); echoes and the temple remembers, plus one more verb in
chapter 3; keyboard and gamepad (touch removed from scope); achievements; settings; light story framing.
**Out:** mobile (all platforms), web demo, cloud accounts, multiplayer, level editor (possible post-launch),
enemies without a puzzle purpose.
**Post-launch ideas:** a daily temple with a shareable result; seeing other players' statues in the same level.

## 7. Team and budget
| Role | Who |
|---|---|
| Product owner, playtester, final approval | The user (5–6 h/day, in the loop) |
| Design, code, levels, art made in code, docs | Claude |
| External playtesters | Friends and people found by the user (unpaid) |

**Budget: none.** Our only budget is Claude tokens, so the work is planned to use them sparingly (batched changes, narrow reads).
Art must come from code, the project's art tools and free licences (CC0, CC-BY, OFL, MIT; see CREDITS.md).

## 8. Steam release requirements
- Steamworks account and a $100 app fee, paid by the user. **Decision: only at the very end**, once the game works and
  the user is happy with it. Trade-off accepted: a late store page collects fewer wishlists than an early one.
- At the time of writing, Valve requires a store page to show "Coming soon" before release, and a wait after the first
  app fee. Check the current rules when we get there.

## 9. Risks
| Risk | Response |
|---|---|
| Strangers don't find the logic satisfying | Phase 1 tests exactly this before any art or Steam work |
| Late store page means few wishlists | Make the trailer, capsule and demo ready in advance so the page launches complete |
| No art budget | Pick a style we can make well in code; test screenshots early |
| Token limits slow us down | Batch work, plan before building, and test on the user's PC |
| Name clash | "Relicbound" was taken on Steam (BT Studios, July 2025). "Twicefall" had no match when checked on 2026-11-11 |

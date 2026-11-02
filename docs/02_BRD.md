# 02 — Business Requirements Document (BRD)
**Product:** Relicbound: The Meridian Expedition (working title)
**Version:** 0.1 · **Date:** 2026-11-02 · **Status:** Draft for review

## 1. Executive summary
Relicbound is a premium-quality pulp-adventure action-puzzler. It is **web-first**: you play it instantly in a
mobile or desktop browser, and the same build is wrapped for the iOS and Android stores. It modernises the
beloved feature-phone genre (grid puzzles with boulders, treasure and traps) with 2.5D visuals, a real story and
fair, modern design that respects the player's time.

## 2. Business problem / opportunity
- Many millennial players remember this genre fondly. It ran on J2ME phones, which are gone, and no modern
  game fully fills that space.
- Mobile puzzle stores are crowded with free-to-play match-3 games. There is room for a **fair, premium-feeling
  adventure** with no energy systems.
- Web games are easy to try: share a link and play in 5 seconds. Short sessions suit commutes.
- Building from rules that always resolve the same way keeps level production cheap and makes daily challenges
  and replays almost free to add.

## 3. Business objectives
| # | Objective | Measure | Target (12 months post-launch) |
|---|---|---|---|
| BO1 | Validate demand | Web demo plays | 250k unique players |
| BO2 | Convert players to revenue | Demo → full unlock | ≥ 4% |
| BO3 | Retention | D1 / D7 / D30 | 40% / 15% / 6% |
| BO4 | Quality perception | Store rating | ≥ 4.5★ |
| BO5 | Low cost to run | Hosting cost per 1k MAU | < $2 (static hosting + CDN) |

## 4. Target market & audience
- **Primary:** ages 25–40, nostalgic for mobile games from 2005–2010, play 10–20 min sessions on their phone.
- **Secondary:** puzzle and adventure fans aged 13+ (Lara Croft GO, Monument Valley, Zelda fans).
- **Regions:** global, launched in English. Localisation support from day one (EN, ES, PT-BR, RU, TR, UZ, DE, FR, JA).
- **Devices:** Android phones from 2019 or newer (most important), iPhone 11+, desktop browsers.

## 5. Business model (recommended)
**Free demo + one-time unlock (premium):**
- World 1 (about 12 levels) is free on the web and in the stores.
- Full game unlock: **$4.99** (one time, works across platforms with an account).
- Optional cosmetic packs: explorer outfits, lantern skins. Cosmetics only.
- Optional ads only on the web demo (one rewarded ad = one extra Hourglass charge). **Never** forced ads.
- Expansion worlds later as paid DLC.

*Rejected:* energy systems or paid hints, because they break the "fair puzzle" promise and the rating target BO4.

## 6. Scope
**In scope (v1.0):** 5 worlds × 12 levels + 5 boss rooms, the story campaign, journal, Relic Kit, cloud save,
touch/keyboard/gamepad controls, web PWA + Android + iOS, the daily challenge room, analytics.
**Out of scope (v1.0):** multiplayer, user level editor (planned for v1.5), console versions, procedurally
generated campaign levels.

## 7. Stakeholders
| Role | Responsibility |
|---|---|
| Product owner (you) | Vision, priorities, final approval |
| Game designer | Levels, systems, balance |
| Engineer(s) | Engine, tools, platforms |
| Artist(s) | 3D tiles, characters, VFX, UI |
| Audio | Music and sound effects |
| QA / playtesters | Bugs, difficulty curve |

## 8. Constraints
- First download for the web demo must be **≤ 15 MB** (to load fast on mobile data). The rest streams in per world.
- Must run at 60 fps on mid-range Android; a fallback holds 30 fps.
- Small team, so we use open-source libraries (see tech doc) and avoid paying per-seat engine fees.
- All characters, settings and names are original. No IP from Diamond Rush or Indiana Jones.

## 9. Assumptions
- Players will pay a fair one-time price once they've had a good free hour.
- Web distribution (itch.io, CrazyGames/Poki portals, our own domain) supplies cheap players. Stores add revenue.

## 10. Risks
| Risk | Impact | Mitigation |
|---|---|---|
| Seen as a "clone" | Brand/legal | Original worlds, mechanics, story and art (see Genre doc §What we change) |
| Web performance on low-end phones | Churn | Quality tiers, meshoptimizer compression, pixel VFX instead of heavy particles |
| Store policy on web wrappers | Launch delay | Capacitor native shell with native IAP and real offline support |
| Level production too slow | Timeline | Text-based level format, in-game editor, automated solver checks |
| Difficulty spikes | Retention | Analytics funnels per level, Hourglass rewind, optional hints from the journal |

## 11. Success criteria / go–no-go
- **Vertical slice gate:** 3 levels + 1 boss. Playtest score ≥ 8/10 for fun, and ≥ 70% finish the slice.
- **Soft launch gate:** D1 ≥ 35%, unlock conversion ≥ 3% in test regions.

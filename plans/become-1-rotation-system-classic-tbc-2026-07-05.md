# Become the #1 Rotation System for Classic + TBC

**Started:** 2026-07-05
**Goal:** Make EaxRotations the highest-fidelity, most complete rotation system for WoW Classic (Vanilla) and TBC across solo, dungeon, raid, and PvP by grounding every spec in authoritative APLs, wowsims, guides, and pro/community sources.

## Phase 1 — Audit current state and collect sources
- [ ] Map every spec to its canonical wowsims APL / SimC APL / Class Discord PvE BiS guide.
- [ ] Identify PvP sources: classic WoW arena guides, pro streamer VoDs, class-discord PvP channels.
- [ ] Solo/leveling: community speedrun guides, Classic/TBC leveling route docs.
- [ ] Index all sources into context-mode so they can be queried without re-fetching.
- [ ] Produce gap matrix: per spec, list missing mechanics, wrong prios, outdated thresholds.

## Phase 2 — Shared-system improvements
Priority shared modules that affect every spec:
- [ ] Cooldown planner (raid trinket/ability stacking).
- [ ] Movement / pre-positioning for mechanics.
- [ ] Dynamic stat snapshotting (trinket procs, haste buffs) for DoT/Finisher decisions.
- [ ] Cleave / AoE target caps (TBC-specific: most spells have soft caps).
- [ ] PvP CC/dispel/kick priority DB per expansion.
- [ ] Dungeon/raid boss mechanic triggers (e.g., freeze on Gluth, shackles on Rage Winterchill).

## Phase 3 — Per-spec fidelity pass
- [ ] Tier 1 (highest impact): Shadow, Affliction, Feral Cat, Hunter BM/MM/Surv, Enhancement, Retribution, Fury, Arcane/Fire.
- [ ] Tier 2: Protection Paladin/Warrior, Resto Shaman/Druid/Priest, Holy Paladin/Priest, Balance.
- [ ] Tier 3: remaining specs and leveling rotations.

## Phase 4 — Validation
- [ ] Every change gated by `luac -p`.
- [ ] Every spec change covered by new or updated test case.
- [ ] Full rotation + leveling suite green before each commit.
- [ ] Compare output against wowsims hundreds-of-thousands iteration APL where possible.

## Done when
- 219 rotation + 13 leveling suites green.
- Every spec has a docstring citing its sources.
- No known APL violations from wowsims/SimC/class guides.

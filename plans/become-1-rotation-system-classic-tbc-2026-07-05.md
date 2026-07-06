# Become the #1 Rotation System for Classic + TBC

**Started:** 2026-07-05
**Goal:** Make EaxRotations the highest-fidelity, most complete rotation system for WoW Classic (Vanilla) and TBC across solo, dungeon, raid, and PvP by grounding every spec in authoritative APLs, wowsims, guides, and pro/community sources.

## Phase 1 — Audit current state and collect sources
- [x] Map every spec to its canonical wowsims APL / SimC APL / Class Discord PvE BiS guide.
- [x] Identify PvP sources: classic WoW arena guides, pro streamer VoDs, class-discord PvP channels.
- [x] Solo/leveling: community speedrun guides, Classic/TBC leveling route docs.
- [x] Index all sources into context-mode so they can be queried without re-fetching.
- [x] Produce gap matrix: per spec, list missing mechanics, wrong prios, outdated thresholds.

**Report:** `plans/research_rotation_sources_report.md`
**Audit:** agent output `tasks/8e985546-024e-4b3.output`

## Phase 1b — Emergency P0 bugfixes (completed 2026-07-05)
- [x] Shadow Priest multi-DoT spread now targets missing-dot enemies
- [x] Hunter BM/Survival Serpent Sting refresh
- [x] Hunter Marksmanship disables in-combat Aimed Shot
- [x] All changes committed with CHANGELOG.md customer-facing entries
- [x] 219 rotation + 13 leveling suites green

## Phase 2 — Shared-system improvements
Priority shared modules that affect every spec:
- [x] Cooldown planner (raid trinket/ability stacking) — v2.3.15.
- [x] Dynamic stat snapshotting — Rip/Rake AP snapshot implemented in Feral Cat.
- [ ] Movement / pre-positioning for mechanics.
- [ ] Cleave / AoE target caps (TBC-specific: most spells have soft caps).
- [ ] PvP CC/dispel/kick priority DB per expansion.
- [ ] Dungeon/raid boss mechanic triggers (e.g., freeze on Gluth, shackles on Rage Winterchill).

## Phase 3 — Per-spec fidelity pass (wowsims APL-aligned)
- [x] Arcane Mage — burn/conserve rotation with Frostbolt conserve, wowsims mana gem logic, PoM at AP end.
- [x] Affliction Warlock — Drain Soul execute at <5% HP, Shadowburn execute.
- [ ] Hunter (all specs) — shot weave overhaul, Aimed Shot pre-pull.
- [ ] Shadow Priest — Shadowfiend timing optimization, Starshards for Night Elf.
- [ ] Feral Cat — Berserk/TF optimization.
- [ ] Retribution Paladin — seal twisting investigation.
- [ ] Fury Warrior — Overpower weaving stance dance.
- [ ] Fire Mage — Combustion after 5-stack Scorch guarantee.
- [ ] Tier 2: Protection Paladin/Warrior, Resto Shaman/Druid/Priest, Holy Paladin/Priest, Balance.
- [ ] Tier 3: remaining specs and leveling rotations.

## Phase 4 — Validation
- [ ] Every change gated by `luac -p`.
- [ ] Every spec change covered by new or updated test case.
- [ ] Full rotation + leveling suite green before each commit.
- [ ] Compare output against wowsims hundreds-of-thousands iteration APL where possible.

## Done when
- 220 rotation + 13 leveling suites green.
- Every spec has a docstring citing its sources.
- No known APL violations from wowsims/SimC/class guides.

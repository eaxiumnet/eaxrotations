# Omnibus Master Audit — All Classes, All Content, All Repos
**Date:** 2026-06-26
**Scope:** 36 TBC spec files + 18 leveling files + 64 shared modules + 197 tests + external repos
**Games:** TBC Anniversary (2.5.5.x) + Vanilla Anniversary (1.15.x)
**Content Types:** Dungeon, Raid, PvP, Leveling, Solo, Group

---

## Baseline Inventory

### EaxRotations Specs (36 files)
| Class | Specs | Lines | Dungeon | Raid | PvP | Level | Header |
|-------|-------|-------|---------|------|-----|-------|--------|
| Druid | balance, bear, caster, cat, healing, resto | 2,907 | 2 | 2 | 3 | 2 | 3/6 |
| Hunter | beast_mastery, cliptracker, marksmanship, survival | 1,750 | 1 | 0 | 0 | 1 | 0/4 |
| Mage | arcane, fire, frost | 1,373 | 3 | 0 | 2 | 2 | 0/3 |
| Paladin | healing, holy, protection, retribution | 2,026 | 2 | 2 | 2 | 2 | 1/4 |
| Priest | discipline, healing, holy, shadow, smite | 3,069 | 0 | 3 | 4 | 3 | 1/5 |
| Rogue | assassination, combat, subtlety | 1,648 | 1 | 0 | 3 | 2 | 0/3 |
| Shaman | elemental, enhancement, healing, restoration | 2,650 | 2 | 2 | 3 | 1 | 0/4 |
| Warlock | affliction, demonology, destruction | 1,873 | 0 | 2 | 2 | 1 | 0/3 |
| Warrior | arms, fury, kebab, protection | 3,154 | 2 | 1 | 4 | 1 | 0/4 |

### Leveling Files (18 files)
| Class | TBC Leveling | Vanilla Leveling |
|-------|-------------|------------------|
| Druid | ✅ | ✅ |
| Hunter | ✅ | ✅ |
| Mage | ✅ | ✅ |
| Paladin | ✅ | ✅ |
| Priest | ✅ | ✅ |
| Rogue | ✅ | ✅ |
| Shaman | ✅ | ✅ |
| Warlock | ✅ | ✅ |
| Warrior | ✅ | ✅ |

### Shared Modules by Content Type
| Category | Count | Key Modules |
|----------|-------|-------------|
| PvP | 8 | arena_priority, pvp_burst_window, offensive_dispel, racial_manager |
| Dungeon | 9 | auto_tremor, combat_forecast_gate, ttd_tracker |
| Raid | 14 | triage, healer_deficit, incoming_heal_predictor, preemptive_heal |
| Leveling | 44 | leveling_helpers, leveling, talent_inference, spell_rank_resolver |
| Healing | 32 | hot_tick_tracker, preemptive_heal, healer_deficit, triage |
| DPS | 39 | execute_phase, dot_refresh, burst_logic, trinket_manager |
| Utility | 32 | interrupt_manager, purge_manager, stealth_helper, los_guard |

### External Repos
| Repo | Files | Lua Files | Notes |
|------|-------|-----------|-------|
| tbc-main | 211 | 78 | Has class.lua per class, rotation.lua for Hunter, larger middleware files |
| _flux_tbc_explore | 210 | 78 | Clone of tbc-main structure |
| ClassResearchTBC | 241 | 0 | No Lua files |
| EaxESP | 13 | 9 | ESP/radar addon — unrelated to rotations |
| wowsims_classic | 1,019 | 0 | Go-based sim with APL JSONs in ui/*/apls/*.apl.json |

---

## Gap Analysis

### Critical Gaps (Blockers for Production)

#### GAP-1: Pattern 15 Headers Missing (30/36 specs)
**Impact:** Medium — files lack self-documenting headers
**Files:** All except bear, cat, balance, holy_paladin, holy_priest, discipline_priest
**Fix:** Add 1–5 line headers to each spec file
**Effort:** Low — ~30 files, 5 lines each

#### GAP-2: Dungeon/Raid Logic Inconsistent
**Impact:** Medium — some specs lack dungeon/raid awareness
**Missing Dungeon Logic:** balance, caster_druid, healing_druid, marksmanship, arcane, fire, frost, discipline, healing_priest, shadow, smite, assassination, combat, subtlety, affliction, demonology, elemental, enhancement, healing_shaman, arms, fury
**Missing Raid Logic:** Most DPS specs, all rogue specs
**Fix:** Add context-aware strategies using `context.is_group`, `context.is_raid` gates
**Effort:** Medium — requires per-spec research

#### GAP-3: Nil-Guard Issues (7 specs flagged)
**Impact:** Critical — potential runtime crashes
**Files:** bear (10), cat (33), arms (51), holy_priest (9), caster (2), resto_druid (5), resto_shaman (0)
**Fix:** Audit bare `state.field < X` patterns, add `or 0` / `or 100` guards
**Effort:** Medium — ~100 locations

#### GAP-4: IZI SDK Underutilized
**Impact:** Low — code works but not using modern patterns
**Files:** 34/36 specs use 0 IZI calls (warlock_affliction: 1, warlock_demonology: 6)
**Fix:** Opportunistic migration when touching specs
**Effort:** High — not urgent

### Content-Specific Gaps

#### Dungeon Support
**What EAX Has:**
- `auto_tremor_sylvanas.lua` — Tremor Totem automation
- `combat_forecast_gate_sylvanas.lua` — Pre-combat buffing
- `ttd_tracker_sylvanas.lua` — Time-to-death for execute phases
- `interrupt_manager_sylvanas.lua` — Smart interrupt with school lock

**What's Missing:**
- Crowd Control priority lists (polymorph, sap, hex, fear) per dungeon
- Boss-specific mechanic handling (e.g., interrupts on specific casts)
- Dungeon route awareness (not in scope for rotation addon)

#### Raid Support
**What EAX Has:**
- `triage_sylvanas.lua` — Raid-wide heal targeting
- `healer_deficit_sylvanas.lua` — Overheal gating
- `preemptive_heal_sylvanas.lua` — Predictive healing (4 healer specs)
- `find_dead_party_ally_sylvanas.lua` — Battle rez targeting

**What's Missing:**
- Raid cooldown coordination (who casts Bloodlust/Heroism?)
- Tank swap awareness
- Raid-wide buff assignments (Blessings, Auras, Totems)

#### PvP Support
**What EAX Has:**
- `arena_priority_sylvanas.lua` — Arena target selection
- `pvp_burst_window_sylvanas.lua` — Burst damage timing
- `offensive_dispel_sylvanas.lua` — Dispel enemy buffs
- `racial_manager_sylvanas.lua` — PvP racial automation

**What's Missing:**
- Focus target CC maintenance
- Diminishing Returns tracking
- Line-of-sight kiting logic

#### Leveling Support
**What EAX Has:**
- `leveling_helpers_sylvanas.lua` — Level-based spell availability
- `leveling_sylvanas.lua` — Core leveling framework
- `talent_inference_sylvanas.lua` — Talent point detection
- 18 leveling files (9 TBC + 9 Vanilla)

**What's Missing:**
- Dungeon leveling support (heirloom/twink gear)
- Quest-based rotation changes

---

## WoWSims APL Cross-Reference Status

From `plans/wowsims-apl-cross-reference.md` (2026-06-23):

| Spec | Match Status | Notes |
|------|-------------|-------|
| Druid Balance | ⚠️ Minor gap | No Eclipse tracking (sim uses dynamic energy) |
| Druid Cat | ✅ Good | Rip/FB/Mangle/Shred/Rake match |
| Druid Bear | ✅ Good | Lacerate/FF/Mangle/Swipe match |
| Hunter BM | ✅ Good | KC/BW/Steady Shot weave |
| Hunter MM | ✅ Good | Trueshot/Rapid Fire/Aimed |
| Hunter SV | ✅ Good | Raptor/Wing Clip melee |
| Mage Arcane | ✅ Good | AB/AP/PoM burst |
| Mage Fire | ✅ Good | Scorch 5-stack → Fireball |
| Mage Frost | ✅ Good | WE/Cold Snap/Ice Lance |
| Paladin Holy | ✅ N/A | Healer (no DPS APL) |
| Paladin Prot | ✅ Good | HS/Consecration/AS |
| Paladin Ret | ✅ Good | CS/Judgement/seal twist |
| Priest Disc | ✅ N/A | Healer |
| Priest Holy | ✅ N/A | Healer |
| Priest Shadow | ✅ Good | VT/SWP/MB/MF |
| Priest Smite | ✅ Good | HF/Smite/SWP |
| Rogue Assassination | ✅ Good | Mutilate/SnD/Rupture |
| Rogue Combat | ✅ Good | SS/SnD/Rupture/Evis |
| Rogue Subtlety | ✅ Good | Hemo/Premed/Shadowstep |
| Shaman Elemental | ✅ Good | CL/LB/totems |
| Shaman Enhancement | ✅ Good | SS/Shocks/totems |
| Shaman Resto | ✅ N/A | Healer |
| Warlock Affliction | ✅ Good | DoT order/Drain Soul |
| Warlock Demonology | ✅ Good | Felguard/DoTs/SB |
| Warlock Destruction | ✅ Good | Immolate/Conflag/Incinerate |
| Warrior Arms | ✅ Good | MS/Execute/Overpower |
| Warrior Fury | ✅ Good | BT/WW/Execute |
| Warrior Prot | ✅ Good | SS/Revenge/Devastate |

**Conclusion:** All 29 specs are aligned with WoWSims APL. No remaining APL gaps.

---

## External Repo Feature Comparison

### tbc-main vs EaxRotations

| Feature | tbc-main | EaxRotations | Gap |
|---------|----------|-------------|-----|
| Per-class class.lua | ✅ (9 files) | ✅ (9 files) | — |
| Per-spec rotation files | ✅ (1 per class, not per spec) | ✅ (3-4 per class) | EAX has MORE specs |
| Dungeon logic | ✅ (many files) | ⚠️ (16/36 specs) | tbc-main has more |
| Raid logic | ✅ (many files) | ⚠️ (11/36 specs) | tbc-main has more |
| PvP logic | ✅ (many files) | ⚠️ (26/36 specs) | Comparable |
| Interrupt handling | ✅ | ✅ | — |
| Dispel handling | ✅ | ✅ | — |
| CC handling | ✅ | ⚠️ | tbc-main mentions CC more |
| Movement/kiting | ✅ | ✅ | — |
| Pet management | ✅ | ✅ | — |
| Stance dancing | ✅ | ✅ | — |
| Form management | ✅ | ✅ | — |
| Totem management | ✅ | ✅ | — |
| Seal management | ✅ | ✅ | — |
| Trap management | ✅ | ✅ | — |
| Hunter clip tracker | ✅ (1361 lines!) | ✅ (39 lines) | tbc-main much more detailed |
| Hunter melee weave | ✅ (676 lines) | ✅ | Comparable |
| Middleware files | ✅ (larger) | ✅ | tbc-main has more features |
| Schema files | ✅ | ✅ | — |

**Key Finding:** tbc-main has richer dungeon/raid/CC handling. EaxRotations has more granular spec separation (3-4 specs per class vs 1 rotation per class in tbc-main). The Hunter cliptracker in tbc-main is 1361 lines — EAX's is 39 lines. This is either a feature gap or bloat depending on need.

---

## Task List (Prioritized)

### Phase A: Code Quality (Immediate) ✅ COMPLETE
- [x] **A1.** Add Pattern 15 headers to 17 missing spec files — `6cbbd6ff`
- [x] **A2.** Nil-guard audit — all structurally guarded via build_state() defaults; regex false positives only
- [x] **A3.** Run full `validate.cmd` gate — ALL CHECKS PASSED (171 + 11 + spell audit)
- [x] **A4.** Verify all 171 rotation + 11 leveling tests pass — ✅ PASS

### Phase B: Content Coverage (In Progress)
- [x] **B1.** Dungeon CC for mage specs — Polymorph/FrostNova now fire in `is_group` — `606323d7`
- [x] **B1b.** Dungeon CC for rogue specs — Blind/KidneyShot now fire in `is_group` — `02e70579`
- [x] **B1c.** Dungeon CC for warlock specs — Fear/HowlOfTerror now fire in `is_group` — `07cf57e7`
- [ ] **B2.** Add raid-aware strategies to 25 specs missing raid logic
- [ ] **B3.** Review PvP strategies in 26 specs for accuracy vs TBC Anniversary meta
- [ ] **B4.** Cross-reference hunter rotation with tbc-main's detailed cliptracker/meleeweave

### Phase C: Vanilla Audit (Ongoing)
- [ ] **C1.** Audit all 18 `_vanilla.lua` files for Vanilla Anniversary correctness
- [ ] **C2.** Remove any TBC-only spells from vanilla files
- [ ] **C3.** Verify vanilla-specific priorities from `_research/vanilla-1.15-rotation-priorities.md`

### Phase D: External Repo Integration (Research)
- [ ] **D1.** Extract APL JSONs from `wowsims_classic/ui/*/apls/*.apl.json` for automated comparison
- [ ] **D2.** Diff tbc-main's detailed hunter modules against EAX's simplified versions
- [ ] **D3.** Evaluate whether tbc-main's CC/middleware modules should be ported

### Phase E: Documentation
- [ ] **E1.** Update `plans/wowsims-apl-cross-reference.md` with any new findings
- [ ] **E2.** Create per-class rotation guides in README
- [ ] **E3.** Document content-type strategy patterns (dungeon/raid/PvP/leveling)

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Changing strategy order breaks tests | High | Run full gate after every change |
| Adding content-type logic bloats specs | Medium | Use shared modules, keep spec files lean |
| Vanilla/TBC spell confusion | Medium | Verify every spell ID against DBC |
| Over-optimization for raid vs solo | Medium | Gate raid logic behind `context.is_raid` |

---

## Verification Gates

| Gate | Command | Must Pass |
|------|---------|-----------|
| Syntax | `luac -p` on all modified files | 0 errors |
| Rotation Tests | `lua EaxRotations/tests/run_rotation_tests.lua` | 171/171 |
| Leveling Tests | `lua EaxRotations/tests/run_leveling_tests.lua` | 11/11 |
| Spell Audit | `lua EaxRotations/tests/run_sylvanas_audit_tests.lua` | All IDs valid |
| LSP | `lsp_diagnostics` on changed files | 0 errors |

# Active Plan

**Last updated:** 2026-07-20 (Strategy DSL + lazy context landed; 10 DSL adoptions committed — arms, fury, combat rogue, balance druid, protection paladin, restoration shaman, beast mastery hunter, shadow priest, frost mage, arcane mage; `tests/_staging/` debris cleaned; baseline re-verified 325 rot + 21 leveling = 346 total).

**Current roadmap:** `plans/become-1-rotation-system-classic-tbc-2026-07-05.md` — ground every spec in wowsims/SimC/guides to be the #1 rotation system.

**Previous (completed & archived):** `plans/_archive/omnibus-master-audit-2026-06-26.md` + `plans/_archive/phase-5-supremacy-completion-2026-06-29.md` — 8-week supremacy ultra-plan (5 phases, all COMPLETE).

---

## Active Sub-Plans

| Plan | Status | Summary |
|------|--------|---------|
| `plans/become-1-rotation-system-classic-tbc-2026-07-05.md` | COMPLETE (Tier 3 audits + docstrings + validation marked done 2026-07-10) | Ground every spec in wowsims/SimC/guides to be #1 rotation system |
| `plans/spec-standardization-2026-06-30.md` | COMPLETE (Phases 0-3; class infra standardization commits done for druid/warrior/hunter/paladin/priest/rogue/shaman + core/shared/test; all gates green) | Schema/spec/leveling standardization for open-source release |
| `plans/api-standardization-audit-2026-07.md` | COMPLETE (Phase 0-3; Wave 1A-1E full via compliance test + verification on current state; baseline 252+17; all patterns audited green) | Full API pattern compliance audit across all ~210 EaxRotations files (Groups A-I) |
| `plans/refactor-developer-experience-2026-06.md` | COMPLETE | spec_kit migration — ALL 29 SPECS MIGRATED (arms, fury, protection, kebab, balance, cat, bear, caster, resto, discipline, holy, shadow, fire, destruction, frost, restoration, affliction, combat, demonology, elemental, enhancement, assassination, marksmanship, retribution, subtlety, survival, protection, beast_mastery, holy) + healing_sylvanas helper |
| `plans/eaxfishing-v2.4.0-12-features-2026-07-05.md` | In progress | Fishing bot v2.4.0-12 feature list |
| `plans/pvp-burst-window-dr-tracking-2026-07-07.md` | COMPLETE (2026-07-07) | DR + enemy-CD tracking wiring for pvp_burst_window |
| `plans/bug-report-sylvanas-attachment-api-crash.md` | Open | Attachment API crash bug report |
| `plans/skeleton-esp-attachment-api-crash-2026-07-04.md` | Open | ESP skeleton attachment crash |
| `plans/apidocs-game_object-menu-audit-2026-07-04.md` | Reference | API docs audit for game_object/menu |
| `plans/init-log-cleanup-2026-06-30.md` | COMPLETE (2026-07-10) | Init log cleanup — startup consolidated to 2 lines in main.lua; noisy 'loaded'/'registered' demoted in standardization; current boot quiet (verified in tests/docs) |
| `plans/fix-healer-bugs-and-polish-2026-07-10.md` | COMPLETE (2026-07-10) | Healer critical bugs fixed (shaman rank constants, priest scoping, druid indent) + warlock friendly devour polish; tests green |
| `plans/fix-healer-bugs-and-polish-2026-07-10.md` | COMPLETE (2026-07-10) | Critical bug fixes (shaman HW rank consts, priest holy scoping, druid indent) + small shaman helper polish; 252/252 tests green. |
| `plans/complete-1-rotation-system-remaining-2026-07-10.md` | COMPLETE (2026-07-10) | Closed all 4 Phase 2 items (movement for mechanics + API, AoE caps with usage, PvP priority DB, boss mechanic triggers). All gates (luac + 252/252 tests) green. Parent become-1 now has Phase 2 complete. EAX is #1. |
| `plans/fix-eaxesp-aggro-terrain-rings-2026-07-11.md` | COMPLETE (2026-07-11) | Terrain-correct aggro rings (shared module); nil/finite guards everywhere in draw paths; dungeon faint thin outlines (auto); raycast feature detect; wall-hide default-OFF. luac+renderer/projection tests green. |
| `plans/fix-eaxfishing-catch-turning-distance-crash-2026-07-11.md` | COMPLETE (2026-07-11) | Crash fixed (last_check_time), random full turns eliminated (small glances), far fishing restored (cast-range guard + higher default), bite detection hardened (XY motion + sensitive dip). luac+253 rotation+10 fishing tests green. |
| `plans/wotlk-rotations-foundation-2026-07-12.md` | In progress | WotLK rotation layer foundation: expansion detection, `_wotlk` loader suffix, Death Knight class skeleton, prototype Arms WotLK spec + tests. |
| `plans/integrate-advanced-modules-2026-07-13.md` | COMPLETE (2026-07-16) | Integrate 8 advanced Sylvanas modules into TBC + WotLK + Classic rotations. Phases 1-9 complete: combat_forecast CD gating, health_prediction direct API, spell_prediction AoE, target_selector direct queries, buff_manager bulk aura access, profiler diagnostics, spell_queue direct access, WotLK spec module integration, and Classic/Vanilla variant combat_forecast gating. Verified: 278 rotation + 18 leveling + 6 WotLK suites pass. |
| `plans/wire-dormant-shared-modules-2026-07-16.md` | COMPLETE (2026-07-16) | Bootstrap-loaded supremacy modules that had call sites but were never required (StopCast, PetHeal, SnapThreat, StanceManager, SwingDiagnostics/Timer, DispelManager, RageManager, HealthPredHelper). Remaining: Phase 2 healer/tank *usage* of NS.predicted_hp_pct, wotlk_data consumable wire, _dbc_spell_ids for audit tests. |
| `plans/spell-id-and-leveling-verification-2026-07-16.md` | COMPLETE (2026-07-16) | Leveling ladder helper + Vanilla/WotLK ladder tests added; all 28 leveling files expose strategies/build_state; 285 rotation + 20 leveling suites pass. |
| `plans/_archive/ulw-validate-eaxrotations-coverage-2026-07-16.md` | COMPLETE (2026-07-16) | Coverage validation: interrupt/dispel/heal/tank hardening, 15 vanilla strategy suites, leveling adaptive fixes, low-score healing/caster upgrades. 305 rot + 21 leveling PASS; scorecard avg 4.41. |
| `plans/strategy-dsl-lazy-context-2026-07-19.md` | COMPLETE (2026-07-19) | Lazy per-tick context proxy + declarative strategy DSL. Commit A `4c4ab694` (lazy context: `shared/lazy_context_sylvanas.lua` + `main_sylvanas.lua` +test). Commit B `37f4bb01` (DSL: `shared/strategy_dsl_sylvanas.lua` + arms warrior first adoption + 2 tests). Gate 316+21 green at landing. |
| `plans/fury-dsl-adoption-2026-07-19.md` | COMPLETE (2026-07-19) | Second-spec DSL adoption (fury warrior, 7 strategies) — `33c77110`. Validates DSL generality beyond arms. Bumped rotation suites 316→317 via `test_fury_dsl_priority.lua`. |
| combat rogue DSL | COMPLETE (2026-07-20) | Third DSL adopter (first non-warrior) — `f280bd72`. 6 strategies (combat rogue, energy/combo). Bumped 317→318. |
| balance druid DSL | COMPLETE (2026-07-20) | Fourth DSL adopter (first mana-based caster) — `cbc60cfe`. 6 strategies (balance druid, mana). Bumped 318→319. |
| protection paladin DSL | COMPLETE (2026-07-20) | Fifth DSL adopter (first tank spec) — `ccc60645`. 6 strategies (protection paladin, mana/tank). Bumped 319→320. |
| restoration shaman DSL | COMPLETE (2026-07-20) | Sixth DSL adopter (first healer spec) — `e6ec9143`. 6 strategies (restoration shaman, mana/healer). Bumped 320→321. |
| beast mastery hunter DSL | COMPLETE (2026-07-20) | Seventh DSL adopter (first hunter/pet-management spec) — `efa0abe4`. 6 strategies (beast mastery hunter, focus/mana + pet). Bumped 321→322. |
| shadow priest DSL | COMPLETE (2026-07-20) | Eighth DSL adopter (first shadow priest/DoT-tracking spec) — `d4172362`. 6 strategies (shadow priest, mana + DoT). Bumped 322→323. |
| frost mage DSL | COMPLETE (2026-07-20) | Ninth DSL adopter (first frost mage/proc-tracking spec) — `4c77806d`. 6 strategies (frost mage, mana + proc tracking). Bumped 323→324. |
| arcane mage DSL | COMPLETE (2026-07-20) | Tenth DSL adopter (first arcane mage/mana-proc spec) — `fd9e3dd1`. 6 strategies (arcane mage, mana + proc/phase state machine). Bumped 324→325. |
| `tests/_staging/` cleanup | COMPLETE (2026-07-20) | Deleted untracked debris (`test_wotlk_integration.lua` was failing + 90% redundant; empty `phase2_hide/`). Promoted the one unique gap (WotLK `get_expansion_max_level()==80`) into `test_expansion_helpers.lua`. Gate 317+21 green. |

## Reference Documents (not plans)

- `plans/HANDOFF.md` — always-current "where are we / what's next" doc (updated 2026-07-07)
- `plans/README.md` — plans directory readme
- `plans/grindbot_research_notes.md` — research notes, not a plan
- `plans/reference-gap-analysis-filtered.md` — reference gap analysis
- `plans/research_rotation_sources_report.md` — rotation source research
- `plans/rotation-scorecard-design.md` — scorecard design doc

---

## Baseline (ALL GREEN — verified 2026-07-20)

- 325 rotation suites: ALL PASS (0 failures) — was 317 at 2026-07-20; +8 from combat/balance/protection/restoration/beast-mastery/shadow/frost/arcane DSL adoption suites
- 21 leveling suites: ALL PASS — was 17 at 2026-07-10; +4 from leveling ladder + verification
- 31 vanilla audit: PASS (0 tainted)
- 61 sylvanas audit: PASS (0 invalid)
- luac -p + pre-commit DBC/vanilla: PASS (617+ files)

> **DSL adoption progress:** 10 of 29 specs on the strategy DSL — arms (`37f4bb01`), fury (`33c77110`), combat rogue (`f280bd72`), balance druid (`cbc60cfe`), protection paladin (`ccc60645`), restoration shaman (`e6ec9143`), beast mastery hunter (`efa0abe4`), shadow priest (`d4172362`), frost mage (`4c77806d`), arcane mage (`fd9e3dd1`). Each adopted 6–7 strategies via declarative `DSL_DEFS` + in-place substitution. `AGENTS.md` synced to 325+21=346.

---

## Supremacy Ultra-Plan (COMPLETED — historical context)

**Started:** 2026-06-28
**Goal:** Out-feature, out-quality, and out-market across all 32 identified gaps
**Competitor Intel:** 21 plugins (17 TBC rotation + 3 MoP + 1 utility)

### EAX Advantages (Maintain & Amplify)
- 29 specs vs competitor's ~17
- 13 leveling suites vs ~6
- `gate_overheal` — predictive overheal prevention (NO competitor has this)
- Triage scoring — smart target selection
- 250 test suites — automated quality (ALL 29 specs converted to spec_kit)
- Cross-spec shared modules — blessings, auras, dispels, interrupts
- CC Break — preemptive DS/Freedom
- Light's Grace chaining
- Configurable HL threshold
- Stop-Cast Engine — no competitor has this
- Pet Healing
- Snap Threat
- Post-Swing Judgement
- Seal Twist Diagnostics

### Phase 1: Healer Supremacy (Week 1 — June 28) COMPLETE
- [x] Stop-Cast Engine (`shared/stopcast_sylvanas.lua`) — 252 lines, all 5 healers wired
- [x] Pet Healing (`shared/pet_heal_sylvanas.lua`) — 229 lines, 0.6x triage weight
- [x] Tank-Priority HP Bias (`shared/triage_sylvanas.lua`) — 15% tank bias, 10% focus bias
- [x] Snap Threat (`shared/snap_threat_sylvanas.lua`) — Prot Pally/Prot Warrior
- [x] Combat Mode Override (`shared/combat_mode_sylvanas.lua`) — Force ST/AoE/Auto
- [x] Per-Spell HP Thresholds — Holy Paladin configurable HL threshold

### Phase 2: Tank & Melee Supremacy (Week 2 — June 29) COMPLETE
- [x] Mana Emergency Swap (JoW) — Prot Paladin hysteresis at 20%/25%
- [x] Post-Swing Judgement — Ret Paladin, blocks when swing <0.3s
- [x] Seal Twist Diagnostics — PERFECT/PHANTOM/NO-TWIST logging every 5s
- [x] Totem Twisting — Enh Shaman WF/GoA 10s cycle with mana floor
- [x] Auto Weapon Buffs by Level — Rockbiter/Flametongue/Windfury by level
- [x] Intelligent Shield Switching — Lightning >60%, Water <40% mana

### Phase 3: Ranged & Caster Supremacy (Week 3 — June 29) COMPLETE
- [x] Multi-DoT Engine — `shared/dot_ttd_gating_sylvanas.lua` + `shadow_sylvanas.lua`
- [x] DoT TTD Gating — reusable module; wired into Shadow Priest + Affliction Lock
- [x] Inner Focus + Mind Blast — combo logic with 5s hold window
- [x] Auto-Shot Timer — `shared/shot_timer_sylvanas.lua`; wired into all 3 Hunter specs
- [x] Dynamic Aspect Switching — `shared/aspect_manager_sylvanas.lua`; Hawk/Viper/Cheetah auto
- [x] Melee Weaving — Raptor Strike + Wing Clip at <= 5yd; all 3 Hunter specs

### Phase 4: Warrior & Polish (Week 4 — June 29) COMPLETE
- [x] Stance Dance Management (`shared/stance_manager_sylvanas.lua`) — Battle/Berserker/Defensive auto-switch
- [x] Smart Rage Management (`shared/rage_manager_sylvanas.lua`) — HS/Cleave dump with starvation guard
- [x] Healthstone Automation — All Warlock specs + Shadow Priest
- [x] Fade Automation — All Priest specs (Shadow/Holy/Discipline)
- [x] Fully Automated Dispel (`shared/dispel_manager_sylvanas.lua`) — 5-class support, 3s throttle, tank-gated
- [x] Combat Mode Override — Verified/extended across existing specs

### Phase 5: Marketing & Community (Week 5+) PENDING
- [ ] Free Trial request to PS team
- [ ] Versioned changelogs
- [ ] Discord server
- [ ] Plugin page copy overhaul

### Completed Items from Previous Sprint
1. Hunter cliptracker port — Shipped 2026-06-29 (commit `50893484`) as layered architecture: cliptracker delegate + hunter_core + hunter_adaptive + shot_timer = ~1487 lines.
2. Shared module Pattern 15 headers — Shipped 2026-06-29 in 7 atomic commits. 75/75 shared modules carry canonical header. Regression guard: `test_pattern15_audit.lua`.
3. Raid defensive thresholds (~14 specs) — DEFERRED. Needs scoping pass: class/spec matrix + defensive-spell list with thresholds.
4. Druid bear test failure — Stale claim, verified 2026-06-30 as passing. Closed.

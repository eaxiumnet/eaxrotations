# Active Plan

**Current:** `plans/ultra-plan--supremacy.md` — 8-week roadmap to dominate 
**Previous:** `plans/omnibus-master-audit-2026-06-26.md` ✅ COMPLETE

---

## 🏆 Supremacy Ultra-Plan
**Started:** 2026-06-28 
**Goal:** Out-feature, out-quality, and out-market across all 32 identified gaps 
**Competitor Intel:** 21 plugins (17 TBC rotation + 3 MoP + 1 utility)

### EAX Advantages (Maintain & Amplify)
- ✅ 29 specs vs 's ~17
- ✅ 11 leveling suites vs ~6
- ✅ `gate_overheal` — predictive overheal prevention (NO competitor has this)
- ✅ Triage scoring — smart target selection
- ✅ 196 test suites — automated quality
- ✅ Cross-spec shared modules — blessings, auras, dispels, interrupts
- ✅ CC Break — preemptive DS/Freedom
- ✅ Light's Grace chaining
- ✅ Configurable HL threshold
- ✅ Stop-Cast Engine — no competitor has this
- ✅ Pet Healing
- ✅ Snap Threat
- ✅ Post-Swing Judgement
- ✅ Seal Twist Diagnostics

### Phase 1: Healer Supremacy (Week 1 — June 28) ✅ COMPLETE
- [x] Stop-Cast Engine (`shared/stopcast_sylvanas.lua`) — 252 lines, all 5 healers wired
- [x] Pet Healing (`shared/pet_heal_sylvanas.lua`) — 229 lines, 0.6x triage weight
- [x] Tank-Priority HP Bias (`shared/triage_sylvanas.lua`) — 15% tank bias, 10% focus bias
- [x] Snap Threat (`shared/snap_threat_sylvanas.lua`) — Prot Pally/Prot Warrior
- [x] Combat Mode Override (`shared/combat_mode_sylvanas.lua`) — Force ST/AoE/Auto
- [x] Per-Spell HP Thresholds — Holy Paladin configurable HL threshold

### Phase 2: Tank & Melee Supremacy (Week 2 — June 29) ✅ COMPLETE
- [x] Mana Emergency Swap (JoW) — Prot Paladin hysteresis at 20%/25%
- [x] Post-Swing Judgement — Ret Paladin, blocks when swing <0.3s
- [x] Seal Twist Diagnostics — PERFECT/PHANTOM/NO-TWIST logging every 5s
- [x] Totem Twisting — Enh Shaman WF↔GoA 10s cycle with mana floor
- [x] Auto Weapon Buffs by Level — Rockbiter→Flametongue→Windfury by level
- [x] Intelligent Shield Switching — Lightning >60%, Water <40% mana

### Phase 3: Ranged & Caster Supremacy (Week 3 — June 29) ✅ COMPLETE
- [x] Multi-DoT Engine — `shared/dot_ttd_gating_sylvanas.lua` + `shadow_sylvanas.lua`
- [x] DoT TTD Gating — reusable module; wired into Shadow Priest + Affliction Lock
- [x] Inner Focus → Mind Blast — combo logic with 5s hold window
- [x] Auto-Shot Timer — `shared/shot_timer_sylvanas.lua`; wired into all 3 Hunter specs
- [x] Dynamic Aspect Switching — `shared/aspect_manager_sylvanas.lua`; Hawk/Viper/Cheetah auto
- [x] Melee Weaving — Raptor Strike + Wing Clip at <= 5yd; all 3 Hunter specs

### Phase 4: Warrior & Polish (Week 4 — June 29) ✅ COMPLETE
- [x] Stance Dance Management (`shared/stance_manager_sylvanas.lua`) — Battle/Berserker/Defensive auto-switch
- [x] Smart Rage Management (`shared/rage_manager_sylvanas.lua`) — HS/Cleave dump with starvation guard
- [x] Healthstone Automation — All Warlock specs + Shadow Priest
- [x] Fade Automation — All Priest specs (Shadow/Holy/Discipline)
- [x] Fully Automated Dispel (`shared/dispel_manager_sylvanas.lua`) — 5-class support, 3s throttle, tank-gated
- [x] Combat Mode Override — Verified/extended across existing specs

### Phase 5: Marketing & Community (Week 5+)
- [ ] Free Trial request to PS team
- [ ] Versioned changelogs
- [ ] Discord server
- [ ] Plugin page copy overhaul

### Baseline (ALL GREEN)
- 208 rotation suites: ALL PASS (0 failures!)
- 11 leveling suites: ALL PASS
- 31 vanilla audit: PASS (0 tainted)
- 61 sylvanas audit: PASS (0 invalid)
- 420/420 luac -p: PASS
- Critical runtime scan: 0 issues

### Current Status (as of 2026-06-29)
- Phase 1: ✅ COMPLETE (Healer Supremacy)
- Phase 2: ✅ COMPLETE (Tank & Melee Supremacy)
- Phase 3: ✅ COMPLETE (Ranged & Caster Supremacy)
- Phase 4: ✅ COMPLETE (Warrior & Polish)
- Phase 5: ⏳ PENDING (Marketing & Community)

### Remaining from Previous Sprint
1. ~~Hunter cliptracker port (tbc-main has 1361-line module vs EAX's 39-line stub)~~ ✅ Shipped 2026-06-29 (see commit 50893484) as a layered architecture: `classes/hunter/cliptracker_sylvanas.lua` (delegate) + `shared/hunter_core_sylvanas.lua` (384 lines: auto-shot timer + weapon-speed table + can_cast_steady/instant) + `shared/hunter_adaptive_sylvanas.lua` (997 lines: wowsims-port ChooseAction engine with damage formulas, clip budgets, decision log) + `shared/shot_timer_sylvanas.lua` (68 lines: pre-cast delay gate) = ~1487 lines of production code covering the same territory as tbc-main's 1361-line monolithic module. Covered by `test_hunter_shot_timer_integration.lua` and `test_hunter_melee_weave.lua` (registered in `run_rotation_tests.lua` lines 39-40).
2. ~~Shared module Pattern 15 headers (43/64 missing)~~ ✅ Shipped 2026-06-29 — audit found 59/75 shared modules needed headers; completed in 5 atomic commits (`13732fa4`, `a46dcac8`, `c5c6e8cd`, `e33fc99b`, `dfb15ed8`). 75/75 shared modules now carry the canonical 5-key Pattern 15 header (WHAT/WHEN/WHY/SAFETY/DECISION). The 5 `wowhead_data_bridge_*_index_*` files are `.gitignored` auto-generated pipeline artefacts — header injection deferred to the build generator (`build_tools/json_to_lua_data.py`).
3. Remaining raid defensive thresholds (~14 specs) — DEFERRED. The original ticket did not specify which class/spec combinations or which defences (Healthstone? Cloak of Shadows? Lifeblood? Mages' Ice Block? Priest's Desperate Prayer?). Without a concrete acceptance criterion this would degenerate into a 14-file sweep with subjective per-spec choice. Needs a follow-up scoping pass before implementation: class/spec matrix + defensive-spell list with thresholds.
4. ~~Druid bear test failure (pre-existing from another agent)~~ ✅ Stale claim. Verified 2026-06-29: `lua EaxRotations/tests/run_rotation_tests.lua` reports 209/209 pass, `run_leveling_tests.lua` reports 11/11 pass, zero failures. Bear test (`test_bear_custom_matches.lua`) is in the green suite. Closing this entry; any real bear failure should be opened as a fresh ticket.

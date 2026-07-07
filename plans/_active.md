# Active Plan

**Last updated:** 2026-07-07 (HEAD `87ffb7aa`)

**Current roadmap:** `plans/become-1-rotation-system-classic-tbc-2026-07-05.md` — ground every spec in wowsims/SimC/guides to be the #1 rotation system.

**Previous (completed & archived):** `plans/_archive/omnibus-master-audit-2026-06-26.md` + `plans/_archive/phase-5-supremacy-completion-2026-06-29.md` — 8-week supremacy ultra-plan (5 phases, all COMPLETE).

---

## Active Sub-Plans

| Plan | Status | Summary |
|------|--------|---------|
| `plans/become-1-rotation-system-classic-tbc-2026-07-05.md` | Active | Ground every spec in wowsims/SimC/guides to be #1 rotation system |
| `plans/spec-standardization-2026-06-30.md` | Active | Schema/spec/leveling standardization for open-source release |
| `plans/refactor-developer-experience-2026-06.md` | Active | spec_kit migration (23 of 29 specs done: arms, fury, protection, kebab, balance, cat, bear, caster, resto, discipline, holy, shadow, fire, destruction, frost, restoration, affliction, combat, demonology, elemental, enhancement, assassination, marksmanship) + healing_sylvanas helper |
| `plans/eaxfishing-v2.4.0-12-features-2026-07-05.md` | In progress | Fishing bot v2.4.0-12 feature list |
| `plans/pvp-burst-window-dr-tracking-2026-07-07.md` | In progress | DR + enemy-CD tracking wiring for pvp_burst_window |
| `plans/bug-report-sylvanas-attachment-api-crash.md` | Open | Attachment API crash bug report |
| `plans/skeleton-esp-attachment-api-crash-2026-07-04.md` | Open | ESP skeleton attachment crash |
| `plans/apidocs-game_object-menu-audit-2026-07-04.md` | Reference | API docs audit for game_object/menu |
| `plans/init-log-cleanup-2026-06-30.md` | Pending | Init log cleanup (no status markers) |

## Reference Documents (not plans)

- `plans/HANDOFF.md` — always-current "where are we / what's next" doc (updated 2026-07-07)
- `plans/README.md` — plans directory readme
- `plans/grindbot_research_notes.md` — research notes, not a plan
- `plans/reference-gap-analysis-filtered.md` — reference gap analysis
- `plans/research_rotation_sources_report.md` — rotation source research
- `plans/rotation-scorecard-design.md` — scorecard design doc

---

## Baseline (ALL GREEN — verified 2026-07-07)

- 234 rotation suites: ALL PASS (0 failures)
- 13 leveling suites: ALL PASS
- 31 vanilla audit: PASS (0 tainted)
- 61 sylvanas audit: PASS (0 invalid)
- 459/459 luac -p: PASS

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
- 234 test suites — automated quality (23 of 29 specs converted to spec_kit)
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

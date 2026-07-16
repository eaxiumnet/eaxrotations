# Wire dormant shared modules (2026-07-16)

## Problem
Several supremacy-phase shared modules existed, had unit tests, and had
nil-guarded call sites in specs — but were never `require`d at bootstrap, so
`NS.StopCast`, `NS.SnapThreat`, `NS.StanceManager`, etc. were always nil at runtime.

## What we did
**Bootstrap in `main.lua` `load_modules` (before class load):**
- `stopcast_sylvanas` → healers already call `NS.StopCast.update`
- `pet_heal_sylvanas` → `core_sylvanas` triage already calls `NS.PetHeal.append_entries`
- `snap_threat_sylvanas` → prot war/pally already call `NS.SnapThreat.check`
- `stance_manager_sylvanas` → prot warrior already uses `NS.StanceManager`
- `swing_diagnostics_sylvanas` → arms/fury/kebab/enh/ret `register_seals` at load
- `swing_timer_sylvanas` → `NS.SwingTimer` for hunter_adaptive; tick via dispatcher
- `dispel_manager_sylvanas` → warlock DevourMagicFriendly middleware
- `rage_manager_sylvanas` → arms/fury HS/Cleave matches
- `melee_combat_math_sylvanas` → exposes `NS.glancing_chance` etc. (pure formulas)

**`main_sylvanas.lua`:**
- Load `health_pred_helper` after `NS.health_prediction` is assigned
- Tick `NS.SwingTimer.on_update` each rotation update

**`health_pred_helper`:** lazy-read `NS.health_prediction`; expose
`NS.incoming_damage` / `NS.predicted_hp_pct` / `NS.is_tank_role`

**Arms/Fury:** use `NS.RageManager.should_heroic_strike` / `should_cleave` when present,
preserving per-spec dump thresholds via settings overlay.

## Still pending (not this change)
| Item | Status |
|------|--------|
| `integrate-advanced-modules` Phase 2.3–2.8 | Specs still need to *call* `NS.predicted_hp_pct` / `NS.incoming_damage` in holy pally, resto druid, tanks (plan TODOs remain) |
| Phase 2.1/2.2/2.5 marked DONE in plan | **Incorrect** — no class file required HealthPred before this; only helper existed. Follow-up: wire into holy/disc/resto matches |
| `wotlk_data_sylvanas` | Pure data; wire into consumable_manager when `NS.is_wotlk()` |
| `_dbc_spell_ids` | Audit-test data only (`low-level-spell-coverage-test-design.md`) — not runtime |
| `auto_wire_sylvanas` | Proposed in archived phase-5 plan; not needed if main.lua bootstrap stays complete |
| Arms/Fury stance via StanceManager | Still use `WH.desired_stance`; only Prot uses StanceManager |

## Plans relationship
- Supremacy Phase 1–4 claimed these “wired” but only call sites + modules existed
- Active `integrate-advanced-modules-2026-07-13.md` Phase 2 is the remaining *behavior* work for health prediction
- This plan is the missing **bootstrap** layer those call sites assumed

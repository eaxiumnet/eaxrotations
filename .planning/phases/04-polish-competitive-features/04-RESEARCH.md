# Phase 04: Polish & Competitive Features - Research

**Date:** 2026-03-20
**Scope:** VIS-01..04, AUTO-01..04, QUAL-01..03

## Current Baseline

- `EAX*/esp_renderer.lua` already renders next-action HUD + target label and supports proc bars.
- `EAX*/main.lua` already emits cast events via `esp_renderer.on_cast(...)` and uses per-spec `ttd_tracker.lua`.
- Shared modules are effectively centralized under `eax_shared/` and consumed via `require("common/eax_shared/...)")`.
- No automated test framework exists; repo relies on `luac -p` + grep-based verification + in-game validation.

## Findings

### Visual Features (VIS-01..VIS-04)

1. **DPS/HPS meter (VIS-01)**
   - Best implemented once in `eax_shared/dps_meter.lua` with API:
     - `on_combat_start()`, `on_damage(amount)`, `on_heal(amount)`, `on_combat_end()`
     - `get_snapshot()` returning fight totals and per-second rates.
   - Wire per-spec `main.lua` to feed meter from player combat log helpers already used by specs.

2. **Cooldown timer display (VIS-02)**
   - Add shared helper `eax_shared/cooldown_tracker.lua` exposing `set_next_spell(spell_id, cast_at)` and `seconds_remaining(now)`.
   - HUD should show `NEXT CD: <seconds>s` for current recommended action.

3. **TTD display (VIS-03)**
   - Keep existing per-spec `ttd_tracker.lua` logic; add standardized HUD readout in `esp_renderer.lua`.
   - Standard fallback: display `TTD: --` when estimator returns `999`.

4. **Buff/debuff tracker display (VIS-04)**
   - Use shared `buff_manager` queries in `main.lua` and pass compact status list to renderer.
   - Renderer draws up to N tracked effects with active/inactive colors.

### Automation Features (AUTO-01..AUTO-04)

1. **Auto-repair and auto-sell greys (AUTO-01, AUTO-02)**
   - Reuse proven vendor flow from `EAXFishing/inventory/vendor.lua`:
     - `core.inventory.get_total_repair_cost`
     - `core.input.repair_all_items(...)`
   - Implement shared `eax_shared/vendor_automation.lua` to avoid 27 duplicated implementations.

2. **Consumables management (AUTO-03)**
   - Existing per-spec potion logic is fragmented.
   - Consolidate in `eax_shared/consumables_manager.lua` with explicit policy functions for:
     - combat potions
     - food/drink OOC upkeep

3. **Auto-mount/dismount (AUTO-04)**
   - Implement `eax_shared/mount_manager.lua` with combat-state gate:
     - dismount immediately when entering combat
     - mount only when out of combat + stationary + no hostile target in melee range

### Quality Features (QUAL-01..QUAL-03)

1. **Rotation validation framework (QUAL-01)**
   - Create Lua validation runner under `tools/rotation_validation.lua` with deterministic checks:
     - required exports in each `main.lua`
     - required shared module imports
     - syntax validity via `luac -p` shell invocation.

2. **DPS benchmark tool (QUAL-02)**
   - Create `tools/dps_benchmark.lua` reading snapshots from `eax_shared/dps_meter.lua` and writing CSV/markdown summary.

3. **Spec regression checklist (QUAL-03)**
   - Create `.planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md` with all 27 specs and pass/fail rows.

## Decisions for Planning

- Use **shared modules first**, then bulk-wire to specs.
- Keep existing per-spec TTD estimators; only standardize display contract.
- Base vendor automation on `EAXFishing` APIs to avoid undocumented calls.
- Enforce grep/luac command verification in every task because no unit test framework exists.

## Risks / Pitfalls

- Path drift (`common/eax_shared` vs `eax_shared`) has caused prior plan deviations.
- Bulk 27-file edits can silently miss one spec; use explicit spec lists in acceptance checks.
- Different specs already have custom potion behavior; shared consumables manager must preserve opt-in toggles.

## Validation Architecture

- **Wave 0:** ensure validation scripts exist and can run in <60s with grep/luac.
- **Per task:** run targeted `rtk rg` checks + `rtk luac -p` on touched files.
- **Per wave:** run all phase validation scripts:
  - `rtk lua tools/rotation_validation.lua`
  - `rtk lua tools/dps_benchmark.lua --dry-run`
  - `rtk rg -n "\[ \]|\[x\]" .planning/phases/04-polish-competitive-features/04-REGRESSION-CHECKLIST.md`

## RESEARCH COMPLETE

Phase 04 can be planned as 5 execution plans across 3 waves:
- Wave 1 foundations: visual core + automation core
- Wave 2 bulk spec wiring
- Wave 3 quality/benchmarking gates

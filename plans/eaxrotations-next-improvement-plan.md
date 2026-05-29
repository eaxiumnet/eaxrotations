# EaxRotations Next Improvement Plan

Date: 2026-05-29
Scope: `EaxRotations/`, `api/`, `apidocs/`
Goal: choose the next highest-impact implementation path for improving EaxRotations without inventing unsupported Sylvanas APIs.

## Executive Recommendation

The next step should be a **healing + interrupt + TTD consolidation pass**, not a brand-new subsystem from scratch.

EaxRotations already has strong foundations:

- predictive healing/overheal logic in `EaxRotations/shared/healer_deficit_sylvanas.lua`
- incoming heal prediction in `EaxRotations/shared/incoming_heal_predictor_sylvanas.lua`
- healing entry construction in `EaxRotations/core_sylvanas.lua`
- centralized interrupt strategy in `EaxRotations/shared/interrupt_manager_sylvanas.lua`
- layered TTD tracking in `EaxRotations/shared/ttd_ema_tracker_sylvanas.lua`, `EaxRotations/shared/ttd_tracker_sylvanas.lua`, and `EaxRotations/main_sylvanas.lua`
- centralized spell queue/cast backend in `EaxRotations/core_sylvanas.lua`

The gap is adoption and consistency across specs.

Priority order:

1. Finish healer adoption of `HealerDeficit`/overheal gates across resto druid and resto shaman.
2. Route bespoke interrupt logic through `InterruptManager`.
3. Expand TTD consumers and normalize `context.ttd`/`context.ttd_known` use.
4. Audit remaining direct/bespoke cast paths so all rotation actions use the queue-first backend.
5. Add focused tests after each phase.

---

## Phase 0 — Documentation Discovery Baseline

### Sources consulted

API/docs discovery:

- `apidocs/pages/dev/libraries/modules/health-prediction.md:13-69`
- `apidocs/pages/dev/libraries/modules/combat-forecast.md:43-100`
- `apidocs/pages/dev/libraries/modules/spell-prediction.md:67-341`
- `apidocs/pages/dev/modules/spell-queue.md:50-284`
- `apidocs/pages/dev/api/spell-helper.md:126-320`
- `apidocs/pages/dev/api/movement-handler.md:38-202`
- `apidocs/pages/dev/api/kick-external-filters.md:13-175`
- `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:326-2795`
- `apidocs/pages/dev/libraries/izi/izi-spells.md:35-1279`
- `apidocs/pages/dev/libraries/izi/units.md:96-282`
- `apidocs/pages/dev/modules/buff-manager.md:34-151`
- `api/common/utility/cc_data_helper.lua:1-124`
- `api/common/enums.lua:27-390`
- `api/common/unit_manager.lua:10-27`
- `apidocs/pages/dev/api/core.md:23-215`
- `apidocs/pages/dev/api/input.md:14-446`

Current-code discovery:

- `EaxRotations/common_sylvanas.lua:68-98`
- `EaxRotations/main_sylvanas.lua:365-559`
- `EaxRotations/core_sylvanas.lua:118-132,1015-1227,2200-2494,3265-3295,3977-3990,4180-4234`
- `EaxRotations/shared/ttd_tracker_sylvanas.lua:1-260`
- `EaxRotations/shared/ttd_ema_tracker_sylvanas.lua:1-220`
- `EaxRotations/shared/healer_deficit_sylvanas.lua:1-397`
- `EaxRotations/shared/incoming_heal_predictor_sylvanas.lua:1-520`
- `EaxRotations/shared/interrupt_manager_sylvanas.lua:1-307`
- sampled specs: `classes/priest/discipline_sylvanas.lua`, `classes/paladin/holy_sylvanas.lua`, `classes/shaman/enhancement_sylvanas.lua`, `classes/warrior/middleware_sylvanas.lua`, `classes/warrior/protection_sylvanas.lua`

### Allowed APIs

Healing / incoming damage:

- `health_prediction:get_incoming_damage(target, deadline_time_in_seconds, is_exception?) -> number`
  - source: `apidocs/pages/dev/libraries/modules/health-prediction.md:53-55`
- `unit:get_incoming_damage(deadline_time_in_seconds, is_exception?) -> number`
  - source: `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:326-354`
- `unit:get_health_percentage_inc(deadline_time_in_seconds) -> hp, incoming_heal, absorb, incoming_damage`
  - source: `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:377-409`

TTD / fight length:

- `combat_forecast:get_forecast() -> number`
- `combat_forecast:get_forecast_single(unit, include_pvp?) -> number`
- `combat_forecast:get_min_combat_length(...)`
- `combat_forecast:is_valid_forecast_logic(...)`
  - source: `apidocs/pages/dev/libraries/modules/combat-forecast.md:59-73`
- `unit:get_time_to_death() -> number`
- `unit:time_to_die() -> number`
  - source: `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:1150-1168`

Interrupt/cast telemetry:

- `unit:is_casting()`
- `unit:get_cast_remaining_ms()`
- `unit:get_cast_pct()`
- channel equivalents
- `unit:get_active_cast_or_channel_id()`
  - source: `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:1543-1920`
- Universal Kicks external filters:
  - `ext.register(name, func, opts?)`
  - `ext.apply(...)`
  - `ext.list()`
  - `ext.touch()`
  - `ext.unregister()`
  - source: `apidocs/pages/dev/api/kick-external-filters.md:55-129`

Spell queue/cast pipeline:

- `spell_queue:queue_spell_target(spell_id, target, priority, message?, allow_movement?)`
- `spell_queue:queue_spell_target_fast(...)`
- `spell_queue:queue_spell_position(...)`
- `spell_queue:get_queue_snapshot()`
- `spell_queue:purge_by_spell(spell_id, target?)`
  - source: `apidocs/pages/dev/modules/spell-queue.md:101-244`
- `spell_helper:is_spell_castable(...)`
- `spell_helper:is_spell_queueable(...)`
  - source: `apidocs/pages/dev/api/spell-helper.md:126-157`
- `spell:cast_safe(target?, message?, opts?)`
- `spell:is_castable_to_unit(...)`
  - source: `apidocs/pages/dev/libraries/izi/izi-spells.md:776-892`

Movement / facing:

- `movement_handler:pause_movement(...)`
- `movement_handler:pause_movement_light(...)`
- `movement_handler:resume_movement(...)`
- `movement_handler:look_at_target(...)`
- `movement_handler:look_at_position(...)`
- `movement_handler:on_render()`
  - source: `apidocs/pages/dev/api/movement-handler.md:38-202`

Aura / resource:

- `buff_manager:get_buff_data(unit, enum_key, custom_cache_duration_ms?)`
- `buff_manager:get_debuff_data(...)`
- `buff_manager:get_aura_data(...)`
  - source: `apidocs/pages/dev/modules/buff-manager.md:46-89`
- `unit:buff_up`, `unit:buff_remains`, `unit:get_buff_stacks`, debuff/aura equivalents
  - source: `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:565-1046`
- `unit:get_aura_description_value(spec, search_type?, as_percentage?)`
  - source: `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:1048-1070`
- `unit:power_current()`, `power_pct()`, `power_deficit()`, energy/focus prediction helpers
  - source: `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:1996-2623`

CC / immunity:

- `cc_data_helper.is_susceptible`, `is_stunnable`, `is_silenceable`, etc.
  - source: `api/common/utility/cc_data_helper.lua:102-124`
- `unit:is_cc_immune(type_flags?, min_remaining_ms?, ignore_dot?, dot_blacklist?)`
  - source: `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:442-475`
- `enums.cc_flags`, `enums.damage_type_flags`
  - source: `api/common/enums.lua:315-390`

### Anti-patterns to avoid

- Do not invent a direct Universal Kicks “cast interrupt now” API. Documented integration is filter-based.
- Do not invent a DR tracker. Only CC immunity/static susceptibility APIs were found.
- Do not use raw `core.input.cast_*` for rotation spam unless the existing centralized fallback reaches it.
- Do not use spell queue priority to encode rotation order. Docs say use priority `1`; rotation order should come from strategy ordering and early returns.
- Do not treat `spell_helper:get_spell_damage/get_spell_healing` as exact simulation; docs describe tooltip parsing, not perfect math.
- Do not add WotLK/Cata spells or APIs outside `api/`/`apidocs/`.

---

## Phase 1 — Finish Predictive Healing Adoption

### Objective

Make every healer consume the existing predictive healing/overheal system consistently.

Current evidence:

- `EaxRotations/shared/healer_deficit_sylvanas.lua:219-324` computes predicted absolute deficit using incoming damage, incoming heals, shields, HP-loss rate, caps, and safety margin.
- `EaxRotations/shared/healer_deficit_sylvanas.lua:334-385` exposes `gate_spell_overheal` and `heal_would_overheal`.
- `EaxRotations/core_sylvanas.lua:4187-4218` integrates predicted deficit into `build_healing_entries`, sorting by `effective_hp` and exposing `incoming_dps` / `time_to_die`.
- `classes/priest/discipline_sylvanas.lua:280-301` and `classes/paladin/holy_sylvanas.lua:589-728` already show adoption patterns.
- Adoption appears uneven in resto druid and resto shaman paths.

### Implementation tasks

1. Read these files before editing:
   - `EaxRotations/shared/healer_deficit_sylvanas.lua`
   - `EaxRotations/shared/incoming_heal_predictor_sylvanas.lua`
   - `EaxRotations/core_sylvanas.lua`
   - `EaxRotations/classes/priest/discipline_sylvanas.lua`
   - `EaxRotations/classes/paladin/holy_sylvanas.lua`
   - `EaxRotations/classes/druid/resto_sylvanas.lua`
   - `EaxRotations/classes/shaman/healing_sylvanas.lua`

2. Copy the existing pattern from discipline priest / holy paladin:
   - For each direct heal, call `NS.HealerDeficit.gate_spell_overheal(...)` before casting.
   - For HoTs/shields, use a conservative predicted-deficit gate and existing aura checks.
   - Preserve existing spell priority ordering unless the current order clearly fights predicted healing.

3. Ensure healing decisions prefer:
   - low `effective_hp`
   - real danger from `incoming_dps` / `time_to_die`
   - reduced overheal from `gate_spell_overheal`

4. Do not create a new healing engine module in this phase. Reuse the existing one.

### Documentation references

- Incoming damage API: `apidocs/pages/dev/libraries/modules/health-prediction.md:53-66`
- IZI incoming damage API: `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:326-409`
- Current healing gate: `EaxRotations/shared/healer_deficit_sylvanas.lua:334-385`
- Existing adoption examples:
  - `EaxRotations/classes/priest/discipline_sylvanas.lua:280-301`
  - `EaxRotations/classes/paladin/holy_sylvanas.lua:589-728`

### Verification checklist

- `luac -p` on every modified healer file.
- Run:
  - `lua EaxRotations/tests/run_rotation_tests.lua`
  - `lua EaxRotations/tests/run_leveling_tests.lua`
- Add or update focused tests proving:
  - low current HP still heals
  - incoming damage raises priority before HP drops
  - incoming heals prevent unnecessary duplicate large heals
  - shield/HoT refresh logic does not spam when absorb/HoT remains sufficient

### Anti-pattern guards

- Do not reintroduce inverted return-value gates where an `else return true` accidentally skips valid heals.
- Do not call expensive scan APIs before their settings guards.
- Do not use bare numeric state comparisons like `state.hp < 50`; use safe defaults.
- Do not access menu widgets directly without nil guards.

---

## Phase 2 — Centralize Interrupt Consumers

### Objective

Move specs away from bespoke `target_is_casting` / `NS.try_interrupt` checks and toward `InterruptManager` where practical.

Current evidence:

- `EaxRotations/shared/interrupt_manager_sylvanas.lua:256-286` gates interrupts by control state, GCD, target casting, cast window, humanized delay, and readiness.
- `EaxRotations/shared/interrupt_manager_sylvanas.lua:175-218` supports priority IDs.
- `EaxRotations/shared/interrupt_manager_sylvanas.lua:220-245` supports cast-window percent APIs.
- `EaxRotations/shared/interrupt_manager_sylvanas.lua:111-152` supports humanization.
- `EaxRotations/common_sylvanas.lua:68-75` exposes interrupt humanization settings.
- `EaxRotations/core_sylvanas.lua:3265-3295` currently has a broad probe that can return true for cast/channel/spell_id without priority/window/humanization.
- `EaxRotations/classes/shaman/enhancement_sylvanas.lua:259-267` sets `target_can_interrupt = target_is_casting`, ignoring richer interruptibility checks.

### Implementation tasks

1. Trace `InterruptManager` load/export path before editing.
   - Confirm it is loaded by the runtime entrypoint.
   - Confirm `NS.register_interrupt_spell(...)` is available.

2. For specs with interrupt actions:
   - Register interrupt spells via `NS.register_interrupt_spell(class_key, spell_name, spell_table, required)` from `EaxRotations/shared/interrupt_manager_sylvanas.lua:289-297`.
   - Route strategy match functions through `InterruptManager` instead of direct `target_is_casting` checks.

3. Keep direct fallback only where the manager is unavailable, and guard it tightly.

4. Add `is_interruptible` or equivalent checks where existing code only checks `target_is_casting`.

### Documentation references

- Cast telemetry APIs: `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:1543-1920`
- Universal Kicks filter docs: `apidocs/pages/dev/api/kick-external-filters.md:55-129`
- Existing interrupt manager:
  - `EaxRotations/shared/interrupt_manager_sylvanas.lua:111-152`
  - `EaxRotations/shared/interrupt_manager_sylvanas.lua:175-286`
  - `EaxRotations/shared/interrupt_manager_sylvanas.lua:289-297`

### Verification checklist

- Grep for direct interrupt patterns:
  - `target_is_casting`
  - `target_can_interrupt`
  - `NS.try_interrupt`
  - `is_casting()` near class strategies
- Confirm intentional direct fallbacks are documented in code by structure, not comments.
- Add or update tests for:
  - no interrupt before configured cast percent
  - interrupt fires inside allowed window
  - non-priority casts can be skipped when settings require priority
  - humanized delay does not permanently block interrupts
- Run full rotation and leveling test suites.

### Anti-pattern guards

- Do not invent a Universal Kicks cast API.
- Do not assume every cast is interruptible.
- Do not bypass GCD/control-state checks.
- Do not make interrupts fire from raw target casting state alone.

---

## Phase 3 — Normalize TTD Consumers

### Objective

Make specs use the existing `context.ttd` contract consistently for execute windows, cooldown holds, DoT refreshes, and short-lived target decisions.

Current evidence:

- `EaxRotations/main_sylvanas.lua:450-484` documents the fallback chain: EMA TTD, regression TTD, engine TTD, nil.
- `EaxRotations/main_sylvanas.lua:485-502` implements EMA → regression → engine.
- `EaxRotations/shared/ttd_ema_tracker_sylvanas.lua:124-207` computes DPS/TTD from combat-log events.
- `EaxRotations/shared/ttd_tracker_sylvanas.lua:156-231` computes HP%-based regression TTD.
- Regression is currently only attempted for bosses or higher-level targets in `EaxRotations/main_sylvanas.lua:487-488`.

### Implementation tasks

1. Read:
   - `EaxRotations/main_sylvanas.lua:450-502`
   - `EaxRotations/shared/ttd_ema_tracker_sylvanas.lua`
   - `EaxRotations/shared/ttd_tracker_sylvanas.lua`
   - specs with execute/DoT/cooldown logic

2. Audit consumers of:
   - `context.ttd`
   - `context.ttd_known`
   - local TTD helpers
   - target HP execute gates

3. Replace ad-hoc short-target logic with `context.ttd` where already available.

4. Consider extending regression usage to non-boss targets only if tests show stable behavior.
   - Keep EMA first.
   - Keep engine TTD as fallback unless reliability evidence supports raising it.

5. Use TTD for:
   - skipping long DoTs on targets about to die
   - avoiding long cooldowns on nearly dead trash
   - execute-mode decisions where HP percent alone is insufficient
   - pet/summon or ramp actions that need a minimum fight length

### Documentation references

- Combat forecast docs: `apidocs/pages/dev/libraries/modules/combat-forecast.md:59-73`
- IZI unit TTD: `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:1150-1168`
- IZI TTD target-selection example: `apidocs/pages/dev/libraries/izi/units.md:241-276`
- Current EaxRotations contract: `EaxRotations/main_sylvanas.lua:450-502`

### Verification checklist

- Add or update tests for:
  - DoT skipped when known TTD is below DoT value window
  - execute still works when `ttd_known` is false but HP threshold is met
  - cooldown held on very short TTD target
  - cooldown allowed on boss/high-TTD target
- Run full rotation and leveling tests.

### Anti-pattern guards

- Do not treat nil TTD as 0. Unknown TTD must not mean “target is dying now.”
- Do not block core execute abilities solely because TTD is unknown.
- Do not add precise DPS simulation from tooltip parser APIs.
- Do not make equal/lower-level trash rely only on unstable native TTD without fallback.

---

## Phase 4 — Queue-First Cast Path Audit

### Objective

Ensure class/spec code relies on `NS.try_cast` / `NS.evaluate_cast` / existing action execution instead of bypassing the centralized queue-first backend.

Current evidence:

- `EaxRotations/core_sylvanas.lua:118-119` imports `common/modules/spell_queue`.
- `EaxRotations/core_sylvanas.lua:2271-2349` centralizes cast guards: spell helper castability, anti-flicker, min interval, reagent, immunity.
- `EaxRotations/core_sylvanas.lua:2387-2400` prefers `spell_queue:queue_spell_target`.
- `EaxRotations/core_sylvanas.lua:2402-2417` uses IZI `cast_safe` fallback.
- `EaxRotations/core_sylvanas.lua:2419-2437` falls back to direct input.
- `EaxRotations/core_sylvanas.lua:2460-2484` mirrors this for position casts.

### Implementation tasks

1. Grep class/spec/shared code for direct calls to:
   - `core.input.cast_target_spell`
   - `core.input.cast_spell`
   - `queue_spell_target`
   - `cast_safe`
   - `spell_helper:is_spell_castable`

2. For class/spec rotation actions, prefer existing action definitions and `NS.try_cast` path.

3. Keep direct spell queue use inside core/shared backend only unless there is a documented exception.

4. Preserve existing fallback order:
   - spell queue
   - IZI `cast_safe`
   - direct input fallback

5. Do not change spell queue priority to encode rotation ordering. Keep priority `1` unless the existing backend has a documented exception.

### Documentation references

- Spell queue API: `apidocs/pages/dev/modules/spell-queue.md:101-244`
- Queue best practices: `apidocs/pages/dev/modules/spell-queue.md:246-284`
- Spell helper castability: `apidocs/pages/dev/api/spell-helper.md:126-157`
- IZI safe casts: `apidocs/pages/dev/libraries/izi/izi-spells.md:776-892`
- Current backend: `EaxRotations/core_sylvanas.lua:2271-2437`

### Verification checklist

- Grep confirms class/spec files do not directly spam raw input cast APIs.
- Existing direct uses are either core backend or documented special cases.
- Full rotation and leveling suites pass.
- Lua syntax passes on all modified files.

### Anti-pattern guards

- Do not bypass `NS.evaluate_cast` guards.
- Do not queue with variable priority to force rotation order.
- Do not remove IZI fallback.
- Do not remove direct input fallback unless tests and runtime compatibility prove it is safe.

---

## Phase 5 — Optional Movement/Position Enhancements

### Objective

Only after Phases 1-4, consider movement-safe positioning improvements for spells that already need facing/positioning.

### Implementation tasks

1. Identify existing position spells or casts failing due to facing/movement.
2. Prefer `movement_handler` over raw input.
3. Keep movement interventions short and gated by explicit cast need.
4. Ensure `movement_handler:on_render()` is wired only if required by docs and already compatible with project render flow.

### Documentation references

- Movement handler docs: `apidocs/pages/dev/api/movement-handler.md:38-202`
- Raw input warning / queue recommendation: `apidocs/pages/dev/api/input.md:14-60`
- Look/facing APIs: `apidocs/pages/dev/api/input.md:396-446`

### Verification checklist

- No movement lock remains after failed/blocked casts.
- Position spells still use `NS.try_cast_position` or existing backend.
- Tests pass.

### Anti-pattern guards

- Do not add broad auto-movement to every spell.
- Do not disable movement without guaranteed resume.
- Do not use raw movement/facing APIs when `movement_handler` can handle the case.

---

## Phase 6 — Test and Regression Matrix

### Objective

Lock in the improvements with focused tests and full-suite validation.

### Required checks

For every modified Lua file:

```bash
rtk luac -p <file>
```

Full suites:

```bash
rtk lua EaxRotations/tests/run_rotation_tests.lua
rtk lua EaxRotations/tests/run_leveling_tests.lua
```

Recommended greps:

```bash
rtk grep "core\.input\.cast" EaxRotations/classes EaxRotations/shared
rtk grep "target_is_casting\|target_can_interrupt\|NS\.try_interrupt" EaxRotations/classes EaxRotations/shared
rtk grep "gate_spell_overheal\|heal_would_overheal" EaxRotations/classes/druid EaxRotations/classes/shaman EaxRotations/classes/priest EaxRotations/classes/paladin
rtk grep "context\.ttd\|ttd_known" EaxRotations/classes
```

### Acceptance criteria

- All modified files pass `luac -p`.
- Rotation test suite passes.
- Leveling test suite passes.
- Healers share the same predictive-overheal pattern unless a spec has a concrete reason not to.
- Interrupt consumers use shared manager semantics instead of direct cast-state checks where possible.
- TTD unknown state remains safe and does not block core abilities.
- Cast path remains queue-first with IZI and direct input fallbacks intact.

---

## Suggested Execution Order for New Sessions

### Session A — Healing adoption

Prompt:

```text
Execute Phase 1 from plans/eaxrotations-next-improvement-plan.md. Read the cited docs/files first. Update resto druid and resto shaman healing logic to use existing HealerDeficit/overheal gates consistently with discipline priest and holy paladin patterns. Do not create new shared modules. Run luac on modified files and both rotation/leveling test suites.
```

### Session B — Interrupt consolidation

Prompt:

```text
Execute Phase 2 from plans/eaxrotations-next-improvement-plan.md. Read interrupt_manager and cited docs first. Audit specs with direct interrupt checks, route them through InterruptManager where practical, and preserve safe fallbacks only when necessary. Add/update tests for cast window and priority behavior. Run luac and both test suites.
```

### Session C — TTD consumers

Prompt:

```text
Execute Phase 3 from plans/eaxrotations-next-improvement-plan.md. Read the TTD trackers and main_sylvanas TTD contract first. Normalize execute, DoT, cooldown, and short-lived-target decisions around context.ttd/context.ttd_known without treating unknown as zero. Add focused tests and run full suites.
```

### Session D — Cast path audit

Prompt:

```text
Execute Phase 4 from plans/eaxrotations-next-improvement-plan.md. Audit direct cast/queue/helper calls in classes and shared modules. Keep rotation actions on the centralized NS.try_cast/evaluate_cast backend unless a documented exception exists. Preserve queue -> IZI -> input fallback order. Run greps, luac, and both test suites.
```

---

## Final Recommendation

Start with **Session A: Healing adoption**.

Reason: the healing engine work is already partially implemented and likely gives the largest immediate user-visible quality boost. It also reduces overheal bugs and makes future TTD/incoming-damage features easier to consume through a consistent healing-entry contract.

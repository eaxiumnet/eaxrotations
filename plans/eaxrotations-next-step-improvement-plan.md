# EaxRotations Next-Step Improvement Plan

## Goal

Move EaxRotations from “complete and stable” to “top-tier adaptive rotations” by prioritizing evidence-backed upgrades from `api/`, `apidocs/`, and current shared systems. The next best step is not a brand-new engine from scratch; it is to finish adoption of the systems already started, then layer documented Sylvanas capabilities on top.

## Phase 0 — Documentation Discovery Baseline

### Allowed APIs and evidence

**Predictive healing / incoming damage**
- `health_prediction:get_incoming_damage(target, deadline_time_in_seconds, is_exception?) -> number` — `apidocs/pages/dev/libraries/modules/health-prediction.md:53-55`
- IZI unit wrappers:
  - `unit:get_incoming_damage(deadline_time_in_seconds, is_exception?)` — `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:326-354`
  - `unit:get_health_percentage_inc(deadline_time_in_seconds)` — `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:377-409`
  - `unit:get_incoming_damage_types(deadline_time_in_seconds?, is_exception?)` — `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:356-375`

**Time-to-die / fight forecasting**
- `combat_forecast:get_forecast()`, `get_forecast_single(unit, include_pvp?)`, `get_min_combat_length(...)`, `is_valid_forecast_logic(...)` — `apidocs/pages/dev/libraries/modules/combat-forecast.md:59-73`
- `unit:get_time_to_death()` / `unit:time_to_die()` — `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:1150-1168`
- Target selection example using `enemy:time_to_die()` — `apidocs/pages/dev/libraries/izi/units.md:241-276`

**Spell queue / casting**
- `spell_queue:queue_spell_target(spell_id, target, priority, message?, allow_movement?)` — `apidocs/pages/dev/modules/spell-queue.md:101-113`
- `queue_spell_target_fast(...)` — `apidocs/pages/dev/modules/spell-queue.md:116-128`
- `queue_spell_position(...)` / `_fast(...)` — `apidocs/pages/dev/modules/spell-queue.md:130-152`
- `get_queue_snapshot()` fields — `apidocs/pages/dev/modules/spell-queue.md:209-221`
- `purge_by_spell(spell_id, target?)` — `apidocs/pages/dev/modules/spell-queue.md:229-244`
- Best practice: use priority `1`; order rotations by code priority/early return, not queue priority — `apidocs/pages/dev/modules/spell-queue.md:246-284`
- Existing backend already queues first, then IZI, then input fallback — `EaxRotations/core_sylvanas.lua:2351-2437`

**Interrupts**
- Universal Kicks external filters:
  - `ext.register(name, func, opts?)` — `apidocs/pages/dev/api/kick-external-filters.md:55-78`
  - Callback signature `function(local_player, solution_table, spell_to_kick_table, kick_target, prediction_data): boolean, string|nil` — `kick-external-filters.md:66-73`
- Cast telemetry:
  - `unit:is_casting()`, `get_cast_remaining_ms()`, `get_cast_pct()`, channel equivalents, `get_active_cast_or_channel_id()` — `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:1543-1920`
- Existing interrupt manager already implements priority, humanization, cast window, and readiness — `EaxRotations/shared/interrupt_manager_sylvanas.lua:111-152`, `:175-245`, `:256-286`

**Movement / facing**
- `movement_handler:pause_movement(...)`, `pause_movement_light(...)`, `resume_movement(...)` — `apidocs/pages/dev/api/movement-handler.md:38-96`
- `look_at_target(...)`, `look_at_position(...)`, `unlock_look_at(...)` — `movement-handler.md:98-155`
- `movement_handler:on_render()` required — `movement-handler.md:158-169`

**CC / immunity**
- Static NPC susceptibility helper: `cc_data_helper.CC`, `is_susceptible`, `is_stunnable`, `is_silenceable`, etc. — `api/common/utility/cc_data_helper.lua:73-124`
- IZI immunity: `unit:is_cc_immune(type_flags?, min_remaining_ms?, ignore_dot?, dot_blacklist?)` — `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:442-475`
- CC flags — `api/common/enums.lua:315-352`

### Anti-patterns to avoid

- Do not invent a direct “healing engine” or “DPS engine” API. Compose documented modules and current shared modules.
- Do not use raw `core.input.cast_*` from spec files. Keep all casting through `NS.try_cast` / `NS.try_cast_position`.
- Do not use queue priority to encode rotation priority. Keep priority `1`; use rotation ordering and early returns.
- Do not assume a documented direct Universal Kicks “cast interrupt now” API exists. Only filters are documented.
- Do not add a DR tracker unless docs/API expose one. Current evidence supports immunity checks, not full DR tracking.
- Do not treat tooltip parsing APIs as exact spell simulation.

---

## Recommended order of work

1. **Interrupt adoption and correctness** — highest impact/lowest blast radius.
2. **Healing engine adoption pass** — current engine exists; make all healers use it consistently.
3. **TTD/fight-forecast upgrade** — improve DPS cooldown/dot/execute decisions.
4. **Spell queue observability and purge hygiene** — backend exists; add safety/diagnostics, not a rewrite.
5. **Movement/facing assist for cast reliability** — optional, guarded, and only through documented movement handler.
6. **CC/immunity-aware utility layer** — use documented immunity/susceptibility helpers for CC specs.

---

## Phase 1 — Centralize interrupt decisions through `InterruptManager`

### What to implement

Replace spec-local interrupt checks that only test `target_is_casting` or call broad `NS.try_interrupt` with the existing shared manager path.

Do this by copying the existing manager flow from:
- `EaxRotations/shared/interrupt_manager_sylvanas.lua:256-286`
- Registration helper: `EaxRotations/shared/interrupt_manager_sylvanas.lua:289-297`

Targets to inspect first:
- `EaxRotations/core_sylvanas.lua:3265-3295` — broad `NS.try_interrupt` probe currently lacks interruptible flag/priority/window/humanization.
- `EaxRotations/classes/shaman/enhancement_sylvanas.lua:259-267` — currently treats `target_is_casting` as interruptable.
- Grep all specs for `try_interrupt`, `target_is_casting`, `is_casting`, `is_interruptible`.

### Implementation guidance

- Keep the current manager as the source of truth.
- If a spec has a real interrupt spell, register it via `NS.register_interrupt_spell(class_key, spell_name, spell_table, required)`.
- Preserve TBC-era spell constraints.
- Use the manager’s existing cast percent and humanization logic instead of re-implementing delays.
- Keep all menu settings nil-guarded through context/settings helpers.

### Verification checklist

- `luac -p` every modified file.
- Run `lua EaxRotations/tests/run_rotation_tests.lua`.
- Run `lua EaxRotations/tests/run_leveling_tests.lua`.
- Grep check: no spec should newly add raw `core.input` casting for interrupts.
- Grep check: interrupt decisions should no longer be based solely on `target_is_casting` when manager data is available.

### Anti-pattern guards

- Do not call undocumented Universal Kicks internals.
- Do not remove existing interrupt fallbacks until tests prove the manager path covers class behavior.
- Do not add new menu items unless explicitly needed.

---

## Phase 2 — Finish healing engine adoption across all healing specs

### What to implement

Adopt the existing predictive deficit and overheal gate consistently in resto druid, resto shaman, holy priest, discipline priest, and holy paladin. Priest discipline and holy paladin already provide copy-ready patterns.

Copy patterns from:
- `EaxRotations/shared/healer_deficit_sylvanas.lua:219-324` — predictive deficit source.
- `EaxRotations/shared/healer_deficit_sylvanas.lua:334-385` — `gate_spell_overheal` / `heal_would_overheal`.
- `EaxRotations/core_sylvanas.lua:4187-4218` — healing entries with predicted deficit, `effective_hp`, `incoming_dps`, `time_to_die`.
- `EaxRotations/classes/priest/discipline_sylvanas.lua:280-301` — existing direct gate usage.
- `EaxRotations/classes/paladin/holy_sylvanas.lua:589-728` — existing gate usage across heals.

### Implementation guidance

- First inspect current changed healer files:
  - `EaxRotations/classes/druid/resto_sylvanas.lua`
  - `EaxRotations/classes/paladin/holy_sylvanas.lua`
  - `EaxRotations/classes/priest/discipline_sylvanas.lua`
  - `EaxRotations/classes/priest/holy_sylvanas.lua`
  - `EaxRotations/classes/shaman/healing_sylvanas.lua`
  - `EaxRotations/shared/healer_deficit_sylvanas.lua`
- Standardize heal choice around `context.healing_entries` and `effective_hp` where possible.
- Use predictive deficit for expensive/large heals and HoT refresh decisions.
- Keep emergency heals responsive: do not over-gate near-lethal targets.
- Preserve existing class identity: HoT maintenance for druid, shield/penance-style prevention for discipline, chain/group logic for shaman, efficient single-target logic for paladin/priest.

### Verification checklist

- `luac -p` all modified healer files and shared modules.
- Run full rotation and leveling suites.
- Add/update targeted tests if a healer has tests for overheal or predictive healing.
- Grep check: all healing specs should either use `context.healing_entries` or `NS.HealerDeficit` gates for large heals.
- Grep check: no inverted return-value gate pattern that silently skips spells.

### Anti-pattern guards

- Do not remove expensive API guards before calls to incoming-damage/incoming-heal APIs.
- Do not convert every heal into the same generic priority; keep spec-specific behavior.
- Do not trust nil numeric state fields. Use safe defaults.

---

## Phase 3 — Upgrade TTD/fight forecasting for DPS decisions

### What to implement

Improve usage of the existing layered TTD system so DPS rotations can make better decisions about dots, cooldowns, executes, and short-lived targets.

Current sources:
- `EaxRotations/main_sylvanas.lua:450-502` — fallback chain: EMA TTD → regression TTD → engine TTD.
- `EaxRotations/shared/ttd_ema_tracker_sylvanas.lua:124-207` — combat-log EMA DPS/TTD.
- `EaxRotations/shared/ttd_tracker_sylvanas.lua:156-231` — HP%-based linear regression.
- API docs: `combat_forecast:get_forecast_single(...)` and `unit:time_to_die()` from Phase 0.

### Implementation guidance

- Add a small shared accessor if needed, not per-spec duplicated TTD logic.
- Consider allowing regression TTD for normal equal/lower-level targets after enough samples, not only bosses/higher-level targets.
- Preserve current fallback order unless evidence shows native engine TTD is more stable in tests.
- Expose simple booleans/fields to specs via context:
  - `ttd_known`
  - `ttd`
  - optional `fight_remains_bucket` if useful: short/medium/long.
- Start adoption in high-TTD-value specs:
  - Warlock DoT specs and demonology.
  - Shadow priest.
  - Warrior execute specs.
  - Hunter/rogue cooldown or finisher logic if present.

### Verification checklist

- Existing rotation and leveling tests pass.
- Add focused tests around short TTD: skip long DoTs/cooldowns when target will die too soon.
- Add focused tests around execute TTD: do not skip execute due to nil/unknown TTD.
- Grep check: specs use `context.ttd_known` before making TTD-dependent decisions.

### Anti-pattern guards

- Do not treat unknown TTD as `0` for DPS; that causes false “target dying” behavior.
- Do not make rotation decisions solely from native engine TTD without fallback/known flag.
- Do not add WotLK/Cata spell logic while touching DPS specs.

---

## Phase 4 — Spell queue hygiene and observability

### What to implement

Keep `NS.try_cast` as the central backend, but add limited queue hygiene and debugging where it helps prevent stuck casts or repeated stale queued actions.

Current backend:
- `EaxRotations/core_sylvanas.lua:2271-2349` — `NS.evaluate_cast` guards.
- `EaxRotations/core_sylvanas.lua:2351-2437` — queue → IZI → input fallback.
- `EaxRotations/core_sylvanas.lua:2460-2484` — position cast backend.

Documented APIs:
- `spell_queue:get_queue_snapshot()` — `apidocs/pages/dev/modules/spell-queue.md:209-221`
- `spell_queue:purge_by_spell(spell_id, target?)` — `spell-queue.md:229-244`

### Implementation guidance

- Add debug-only visibility into queue snapshot if current debug facilities can display it without hot-path garbage.
- Purge stale spell entries only when there is a clear state transition, e.g. target changed, spell no longer castable, or dead target.
- Keep priority `1` for rotation casts.
- Keep current IZI and input fallback; do not remove them.

### Verification checklist

- `luac -p EaxRotations/core_sylvanas.lua` if modified.
- Full rotation and leveling tests.
- Add/adjust tests for stale target or dead target queue purge if test harness supports it.
- Grep check: no spec imports `spell_queue` directly unless explicitly justified.

### Anti-pattern guards

- Do not rewrite the casting backend unless a concrete failing test demands it.
- Do not spam `get_queue_snapshot()` every frame without a debug gate/throttle.
- Do not encode rotation order with queue priority.

---

## Phase 5 — Movement/facing assist for cast reliability

### What to implement

Add a guarded movement/facing helper only if current cast failures show facing/movement issues. This should be conservative and opt-in through existing settings where possible.

Documented copy points:
- `movement_handler:pause_movement(...)`, `pause_movement_light(...)`, `resume_movement(...)` — `apidocs/pages/dev/api/movement-handler.md:38-96`
- `look_at_target(...)`, `look_at_position(...)`, `unlock_look_at(...)` — `movement-handler.md:98-155`
- Examples — `movement-handler.md:180-202`

### Implementation guidance

- Integrate only near the cast backend or a shared helper, not per spec.
- Never force movement for instant casts or when not needed.
- Respect player control and existing movement state.
- Ensure `movement_handler:on_render()` requirement is satisfied before relying on it.

### Verification checklist

- Syntax check modified files.
- Full tests.
- Manual/runtime validation likely required; test harness may not simulate facing/movement.
- Debug logs should confirm helper is gated and not firing constantly.

### Anti-pattern guards

- Do not use raw `core.input.disable_movement` directly if movement_handler works.
- Do not auto-face in PvP or user-controlled sensitive contexts without a setting.
- Do not add movement manipulation to every failed cast path.

---

## Phase 6 — CC/immunity-aware utility decisions

### What to implement

Use documented immunity and CC susceptibility helpers to prevent wasted CC/utility spells where rotations currently attempt them blindly.

Documented copy points:
- `api/common/utility/cc_data_helper.lua:73-124`
- `unit:is_cc_immune(...)` — `apidocs/pages/dev/libraries/izi/izi-object-extensions.md:442-475`
- `api/common/enums.lua:315-352`

### Implementation guidance

- Start with specs that already use CC or utility spells.
- Add a small shared helper if multiple specs need identical immunity checks.
- Keep checks nil-safe and optional; if helper/module unavailable, fall back to current behavior.

### Verification checklist

- Syntax check modified files.
- Full tests.
- Add tests for “immune target skips CC” if harness supports target method stubs.
- Grep check: no invented DR API names.

### Anti-pattern guards

- Do not implement a full diminishing-return system without documented source data.
- Do not block interrupts with CC immunity checks; interruptibility is separate.
- Do not make PvE NPC susceptibility assumptions for players unless API docs support it.

---

## Final verification phase

Run after each implementation slice and before reporting completion:

1. `luac -p` every modified `.lua` file.
2. `lua EaxRotations/tests/run_rotation_tests.lua`
3. `lua EaxRotations/tests/run_leveling_tests.lua`
4. Grep anti-patterns:
   - raw `core.input.cast_` in spec files
   - unguarded `menu.*:get()`
   - `target_is_casting` used as sole interrupt condition
   - TTD decisions without `ttd_known`
   - direct use of undocumented Universal Kicks internals
5. If 3+ files, backend/API, or infrastructure changed, run independent verification before declaring completion.

## Suggested immediate next task

Start with **Phase 1: Centralize interrupt decisions through `InterruptManager`**.

Why:
- It is a clear correctness gap with evidence.
- The shared manager already exists, so this is adoption/refinement, not architecture invention.
- It reduces wasted/unsafe interrupts and makes interrupt behavior consistent across specs.
- It has lower blast radius than rewriting healing or TTD.

After Phase 1 passes tests, do Phase 2 healing adoption because the project already has a strong predictive healing foundation and the current gap is uneven use across healer specs.

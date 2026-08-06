# EaxRotations Technical Guide
**Version:** 2.2.2 | **Updated:** 2026-06-29 | **Status:** Stable

## What This Is
EaxRotations is a TBC Classic rotation automation framework for Project Sylvanas. It does not blindly press buttons. Every action passes through gates before reaching the API:
- Player exists and is alive
- Target is valid, hostile, and in range
- Spell is known and off cooldown
- GCD is available
- Required resource is available
- Required stance/form is active
- Configured rules allow the action

## Boot Sequence
The runtime order is controlled by explicit `require()` calls in `main.lua`.

### Complete Runtime Load Order (main.lua)

| Step | File | Purpose | Guarded? |
|------|------|---------|----------|
| 1 | `common/izi_sdk` | IZI SDK; aborts if missing | Hard |
| 2 | `header` | Plugin metadata/class info | Hard |
| 3 | `core_sylvanas` | Creates `_G.EaxRotations` namespace | Hard |
| 4 | `helpers_sylvanas` | Shared helper aliases | Hard |
| 5 | 24 shared modules | Services, helpers, Tier 2-4 | Hard |
| 6 | `main_sylvanas` | Dispatcher tick engine | Hard |
| 7 | `classes/<class>/class_sylvanas` | Class bootstrap | `pcall` |
| 8 | `common/color` | Menu color constants | Hard |
| 9 | `key_helper`, `control_panel_helper` | Optional helpers | `pcall` |
| 10 | `classes/<class>/schema_sylvanas` | Widget creation schema | `pcall` |

Post-boot conditional loads:
- `dashboard_sylvanas` / `debug_log_sylvanas`: loaded on-demand by their respective toggle settings (the `show_dashboard` and `show_debug_log` settings are no longer present in `main.lua`; these modules are loaded transitively or via class middleware when needed)
- `movement_assist_sylvanas`: loaded at the end of `main.lua` inside a `do` block, registered as a render callback gated on `rotation_enabled`

Transitive requires (in `main_sylvanas.lua`): `spell_queue`, `combat_forecast`, `buff_db`, `ooc_manager`, `burst_logic`, `combat_forecast_gate_sylvanas`.

## Complete Tick Trace
Entry point: `main.lua:on_update()` (registered via `NS.register_on_update_callback` in the REGISTER CALLBACKS section at the end of `main.lua`).

### Phase A: main.lua:on_update (Prelude)
1. Heartbeat log (top of `on_update`): confirms callback fires, logs runtime generation
2. Runtime-generation guard (top of `on_update`): if mismatch → log and return
3. Raw player lookup (early in `on_update`): `core.object_manager.get_local_player()`; nil check (GUARD-2)
4. Alive check (early in `on_update`): `player:is_alive()` pcall; not alive → GUARD-3 → return
5. Deferred class-module retry (mid `on_update`): if class module failed to load at boot, retries now
6. Sync control panel (mid `on_update`): `control_panel_helper:on_update()`
7. Sync menu settings (mid `on_update`): read widget states via `sync_quick_toggles()` and `sync_playstyle_control()`, detect changes via `schema_widget_last_values`, call `set_setting(key, value)` on changes
8. Check `rotation_enabled` (mid `on_update`): if `false` → log GUARD-4 → return
9. Validate player (lower `on_update`): `GetPlayer()` nil check (GUARD-5), `is_valid()` pcall (GUARD-6)
10. Auto-run API probe (lower `on_update`): one-shot probe on first valid frame
11. Call dispatcher (end of `on_update`): `pcall(framework_main.on_rotation_update)` with error logging

### Phase B: main_sylvanas.lua:on_rotation_update (Dispatcher)
7. **`build_context()`** (called at the top of `on_rotation_update`): Clears `_context`, gets me/target, fires combat transitions, populates 40+ fields, sets `_context.settings = NS.settings` (inside `build_context`, direct reference)
8. Abort if no context (early return in `on_rotation_update`)
9. Log context summary (inside `build_context`, throttled trace)
10. **OOC gate** (early in `on_rotation_update`): if `not (in_combat or has_valid_enemy_target)` → runs `ooc_manager.on_update()` if available; if that fires → returns `true`; otherwise returns `false`
11. **Registry + playstyle selection** (mid `on_rotation_update`): reads `playstyle` setting; defaults to `active_playstyle` or `config.default_playstyle`; **auto-leveling**: if `(is_leveling or is_solo)` and `registry.playstyles.leveling` exists → forced `active = "leveling"`
12. **Middleware** (mid `on_rotation_update`): `run_list("middleware", NS.class_middleware[class_key], nil, context)`. If middleware fires → returns `true` (blocks playstyle for this tick)
13. **Playstyle strategies** (end of `on_rotation_update`): `run_list(tostring(active), registry.playstyles[active], registry.options[active], context)`. First successful `execute` returns `true`, stops iteration
14. No-action logging: no `trace_no_action` exists in the current codebase; strategies that don't match simply fall through and `run_list` returns `false`

### Phase C: run_list() Internals (in `main_sylvanas.lua`)
15. Requires list is table; optionally builds `state` via `get_state`
16. Iterates `for i = 1, #list`; checks `matches` then `execute`; first success wins

### Error Handling
- `safe(fn, ...)` (in `main_sylvanas.lua`): `pcall` wrapper, rate-limited to 1 warning per 2 seconds
- Errors do NOT abort the tick; degrade to "no action"

## Runtime Boundary (NS.*)
Created by `core_sylvanas.lua`. Key functions:
- **Player**: `GetPlayer()`, `GetFocus()`, `GetPartyMembers()`, `GetTarget()`
- **Casting**: `try_cast()`, `spell_ready()`, `spell_action()`, `is_spell_learned()`
- **Buffs**: `buff_up()`, `debuff_up()`, `buff_points()`, `get_aura_data()`
- **Targeting**: `is_hostile_unit()`, `GetEnemiesInRange()`, `same_unit()`
- **Resources**: `mana_pct()`, `rage_pct()`, `energy_pct()`, `hp_pct()`
- **Settings**: `get_setting()`, `set_setting()`, `get_active_playstyle()`
- **Registry**: `rotation_registry:set_class_config()`, `rotation_registry:register()`
- **Time**: `time_now()`, `game_time_ms()`, `get_ping()`

## Annotated Playstyle Example: Warrior Fury
File: `classes/warrior/fury_sylvanas.lua` (~847 lines)

### Strategy Priority List (24 entries)
1. Healthstone 2. Pummel 3. Intercept 4. Hamstring 5. BerserkerStance 6. BattleStance 7. BattleShout 8. BerserkerRage 9. Bloodrage 10. VictoryRush 11. Charge 12. Recklessness 13. DeathWish 14. SweepingStrikes 15. Rampage 16. Bloodthirst 17. Execute 18. Whirlwind 19. Slam 20. SwingDesync 21. SunderArmor 22. DemoralizingShout 23. Cleave 24. HeroicStrike

### State Table (the `build_state` function)
Builds: rage, hp, target_hp, stance, enemy_count, is_pvp, in_combat, is_moving, target_distance, target_is_casting, buffs (BS, CS, BR, SS, Rampage, stacks, VR), debuffs (sunder_stacks, rend_remains, hamstring, demo, tclap), 20+ readiness flags, execute_phase, healthstone/potion IDs, swing timer state.

### Match + Execute Pair (Healthstone)
```lua
-- Match function (healthstone_matches in fury_sylvanas.lua)
local function healthstone_matches(context, state)
 local hs_enabled = setting(context, "use_healthstones", true)
 if not hs_enabled then return false end
 local hs_hp = setting(context, "healthstone_hp", 35)
 if (state.hp or 100) > hs_hp then return false end
 -- Healthstone preferred, then health potion as fallback
 if state.healthstone_ready and state.healthstone_id then
 return true
 end
 if state.health_potion_ready and state.health_potion_id then
 return true
 end
 return false
end

-- Strategy entry (in the STRATEGY_SPECS table)
{ "Healthstone", healthstone_matches,
 build_action("Healthstone", nil, { target = "self", requires_target = false }),
 function(context)
 local s = build_state(context or {})
 if s.healthstone_ready and s.healthstone_id and NS.use_item_by_id then
 return NS.use_item_by_id(s.healthstone_id, context.me or context.target)
 end
 if s.health_potion_ready and s.health_potion_id and NS.use_item_by_id then
 return NS.use_item_by_id(s.health_potion_id, context.me or context.target)
 end
 return false
 end }
```
**Annotation**: Match gates on `use_healthstones` setting and HP threshold, prefers healthstone then health potion. Executor re-builds state and calls `NS.use_item_by_id` directly if available.

**Note**: The `charge_ooc_only` gate in `charge_matches` is functional—it checks `context.target:is_in_combat()` and skips Charge if the target is already in combat.

### Special Mechanics
- **Slam weaving**: Only fires if swing timer exists, stationary, rage >= 15, BT/WW not imminent, and next MH swing is inside safe weave window
- **Rampage**: Casts when buff missing, stacks below threshold, or buff <= 3s remaining
- **Execute phase**: Active at target HP <= 20; fires when rage >= threshold
- **Rage pooling**: BT/WW/Execute gate on minimum rage; Slam blocks if BT/WW coming off cooldown soon
- **Stance safety**: Swaps use Tactical Mastery-style rage preservation

Settings consumed (~14 unique keys): stance_preference, auto_charge, charge_ooc_only, use_healthstones, healthstone_hp, use_cooldowns, rampage_min_stacks, sunder_mode, execute_phase_rage, slam_weave_enabled, heroic_strike_rage, cleave_rage, sweeping_strikes_count.

## All 31 + 9 Leveling Playstyles (TBC)

The inventory below is the legacy TBC playstyle set. Season of Discovery is a separate explicit runtime mode with its own 20-entry manifest; see [SOD_ROTATIONS.md](SOD_ROTATIONS.md) for its modules and provenance.

### 31 Non-Leveling (Registered at Runtime)

| # | Class | Playstyle | Role | Lines | Custom Match |
|---|-------|-----------|------|-------|-------------|
| 1 | Druid | Balance | Ranged DPS | ~434 | test_balance_custom_matches.lua |
| 2 | Druid | Bear | Tank | ~866 | test_bear_custom_matches.lua |
| 3 | Druid | Cat | Melee DPS | ~836 | test_cat_custom_matches.lua |
| 4 | Druid | **Caster** | Caster / Healer | ~142 | test_druid_caster_custom_matches.lua |
| 5 | Druid | Restoration | Healer | ~573 |—|
| 6 | Hunter | Beast Mastery | Ranged DPS | ~782 |—|
| 7 | Hunter | Marksmanship | Ranged DPS | ~416 |—|
| 8 | Hunter | Survival | Ranged DPS/Control | ~495 |—|
| 9 | Mage | Arcane | Ranged DPS | ~556 | test_arcane_custom_matches.lua |
| 10 | Mage | Fire | Ranged DPS | ~337 | test_fire_custom_matches.lua |
| 11 | Mage | Frost | Ranged DPS | ~474 | test_frost_custom_matches.lua |
| 12 | Paladin | Holy | Healer | ~956 | test_paladin_holy_custom_matches.lua* |
| 13 | Paladin | Protection | Tank | ~565 |—|
| 14 | Paladin | Retribution | Melee DPS | ~630 |—|
| 15 | Priest | Discipline | Healer/Shielding | ~728 | test_discipline_custom_matches.lua |
| 16 | Priest | Holy | Healer | ~925 | test_priest_holy_custom_matches.lua |
| 17 | Priest | Shadow | Ranged DPS | ~732 |—|
| 18 | Priest | **Smite** | Ranged DPS | ~479 |—|
| 19 | Rogue | Assassination | Melee DPS | ~605 |—|
| 20 | Rogue | Combat | Melee DPS | ~504 |—|
| 21 | Rogue | Subtlety | Melee DPS | ~525 |—|
| 22 | Shaman | Elemental | Ranged DPS | ~521 |—|
| 23 | Shaman | Enhancement | Melee DPS | ~1136 |—|
| 24 | Shaman | Restoration | Healer | ~638 |—|
| 25 | Warlock | Affliction | Ranged DPS | ~946 |—|
| 26 | Warlock | Demonology | Ranged DPS | ~458 | test_demonology_custom_matches.lua |
| 27 | Warlock | Destruction | Ranged DPS | ~477 |—|
| 28 | Warrior | Arms | Melee DPS | ~811 | test_arms_custom_matches.lua |
| 29 | Warrior | Fury | Melee DPS | ~847 | test_fury_custom_matches.lua |
| 30 | Warrior | **Kebab** | PvP Utility | ~562 | test_kebab_general_use_matches.lua |
| 31 | Warrior | Protection | Tank | ~963 |—|

\* File exists but is NOT in `run_rotation_tests.lua` runner roster.

### 9 Leveling Playstyles
Every class has a `leveling_sylvanas.lua` loading a `"leveling"` playstyle. Auto-selected when player is leveling/solo (in `on_rotation_update`).

| Class | File |
|-------|------|
| Druid | classes/druid/leveling_sylvanas.lua |
| Hunter | classes/hunter/leveling_sylvanas.lua |
| Mage | classes/mage/leveling_sylvanas.lua |
| Paladin | classes/paladin/leveling_sylvanas.lua |
| Priest | classes/priest/leveling_sylvanas.lua |
| Rogue | classes/rogue/leveling_sylvanas.lua |
| Shaman | classes/shaman/leveling_sylvanas.lua |
| Warlock | classes/warlock/leveling_sylvanas.lua |
| Warrior | classes/warrior/leveling_sylvanas.lua |

### Deep Mini-Specs (6 Representative)

#### 1. Warrior Fury (~847 lines)
Priority: Healthstone → Pummel → Intercept → Hamstring → BerserkerStance → BattleShout → Bloodthirst → Execute → Whirlwind → Cleave → HeroicStrike
State: 40+ fields, readiness flags, buffs, debuffs, swing timer, consumables
Settings: ~14 unique keys
Special: Slam weaving, Rampage stacks, execute phase, rage pooling stance safety

#### 2. Priest Discipline (~728 lines)
Priority: Emergency PW:S → Prayer of Mending (tank) → Flash Heal → Greater Heal → Binding Heal → Circle of Healing
State: lowest/tank targets, group counts, buff coverage, ready flags, mana/hp
Settings: discipline_pws_hp, discipline_flash_hp, discipline_greater_heal_hp, discipline_renew_hp, discipline_aoe_hp, discipline_dps_when_idle, discipline_pain_suppression_hp, discipline_use_power_infusion, discipline_use_inner_focus, discipline_healthstone_hp
Mechanics: PW:S absorb tracking, pushback-aware Greater Heal, StopCast/PreHeal/Fade, idle damage fallback
Middleware: classes/priest/healing_sylvanas.lua

#### 3. Priest Shadow (~732 lines)
Priority: PreCombatPull → Shadowform → Silence → ManaBelow5Wand → Shadowfiend → VampiricTouch → ShadowWordPain → MindBlast → MindFlay
State: DoT remains, Mind Blast/SWD readiness, Mind Flay channel/clip, Shadowform, per-target snapshot caches
Settings: shadow_combat_mode, shadow_vt_refresh_window, shadow_swp_refresh_window, shadow_dp_refresh_window, shadow_swd_safety_hp, shadow_shield_hp, shadow_threat_safe
Mechanics: Mind Flay clipping, snapshot-aware DoT refresh, Bloodlust-adjusted thresholds, wand emergency, threat-gated nukes
Middleware: shared/mf_tick_compute_sylvanas.lua

#### 4. Druid Balance (~434 lines)
Priority: BarkskinDefense → ManaPotionEmergency → ForceOfNature → InnervateSelf → RebirthBattleRez → MoonkinForm → PreHurricaneBarkskin → InsectSwarm → Moonfire → Starfire → Wrath
State: DoT remains, Nature's Grace, Barkskin, mana, enemy_count, TTD, smart Innervate target
Settings: balance_innervate_mana, balance_starfire_mana, balance_barkskin_hp, balance_hurricane_targets, balance_use_insect_swarm
Mechanics: Barkskin-before-Hurricane, healer-priority Innervate scan (Paladin 2, Priest 5, Shaman 7, Druid 11), battle rez target selection

#### 5. Paladin Protection (~565 lines)
Priority: RighteousFury → DevotionAura → BlessingOfSanctuary → SealRighteousness → HolyShield → Consecration → AvengerShield
State: Holy Shield charges via NS.buff_points, consecration remains, ally threat/low-HP scans, CC proximity
Settings: Minimal; largely conservative defaults
Mechanics: Holy Shield charge tracking (refreshes when charges <= 2), CC-safe Consecration/Avenger's Shield, Righteous Defense/BoP peels

#### 6. Rogue Combat (~504 lines)
Priority: Stealth → AdrenalineRush → BladeFlurry → SliceAndDice → Rupture → Eviscerate → Kick → SinisterStrike
State: stealth/SnD/BR/AR buffs, Rupture remains, combo points, energy, hp, combat, target casting, heroism state, threat %
Settings: use_cooldowns, combat_adrenaline_rush_heroism, combat_blade_flurry_count, combat_rupture_ttd, combat_vanish_hp, combat_feint_threat
Mechanics: Energy-tick prediction, Heroism-aware AR delay, Blade Flurry AoE gate, SnD uptime, Rupture TTD gate, threat-based Feint/Vanish

#### 7. Druid Bear (~866 lines)
Priority: Survival (SurvivalInstincts, Barkskin, FrenziedRegen) → Swipe (AoE) → Lacerate → Mangle (Bear) → Maul → DemoralizingRoar → FaerieFire (Feral) → Enrage
State: rage, hp, threat, swipe_ready, lacerate_stacks, mangle_ready, maul_ready, demo_remains, survival cooldowns
Settings: bear_survival_hp, bear_aoe_count, bear_lacerate_refresh, bear_survival_priority
Mechanics: Mangle cooldown tracking, Lacerate stack maintenance, Swipe AoE when 2+ enemies, survival CD HP thresholds

#### 8. Druid Cat (~836 lines)
Priority: PoolForRip → PoolForBuilderTick → PoolForExecuteBite → Powershift → RipSnapshot → RakeSnapshot → Mangle (Cat) → Shred → FerociousBite
State: energy, combo_points, rip_remains, rake_remains, mangle_remains, shred_ready, powershift_energy, pvp_mode, tick_phase, next_tick_time
Settings: cat_rip_ttd, cat_rake_refresh, cat_powershift_enabled, cat_shred_only_behind, cat_pvp_opener
Mechanics: Powershift energy reset, Rip/Rake snapshotting (attack power tracking), positional Shred requirement, energy tick prediction

### Remaining Playstyles (Source-First Reference)

The remaining 23 playstyles follow the same architectural pattern shown above:
- **Strategy table**: Ordered `{ name, matches, execute }` entries (or dynamic ACTIONS iteration as in Bear/Cat)
- **State builder**: Computes buff/debuff/cooldown readiness, HP/resource thresholds
- **Settings**: Consumed from `context.settings` via `setting(context, key, default)`
- **Registration**: `NS.rotation_registry:register("playstyle", strategies, { get_state = build_state })`

For the exact priority order of each spec, read the strategy lists in the source files:

| Playstyle | File | Approx Lines |
|-----------|------|-------------|
| Hunter Beast Mastery | classes/hunter/beast_mastery_sylvanas.lua | ~782 |
| Hunter Marksmanship | classes/hunter/marksmanship_sylvanas.lua | ~416 |
| Hunter Survival | classes/hunter/survival_sylvanas.lua | ~495 |
| Mage Arcane | classes/mage/arcane_sylvanas.lua | ~556 |
| Mage Fire | classes/mage/fire_sylvanas.lua | ~337 |
| Mage Frost | classes/mage/frost_sylvanas.lua | ~474 |
| Paladin Holy | classes/paladin/holy_sylvanas.lua | ~956 |
| Paladin Retribution | classes/paladin/retribution_sylvanas.lua | ~630 |
| Priest Holy | classes/priest/holy_sylvanas.lua | ~925 |
| Priest Shadow | classes/priest/shadow_sylvanas.lua | ~732 |
| Priest Smite | classes/priest/smite_sylvanas.lua | ~479 |
| Rogue Assassination | classes/rogue/assassination_sylvanas.lua | ~605 |
| Rogue Subtlety | classes/rogue/subtlety_sylvanas.lua | ~525 |
| Shaman Elemental | classes/shaman/elemental_sylvanas.lua | ~521 |
| Shaman Enhancement | classes/shaman/enhancement_sylvanas.lua | ~1136 |
| Shaman Restoration | classes/shaman/restoration_sylvanas.lua | ~638 |
| Warlock Affliction | classes/warlock/affliction_sylvanas.lua | ~946 |
| Warlock Demonology | classes/warlock/demonology_sylvanas.lua | ~458 |
| Warlock Destruction | classes/warlock/destruction_sylvanas.lua | ~477 |
| Warrior Arms | classes/warrior/arms_sylvanas.lua | ~811 |
| Warrior Kebab | classes/warrior/kebab_sylvanas.lua | ~562 |
| Warrior Protection | classes/warrior/protection_sylvanas.lua | ~963 |
| Druid Caster | classes/druid/caster_sylvanas.lua | ~142 |
| Druid Restoration | classes/druid/resto_sylvanas.lua | ~573 |

## Season of Discovery Runtime

SoD mode is selected before class rotation resolution. The loader uses only the class's `_sod.lua` manifest entries and exposes normalized `sod_phase` and rune state to those modules. Missing or malformed phase/rune data disables dependent actions rather than enabling a guessed fallback. The SoD source/action contract is pinned to `wowsims/sod` commit `0e3f6eff5fa3ad356664a1c2abbd02903d4cc97e`, with client data validated against `wowheadScrape/dbc_extract/wowsims.db`; the complete source paths and audit commands are in [SOD_ROTATIONS.md](SOD_ROTATIONS.md).

## Settings & Menu Lifecycle
1. **Schema definition** (`classes/<class>/schema_sylvanas.lua`): raw data tables with `{ key, type, default, label, tooltip }`
2. **Shared factories** (`common_sylvanas.lua`): local-only helper functions; schemas may be raw tables or use these factories
3. **Widget creation** (in the `initialize_schema_menu` function in `main.lua`): `initialize_schema_menu()` → `create_schema_widget(def)` → `core.menu.checkbox/slider_int/combobox`
4. **Per-tick sync** (in the `on_update` function in `main.lua`): `widget.sync()` → compare to `schema_widget_last_values` → `set_setting(key, value)` if changed
5. **Storage** (`core_sylvanas.lua`): `NS.set_setting()` writes `NS.settings[key]`; `NS.get_setting()` reads from cache
6. **Context injection** (in the `build_context` function in `main_sylvanas.lua`): `_context.settings = NS.settings` (direct reference)
7. **Spec consumption**: `context.settings[key]` or `NS.get_setting(key, fallback)`
8. **User change** → next tick: sync detects change → `set_setting()` → NS.settings → build_context() → spec sees new value

## How to Modify a Rotation
### 1. Add setting to schema
```lua
{ type = "checkbox", key = "use_custom_spell", default = true, label = "Use Custom Spell" }
```
### 2. Add strategy in spec file
```lua
local ACTION = { CustomSpell = SPELLS.CustomSpell }
local function custom_matches(context)
 if not context.settings or context.settings.use_custom_spell == false then return false end
 return ready(ACTION.CustomSpell, context.target)
end
local strategies = {
 { name = "CustomSpell", matches = custom_matches,
 execute = function(ctx) return NS.try_cast(ACTION.CustomSpell, ctx.target) end },
 ...
}
NS.rotation_registry:register("spec", strategies, { get_state = build_state })
```
### 3. Validate
```powershell
luac -p EaxRotations/classes/<class>/<spec>_sylvanas.lua
lua EaxRotations/tests/run_rotation_tests.lua
```
### Rules
- Priority order matters (emergency at top)
- Always nil-guard `context.settings`
- Use `NS.try_cast()` for cast safety
- Keep `matches()` fast; no expensive scans
- Register new playstyle in `class_sylvanas.lua` via `load_spec` (and `load_child` for middleware)

## API Dependencies
- **Raw Sylvanas API** (`api/core.lua`, `api/game_object.lua`): Callbacks, time, input, unit methods
- **Helper Modules** (`api/common/modules/`): spell_queue, target_selector, buff_manager, spell_prediction, combat_forecast, health_prediction
- **IZI SDK** (`api/common/izi_sdk.lua`): High-level facade (`izi.me()`, `izi.spell()`, `izi.on_combat_start()`)
- **Data Tables**: buff_db (578 entries), enums (394 constants)

## Testing & Validation Pipeline
- **Rotation tests**: 190 entries in `run_rotation_tests.lua` (all unique files, no duplicates)
- **Leveling tests**: 11 entries in `run_leveling_tests.lua`
- **Audit tests**: `run_sylvanas_audit_tests.lua` and `run_vanilla_audit_tests.lua` for TBC ID and static behavior checks
- **Execution**: Plain Lua; each file executed via the test runner library; missing file = FAIL
- **Validation**: `luac -p` syntax gate; test gate (exit 1 if any failure); audit tools for TBC IDs and static behavior

## Critical Coding Patterns
- **Menu guards**: `(menu.x and menu.x:get()) or default`
- **API caching**: Cache hot API refs at module load
- **Squared distance**: `dx*dx + dy*dy` vs `math.sqrt`
- **Static table reuse**: Pre-allocated tables with `.n` count vs per-frame `{}`
- **Aura points**: `NS.buff_points(unit, ids)[1]` for Holy Shield charges
- **PW:S absorb**: `Healing.pws_absorb_remaining(unit)` to avoid overwriting healthy shields

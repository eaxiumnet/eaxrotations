# EaxRotations Technical Guide
**Version:** 1.0.15 | **Updated:** 2026-05-21 | **Status:** Stable

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
`load_order_sylvanas.lua` is **documentation-only**. The actual runtime order is controlled by explicit `require()` calls in `main.lua`.

### Complete Runtime Load Order (main.lua)

| Step | File | Line | Purpose | Guarded? |
|------|------|------|---------|----------|
| 1 | `common/izi_sdk` | 18 | IZI SDK; aborts if missing | Hard |
| 2 | `header` | 26 | Plugin metadata/class info | Hard |
| 3 | `core_sylvanas` | 43 | Creates `_G.EaxRotations` namespace | Hard |
| 4-5 | `helpers_sylvanas`, `explain_helpers_sylvanas` | 54-57 | Shared helper aliases | Hard |
| 6 | `optimizer` | 59 | DecisionCache memoization | Hard |
| 7-30 | 24 shared modules | 61-95 | Services, helpers, Tier 2-4 | Hard |
| 31 | `main_sylvanas` | 97 | Dispatcher tick engine | Hard |
| 32 | `classes/<class>/class_sylvanas` | 112-116 | Class bootstrap | `pcall` |
| 33 | `common/color` | 121 | Menu color constants | Hard |
| 34-35 | `key_helper`, `control_panel_helper` | 122-125 | Optional helpers | `pcall` |
| 36 | `classes/<class>/schema_sylvanas` | 176-183 | Widget creation schema | `pcall` |

Post-boot conditional loads:
- `dashboard_sylvanas` (line 718): when `show_dashboard` toggle ON
- `debug_log_sylvanas` (line 729): when `show_debug_log` toggle ON

Transitive requires (in `main_sylvanas.lua`): `spell_queue`, `combat_forecast`, `buff_db`, `ooc_manager`, `burst_logic`, `combat_forecast_gate_sylvanas`.

## Complete Tick Trace
Entry point: `main.lua:on_update()` (registered at line 844).

### Phase A: main.lua:on_update (Prelude, lines 662-838)
1. Heartbeat log (lines 662-667): confirms callback fires, logs runtime generation
2. Runtime-generation guard (lines 668-675): if mismatch → log and return
3. Raw player lookup (lines 676-683): `core.object_manager.get_local_player()`; nil check (GUARD-2)
4. Alive check (lines 684-691): `player:is_alive()` pcall; not alive → GUARD-3 → return
5. Sync control panel (lines 693-701)
6. Sync menu settings (lines 705-767): read widget states, detect changes via `schema_widget_last_values`, call `set_setting(key, value)` on changes
7. Check `rotation_enabled` (line 771): if `false` → log GUARD-4 → return
8. Validate player (lines 787-803): `GetPlayer()` nil check (GUARD-5), `is_valid()` pcall (GUARD-6)
9. Auto-run API probe (lines 811-816): one-shot probe on first valid frame
10. Call dispatcher (lines 823-837): `pcall(framework_main.on_rotation_update)` with error logging

### Phase B: main_sylvanas.lua:on_rotation_update (Dispatcher, lines 477-530)
7. **`build_context()`** (line 478, lines 155-304): Clears `_context`, gets me/target, fires combat transitions, populates 40+ fields, sets `_context.settings = NS.settings` (line 267, direct reference)
8. Abort if no context (lines 479-483)
9. Log context summary (line 484)
10. **OOC gate** (lines 485-497): if `not (in_combat or has_valid_enemy_target)` → runs `ooc_manager.on_update()` if available; if that fires → returns `true`; otherwise `trace_no_action()` → returns `false`
11. **Registry + playstyle selection** (lines 498-514): reads `playstyle` setting; defaults to `active_playstyle` or `config.default_playstyle`; **auto-leveling** (lines 506-508): if `(is_leveling or is_solo)` and `registry.playstyles.leveling` exists → forced `active = "leveling"`
12. **Middleware** (lines 515-519): `run_list("middleware", NS.class_middleware[class_key], nil, context)`. If middleware fires → returns `true` (blocks playstyle for this tick)
13. **Playstyle strategies** (lines 521-530): `run_list(tostring(active), registry.playstyles[active], registry.options[active], context)`. First successful `execute` returns `true`, stops iteration
14. No-action logging (lines 524-528): `trace_no_action(active, context, "strategies_blocked")`

### Phase C: run_list() Internals (lines 429-475)
15. Requires list is table; optionally builds `state` via `get_state`
16. Iterates `for i = 1, #list`; checks `matches` then `execute`; first success wins

### Error Handling
- `safe(fn, ...)` (lines 55-65): `pcall` wrapper, rate-limited to 1 warning per 2 seconds
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
File: `classes/warrior/fury_sylvanas.lua` (~673 lines)

### Strategy Priority List (26 entries)
1. Healthstone  2. Pummel  3. Intercept  4. Hamstring  5. BerserkerStance  6. BattleStance  7. BattleShout  8. BerserkerRage  9. Bloodrage  10. VictoryRush  11. Charge  12. Recklessness  13. DeathWish  14. Rampage  15. SweepingStrikes  16. Overpower  17. Bloodthirst  18. Execute  19. Rend  20. Whirlwind  21. SunderArmor  22. DemoralizingShout  23. ThunderClap  24. Slam  25. Cleave  26. HeroicStrike

### State Table (lines 240-332)
Builds: rage, hp, target_hp, stance, enemy_count, is_pvp, in_combat, is_moving, target_distance, target_is_casting, buffs (BS, CS, BR, SS, Rampage, stacks, VR), debuffs (sunder_stacks, rend_remains, hamstring, demo, tclap), 20+ readiness flags, execute_phase, healthstone/potion IDs, swing timer state.

### Match + Execute Pair (Healthstone)
```lua
-- Match function (fury_sylvanas.lua:387)
local function healthstone_matches(context, state)
    local hs_enabled = setting(context, "use_healthstones", true)
    if not hs_enabled then return false end
    local hs_hp = setting(context, "healthstone_hp", 35)
    if state.hp > hs_hp then return false end
    -- Healthstone preferred, then health potion as fallback
    if state.healthstone_ready and state.healthstone_id then
        return NS.action_matches(context, { name = "Healthstone", target = "self", requires_target = false })
    end
    if state.health_potion_ready and state.health_potion_id then
        return NS.action_matches(context, { name = "HealthPotion", target = "self", requires_target = false })
    end
    return false
end

-- Strategy entry (fury_sylvanas.lua:599)
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

**Bug**: `charge_matches` references undefined `target` at line 356; the `charge_ooc_only` gate is non-functional (should be `context.target`).

### Special Mechanics
- **Slam weaving**: Only fires if swing timer exists, stationary, rage >= 15, BT/WW not imminent, and next MH swing is inside safe weave window
- **Rampage**: Casts when buff missing, stacks below threshold, or buff <= 3s remaining
- **Execute phase**: Active at target HP <= 20; fires when rage >= threshold
- **Rage pooling**: BT/WW/Execute gate on minimum rage; Slam blocks if BT/WW coming off cooldown soon
- **Stance safety**: Swaps use Tactical Mastery-style rage preservation

Settings consumed (~14 unique keys): stance_preference, auto_charge, charge_ooc_only, use_healthstones, healthstone_hp, use_cooldowns, rampage_min_stacks, sunder_mode, execute_phase_rage, slam_weave_enabled, heroic_strike_rage, cleave_rage, sweeping_strikes_count.

## All 31 + 9 Leveling Playstyles

### 31 Non-Leveling (Registered at Runtime)

| # | Class | Playstyle | Role | Lines | Custom Match |
|---|-------|-----------|------|-------|-------------|
| 1 | Druid | Balance | Ranged DPS | ~536 | test_balance_custom_matches.lua |
| 2 | Druid | Bear | Tank | ~736 | test_bear_custom_matches.lua |
| 3 | Druid | Cat | Melee DPS | ~679 | test_cat_custom_matches.lua |
| 4 | Druid | **Caster** | Caster / Healer | ~300 | test_druid_caster_custom_matches.lua |
| 5 | Druid | Restoration | Healer | ~369 | — |
| 6 | Hunter | Beast Mastery | Ranged DPS | ~480 | — |
| 7 | Hunter | Marksmanship | Ranged DPS | ~465 | — |
| 8 | Hunter | Survival | Ranged DPS/Control | ~460 | — |
| 9 | Mage | Arcane | Ranged DPS | ~510 | test_arcane_custom_matches.lua |
| 10 | Mage | Fire | Ranged DPS | ~520 | test_fire_custom_matches.lua |
| 11 | Mage | Frost | Ranged DPS | ~515 | test_frost_custom_matches.lua |
| 12 | Paladin | Holy | Healer | ~679 | test_paladin_holy_custom_matches.lua* |
| 13 | Paladin | Protection | Tank | ~342 | — |
| 14 | Paladin | Retribution | Melee DPS | ~402 | — |
| 15 | Priest | Discipline | Healer/Shielding | ~544 | test_discipline_custom_matches.lua |
| 16 | Priest | Holy | Healer | ~550 | test_priest_holy_custom_matches.lua |
| 17 | Priest | Shadow | Ranged DPS | ~547 | — |
| 18 | Priest | **Smite** | Ranged DPS | ~380 | — |
| 19 | Rogue | Assassination | Melee DPS | ~421 | — |
| 20 | Rogue | Combat | Melee DPS | ~385 | — |
| 21 | Rogue | Subtlety | Melee DPS | ~359 | — |
| 22 | Shaman | Elemental | Ranged DPS | ~420 | — |
| 23 | Shaman | Enhancement | Melee DPS | ~480 | — |
| 24 | Shaman | Restoration | Healer | ~390 | — |
| 25 | Warlock | Affliction | Ranged DPS | ~472 | — |
| 26 | Warlock | Demonology | Ranged DPS | ~460 | test_demonology_custom_matches.lua |
| 27 | Warlock | Destruction | Ranged DPS | ~455 | — |
| 28 | Warrior | Arms | Melee DPS | ~476 | test_arms_custom_matches.lua |
| 29 | Warrior | Fury | Melee DPS | ~673 | test_fury_custom_matches.lua |
| 30 | Warrior | **Kebab** | PvP Utility | ~300 | test_kebab_general_use_matches.lua |
| 31 | Warrior | Protection | Tank | ~420 | — |

\* File exists but is NOT in `run_rotation_tests.lua` runner roster.

### 9 Leveling Playstyles
Every class has a `leveling_sylvanas.lua` loading a `"leveling"` playstyle. Auto-selected when player is leveling/solo (main_sylvanas.lua:506-508).

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

#### 1. Warrior Fury (~673 lines)
Priority: Healthstone → Pummel → Intercept → Hamstring → BerserkerStance → BattleShout → Bloodthirst → Execute → Whirlwind → Cleave → HeroicStrike
State: 40+ fields, readiness flags, buffs, debuffs, swing timer, consumables
Settings: ~14 unique keys
Special: Slam weaving, Rampage stacks, execute phase, rage pooling stance safety

#### 2. Priest Discipline (~544 lines)
Priority: Emergency PW:S → Prayer of Mending (tank) → Flash Heal → Greater Heal → Binding Heal → Circle of Healing
State: lowest/tank targets, group counts, buff coverage, ready flags, mana/hp
Settings: discipline_pws_hp, discipline_flash_hp, discipline_greater_heal_hp, discipline_renew_hp, discipline_aoe_hp, discipline_dps_when_idle, discipline_pain_suppression_hp, discipline_use_power_infusion, discipline_use_inner_focus, discipline_healthstone_hp
Mechanics: PW:S absorb tracking, pushback-aware Greater Heal, StopCast/PreHeal/Fade, idle damage fallback
Middleware: classes/priest/healing_sylvanas.lua

#### 3. Priest Shadow (~547 lines)
Priority: PreCombatPull → Shadowform → Silence → ManaBelow5Wand → Shadowfiend → VampiricTouch → ShadowWordPain → MindBlast → MindFlay
State: DoT remains, Mind Blast/SWD readiness, Mind Flay channel/clip, Shadowform, per-target snapshot caches
Settings: shadow_combat_mode, shadow_vt_refresh_window, shadow_swp_refresh_window, shadow_dp_refresh_window, shadow_swd_safety_hp, shadow_shield_hp, shadow_threat_safe
Mechanics: Mind Flay clipping, snapshot-aware DoT refresh, Bloodlust-adjusted thresholds, wand emergency, threat-gated nukes
Middleware: shared/mf_tick_compute_sylvanas.lua

#### 4. Druid Balance (~536 lines)
Priority: BarkskinDefense → ManaPotionEmergency → ForceOfNature → InnervateSelf → RebirthBattleRez → MoonkinForm → PreHurricaneBarkskin → InsectSwarm → Moonfire → Starfire → Wrath
State: DoT remains, Nature's Grace, Barkskin, mana, enemy_count, TTD, smart Innervate target
Settings: balance_innervate_mana, balance_starfire_mana, balance_barkskin_hp, balance_hurricane_targets, balance_use_insect_swarm
Mechanics: Barkskin-before-Hurricane, healer-priority Innervate scan (Paladin 2, Priest 5, Shaman 7, Druid 11), battle rez target selection

#### 5. Paladin Protection (~342 lines)
Priority: RighteousFury → DevotionAura → BlessingOfSanctuary → SealRighteousness → HolyShield → Consecration → AvengerShield
State: Holy Shield charges via NS.buff_points, consecration remains, ally threat/low-HP scans, CC proximity
Settings: Minimal; largely conservative defaults
Mechanics: Holy Shield charge tracking (refreshes when charges <= 2), CC-safe Consecration/Avenger's Shield, Righteous Defense/BoP peels

#### 6. Rogue Combat (~385 lines)
Priority: Stealth → AdrenalineRush → BladeFlurry → SliceAndDice → Rupture → Eviscerate → Kick → SinisterStrike
State: stealth/SnD/BR/AR buffs, Rupture remains, combo points, energy, hp, combat, target casting, heroism state, threat %
Settings: use_cooldowns, combat_adrenaline_rush_heroism, combat_blade_flurry_count, combat_rupture_ttd, combat_vanish_hp, combat_feint_threat
Mechanics: Energy-tick prediction, Heroism-aware AR delay, Blade Flurry AoE gate, SnD uptime, Rupture TTD gate, threat-based Feint/Vanish

#### 7. Druid Bear (~736 lines)
Priority: Survival (SurvivalInstincts, Barkskin, FrenziedRegen) → Swipe (AoE) → Lacerate → Mangle (Bear) → Maul → DemoralizingRoar → FaerieFire (Feral) → Enrage
State: rage, hp, threat, swipe_ready, lacerate_stacks, mangle_ready, maul_ready, demo_remains, survival cooldowns
Settings: bear_survival_hp, bear_aoe_count, bear_lacerate_refresh, bear_survival_priority
Mechanics: Mangle cooldown tracking, Lacerate stack maintenance, Swipe AoE when 2+ enemies, survival CD HP thresholds

#### 8. Druid Cat (~679 lines)
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
| Hunter Beast Mastery | classes/hunter/beast_mastery_sylvanas.lua | ~480 |
| Hunter Marksmanship | classes/hunter/marksmanship_sylvanas.lua | ~465 |
| Hunter Survival | classes/hunter/survival_sylvanas.lua | ~460 |
| Mage Arcane | classes/mage/arcane_sylvanas.lua | ~510 |
| Mage Fire | classes/mage/fire_sylvanas.lua | ~520 |
| Mage Frost | classes/mage/frost_sylvanas.lua | ~515 |
| Paladin Holy | classes/paladin/holy_sylvanas.lua | ~679 |
| Paladin Retribution | classes/paladin/retribution_sylvanas.lua | ~402 |
| Priest Holy | classes/priest/holy_sylvanas.lua | ~550 |
| Priest Shadow | classes/priest/shadow_sylvanas.lua | ~547 |
| Priest Smite | classes/priest/smite_sylvanas.lua | ~380 |
| Rogue Assassination | classes/rogue/assassination_sylvanas.lua | ~421 |
| Rogue Subtlety | classes/rogue/subtlety_sylvanas.lua | ~359 |
| Shaman Elemental | classes/shaman/elemental_sylvanas.lua | ~420 |
| Shaman Enhancement | classes/shaman/enhancement_sylvanas.lua | ~480 |
| Shaman Restoration | classes/shaman/restoration_sylvanas.lua | ~390 |
| Warlock Affliction | classes/warlock/affliction_sylvanas.lua | ~472 |
| Warlock Demonology | classes/warlock/demonology_sylvanas.lua | ~460 |
| Warlock Destruction | classes/warlock/destruction_sylvanas.lua | ~455 |
| Warrior Arms | classes/warrior/arms_sylvanas.lua | ~476 |
| Warrior Kebab | classes/warrior/kebab_sylvanas.lua | ~300 |
| Warrior Protection | classes/warrior/protection_sylvanas.lua | ~420 |
| Druid Caster | classes/druid/caster_sylvanas.lua | ~300 |
| Druid Restoration | classes/druid/resto_sylvanas.lua | ~369 |

## Settings & Menu Lifecycle
1. **Schema definition** (`classes/<class>/schema_sylvanas.lua`): raw data tables with `{ key, type, default, label, tooltip }`
2. **Shared factories** (`common_sylvanas.lua`): local-only helper functions; schemas may be raw tables or use these factories
3. **Widget creation** (`main.lua:176-220`): `initialize_schema_menu()` → `create_schema_widget(def)` → `core.menu.checkbox/slider_int/combobox`
4. **Per-tick sync** (`main.lua:738-767`): `widget.sync()` → compare to `schema_widget_last_values` → `set_setting(key, value)` if changed
5. **Storage** (`core_sylvanas.lua`): `NS.set_setting()` writes `NS.settings[key]`; `NS.get_setting()` reads from cache
6. **Context injection** (`main_sylvanas.lua:267`): `_context.settings = NS.settings` (direct reference)
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
- Register new playstyle in `class_sylvanas.lua` via `load_child`

## API Dependencies
- **Raw Sylvanas API** (`api/core.lua`, `api/game_object.lua`): Callbacks, time, input, unit methods
- **Helper Modules** (`api/common/modules/`): spell_queue, target_selector, buff_manager, spell_prediction, combat_forecast, health_prediction
- **IZI SDK** (`api/common/izi_sdk.lua`): High-level facade (`izi.me()`, `izi.spell()`, `izi.on_combat_start()`)
- **Data Tables**: buff_db (578 entries), enums (394 constants)

## Testing & Validation Pipeline
- **Rotation tests**: 100 entries in `run_rotation_tests.lua` (99 unique files; `test_execute_phase.lua` duplicated at lines 47 and 76)
- **Leveling tests**: 11 entries in `run_leveling_tests.lua`
- **Execution**: Plain Lua; each file executed via `io.popen("lua <file>")`; missing file = FAIL
- **Validation**: `luac -p` syntax gate; test gate (exit 1 if any failure); audit tools for TBC IDs and static behavior

## Critical Coding Patterns
- **Menu guards**: `(menu.x and menu.x:get()) or default`
- **API caching**: Cache hot API refs at module load
- **Squared distance**: `dx*dx + dy*dy` vs `math.sqrt`
- **Static table reuse**: Pre-allocated tables with `.n` count vs per-frame `{}`
- **Aura points**: `NS.buff_points(unit, ids)[1]` for Holy Shield charges
- **PW:S absorb**: `Healing.pws_absorb_remaining(unit)` to avoid overwriting healthy shields

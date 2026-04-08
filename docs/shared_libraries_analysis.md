# EAX TBC Classic - Shared Libraries Analysis

**Wave 1, Task 1 of 3** - Comprehensive catalog of all 22 shared libraries in the root `libraries/` folder.

**Date:** 2026-04-08  
**Analyzed By:** Sisyphus-Junior  
**Reference:** Flux TBC Classic Rotation Framework

---

## Executive Summary

This document catalogs all 22 shared libraries in the EAX TBC Classic rotation plugin suite. Each library provides cross-cutting functionality used by multiple class specializations. The libraries follow consistent patterns: API caching at module load, nil-guarded menu access, IZI SDK integration where applicable, and middleware pattern support for extensible rotation logic.

---

## Library Catalog (Alphabetical)

### 1. `anti_fake_manager.lua`

**Primary Purpose:** PvP anti-fake interrupt logic - detects and responds to fake casting (casters canceling spells to bait interrupts).

**Key Exported Functions:**
- `is_likely_fake(target)` - Returns true if target has faked twice recently
- `get_interrupt_delay(target, is_pvp)` - Returns random 100-400ms delay for PvP interrupts
- `record_cast_start(target)` - Records when a target starts casting
- `record_cast_end(target, was_interrupted)` - Records cast outcome to track fake patterns

**Used By Specs:**
- All specs with interrupt capabilities (via defensive/interrupt managers)
- EAXWarriorFury, EAXWarriorArms, EAXRogueAssassination, EAXRogueCombat, EAXRogueSubtlety
- EAXShamanElemental, EAXShamanEnhancement

**IZI SDK Integration:** None (uses core APIs only)

**Middleware Pattern:** No

---

### 2. `burst_manager.lua`

**Primary Purpose:** Auto-burst system that detects optimal cooldown usage windows (Bloodlust, pull, execute phase).

**Key Exported Functions:**
- `has_bloodlust(me)` - Checks for Bloodlust/Heroism buffs
- `should_auto_burst(me, target, combat_time, menu)` - Returns true if burst conditions met
- `should_defensive_burst(me, menu)` - Returns true if defensive burst needed

**Used By Specs:**
- EAXPaladinRetribution
- EAXDruidFeral
- EAXDruidBear
- EAXWarriorFury
- EAXWarriorArms
- EAXShamanEnhancement
- EAXShamanElemental
- All DPS specs with offensive cooldowns

**IZI SDK Integration:** None

**Middleware Pattern:** No

---

### 3. `cc_detector.lua`

**Primary Purpose:** Crowd Control detection module - identifies all CC debuffs on units for rotation safety checks.

**Key Exported Functions:**
- `is_ccd(unit)` - Returns true + CC type if unit is crowd controlled
- `should_stop_rotation(unit)` - Returns true if rotation should halt due to CC
- `is_stunned(unit)`, `is_silenced(unit)`, `is_feared(unit)` - Specific CC checks
- `get_cc_duration(unit)` - Returns remaining CC duration
- `has_cc_type(unit, cc_type)` - Check for specific CC category
- `is_disarmed(unit)`, `is_rooted(unit)`, `is_polymorphed(unit)` - Convenience checks

**TBC CC Database Coverage:**
- Polymorph, Fear, Psychic Scream, Howl of Terror, Death Coil (Horror)
- Sap, Gouge, Blind, Cyclone, Entangling Roots
- All stun effects (Cheap Shot, Kidney Shot, Hammer of Justice, etc.)
- Silence effects, Disarm, Charm, Sleep, Banish, Hex
- Freezing Trap, Scatter Shot, Shackle Undead

**Used By Specs:**
- EAXPaladinRetribution (main.lua line 423)
- All specs via defensive managers

**IZI SDK Integration:** Uses `common/modules/buff_manager`

**Middleware Pattern:** No

---

### 4. `combat_forecast.lua`

**Primary Purpose:** Time-To-Death (TTD) prediction for cooldown gating - prevents wasting CDs on dying targets.

**Key Exported Functions:**
- `sample(target)` - Records HP sample (call every ~1 second)
- `get_ttd(target)` - Returns predicted seconds until death
- `worth_using_cds(target, min_ttd)` - Returns true if target will live long enough
- `is_dying(target, threshold_s)` - Quick check if target dying soon
- `is_valid_forecast_logic(min_ttd, target, allow_nil)` - Legacy compatibility
- `reset(target)` - Clear samples for a target

**Configuration:**
- MAX_SAMPLES = 10 (rolling window)
- SAMPLE_INTERVAL = 1.0 second
- DEFAULT_TTD = 500 seconds (for stable/healing targets)
- MIN_SAMPLES_FOR_TTD = 2

**Used By Specs:**
- EAXPaladinRetribution
- EAXDruidResto
- EAXDruidFeral
- EAXDruidBear
- EAXDruidBalance
- EAXPaladinProtection
- EAXPaladinHoly
- EAXMageFrost
- All specs via trinket_manager, burst_manager

**IZI SDK Integration:** None

**Middleware Pattern:** No

---

### 5. `compat.lua`

**Primary Purpose:** Legacy to Sylvanas compatibility layer - provides API wrappers for incremental migration.

**Key Exported Functions:**
- `get_menu_value(menu, key, default)` - Safe menu access with nil guards
- `build_context(me, menu, utils)` - Creates rotation context with combat state
- `register_middleware(mw)` - Middleware registration with priority
- `execute_middleware(icon, context)` - Execute registered middleware
- `set_force_flag(flag_name, duration)` / `is_force_active(flag_name)` - Force command system
- `refresh_settings(menu, schema)` - 50ms throttled settings cache
- `cast_safe(spell_id, target)` - Safe spell cast wrapper
- `has_talent(talent_id, min_points)` - Talent point checker
- `cooldown_remains(spell_id)` / `is_spell_ready(spell_id)` - Cooldown utilities

**Used By Specs:**
- EAXMageFrost (middleware_manager.lua)
- Legacy spec support

**IZI SDK Integration:** None (provides compatibility layer)

**Middleware Pattern:** Yes - full middleware registry implementation

---

### 6. `context_builder.lua`

**Primary Purpose:** Shared rotation context builder for tanking specs - builds context once per frame to reduce API calls.

**Key Exported Functions:**
- `build(me, target, menu)` - Builds comprehensive context table
- `clear_cache()` - Clear cached context
- `_is_melee_range(me, target)` - Squared distance check
- `_dist_squared(a, b)` - Calculate squared distance
- `get_debuff_data(target, debuff_ids)` - Buff manager wrapper
- `get_buff_data(unit, buff_ids)` - Buff manager wrapper
- `count_enemies_in_radius(me, radius)` - Enemy counting
- `count_enemies_by_class(me, radius)` - Classified enemy counts (boss/elite/trash)

**Context Table Structure:**
```lua
{
  me = player_object,
  hp = health_percentage,
  rage/mana = resource_value,
  stance/form = current_form,
  target = target_object,
  has_target = boolean,
  target_hp = target_health,
  in_melee_range = boolean,
  threat_pct = threat_percentage,
  threat_status = 0-3 (loose to secure),
  enemy_count = number,
  melee_enemies = number,
  party_size = number,
  settings = {} -- cached menu values
}
```

**Used By Specs:**
- EAXWarriorProtection
- EAXPaladinProtection
- EAXDruidBear
- All tanking specs

**IZI SDK Integration:** Uses `common/modules/buff_manager`

**Middleware Pattern:** No

---

### 7. `dashboard.lua`

**Primary Purpose:** Combat dashboard with resource bars, cooldown tracking, buff/debuff monitoring, and swing timers.

**Key Exported Functions:**
- `init(class_config)` - Initialize with class configuration
- `set_enabled(state)` / `set_position(x, y)` / `set_scale(scale)` - UI controls
- `update()` - Throttled update (10Hz)
- `render()` - Render dashboard (every frame)
- `register_render_callback()` - Register with Sylvanas render system
- `add_menu_items(menu, tree_node)` - Menu integration

**Dashboard Features:**
- Resource bar (rage/energy/mana/focus/runic)
- Cooldown icons with remaining time
- Buff/debuff tracking
- Timer bars (GCD + Swing)
- Action history (last 6 spells)
- Energy tick sweep animation
- Combo point pips (5 max)
- Threat bar with percentage

**Used By Specs:**
- EAXPaladinRetribution
- EAXDruidResto
- EAXDruidFeral
- EAXDruidBear
- EAXDruidBalance
- EAXPaladinProtection
- EAXPaladinHoly
- EAXMageFrost
- All modern specs

**IZI SDK Integration:**
- `izi.draw_spell_icon()` for spell rendering
- `izi.draw_icon()` for Wowhead icons
- Auto-caching graphics

**Middleware Pattern:** No

---

### 8. `energy_tick.lua`

**Primary Purpose:** Server-side energy tick tracking for Feral Druid optimization - prevents clipping ticks with unnecessary powershifts.

**Key Exported Functions:**
- `update(current_energy)` - Call every frame with player energy
- `time_until_next_tick()` - Returns seconds until next tick
- `should_delay_action()` - Returns true if tick < 0.4s away
- `on_shift()` - Reset tracking after powershift
- `get_last_tick_time()` - Returns timestamp of last detected tick
- `is_confident()` - Returns true if at least one tick detected

**Constants:**
- TICK_INTERVAL = 2.0 seconds
- DELAY_THRESHOLD = 0.4 seconds

**Used By Specs:**
- EAXDruidFeral (via dashboard_config.lua)
- EAXDruidResto (commented examples)
- All Druid specs with energy resource

**IZI SDK Integration:** None

**Middleware Pattern:** No

---

### 9. `force_commands.lua`

**Primary Purpose:** Force command system for `/eax burst` and `/eax def` slash commands.

**Key Exported Functions:**
- `init()` - Register chat event handler (call once on load)
- `is_burst_active()` - Check if burst mode active
- `is_defensive_active()` - Check if defensive mode active
- `should_bypass(is_burst_spell, is_defensive_spell)` - Check if spell should bypass normal checks
- `get_remaining(flag_name)` - Get remaining seconds for flag
- `set_burst(duration)` / `set_defensive(duration)` - Programmatic activation
- `clear_burst()` / `clear_defensive()` - Immediate clear

**Slash Commands:**
- `/eax burst` or `/eax offensive` - Activate burst for 3 seconds
- `/eax def` or `/eax defensive` - Activate defensive for 3 seconds

**Used By Specs:**
- EAXPaladinRetribution
- All specs with burst/defensive cooldowns

**IZI SDK Integration:** None

**Middleware Pattern:** No

---

### 10. `form_consumables.lua`

**Primary Purpose:** Form-aware consumable management for Druid specs - handles leave form → use consumable → return to form.

**Key Exported Functions:**
- `get_current_form(me)` - Returns CAT/BEAR/TRAVEL/AQUATIC/MOONKIN/TREE or nil
- `is_in_combat_form(me)` - Check if in combat-relevant form
- `is_in_any_form(me)` - Check if in any form
- `leave_form(me)` - Cancel current form
- `return_to_form(me, form_name, spell_ids)` - Cast form spell
- `get_ready_consumable(item_ids)` - Find first ready consumable
- `use_consumable(item_id, target)` - Use item
- `check_and_use(me, menu, form_spells, saved_form)` - Main entry point
- `get_consumable_counts()` - Get bag counts
- `has_any_ready()` - Check if any consumables available

**Supported Consumables:**
- Healthstones (all ranks)
- Healing Potions (all ranks)

**Used By Specs:**
- EAXDruidFeral
- EAXDruidBear
- EAXDruidResto
- EAXDruidBalance
- All Druid specs

**IZI SDK Integration:** None

**Middleware Pattern:** No

---

### 11. `heal_context.lua`

**Primary Purpose:** Shared healing context module for all EAX healing specs - builds cached view of healing situation.

**Key Exported Functions:**
- `get_context(me)` - Returns cached healing context
- `build(me)` - Force rebuild of context
- `invalidate()` - Force rebuild on next get
- `get_tanks()` - Returns array of tank units
- `get_injured_count(threshold)` - Count allies below HP threshold
- `get_aoe_heal_target(aoe_spell_id, min_targets)` - Find best AoE heal target
- `is_emergency_situation(emergency_threshold)` - Check if emergency healing needed
- `get_lowest_ally()` - Returns lowest HP ally + percentage
- `get_avg_party_hp()` - Returns average party health
- `unit_needs_healing(unit, threshold)` - Check specific unit
- `get_unit_health_pct(unit)` - Safe health percentage
- `is_unit_tank(unit)` / `is_unit_healer(unit)` - Role detection

**Context Table Structure:**
```lua
{
  tanks = {},
  healers = {},
  injured = {},
  lowest_ally = game_object,
  lowest_hp_pct = number,
  injured_count = number,
  total_allies = number,
  avg_party_hp = number,
  timestamp = number,
  valid = boolean
}
```

**Used By Specs:**
- EAXDruidResto
- EAXPriestHoly
- EAXPriestDiscipline
- EAXShamanRestoration
- EAXPriestSmite
- All healing specs

**IZI SDK Integration:**
- `izi.friends(range)` for ally scanning
- `izi.party(range)` for party scanning

**Middleware Pattern:** No

---

### 12. `heal_utils.lua`

**Primary Purpose:** Shared healing utilities for all EAX healing specs - target selection, effective health calculation, healability checks.

**Key Exported Functions:**
- `find_lowest_effective_ally(me, threshold, skip_self)` - Find lowest HP ally
- `get_tank_unit(me)` - Identify tank via aggro/role detection
- `count_below_hp(me, threshold)` - Count allies below threshold
- `get_mana_pct(me)` - Get mana percentage
- `is_healable_target(unit)` - Check if target can receive heals
- `predict_effective_deficit(unit, incoming_heal_lookahead)` - Calculate effective health deficit

**Used By Specs:**
- EAXDruidResto
- EAXPriestHoly
- EAXPriestDiscipline
- EAXShamanRestoration
- EAXPriestSmite
- All healing specs

**IZI SDK Integration:**
- `izi.friends(DEFAULT_ALLY_RANGE)` for ally scanning

**Middleware Pattern:** No

---

### 13. `hot_manager.lua`

**Primary Purpose:** HoT (Heal over Time) tracking for Druid and Priest healing - prevents overwriting HoTs, manages Lifebloom 3-stack.

**Key Exported Functions:**
- `has_hot(unit, hot_spell_id)` - Check if unit has specific HoT
- `get_hot_remaining(unit, hot_spell_id)` - Get remaining duration
- `count_hots(unit)` - Count total HoTs on target
- `is_lifebloom_refresh_needed(unit, refresh_threshold)` - Check if Lifebloom needs refresh
- `get_lifebloom_stacks(unit)` - Get current stack count (0-3)
- `get_renew_target(threshold)` - Find target needing Renew
- `get_rejuvenation_target(threshold)` - Find target needing Rejuvenation
- `get_regrowth_target(threshold)` - Find target needing Regrowth
- `get_lifebloom_target(threshold, refresh_threshold)` - Find target needing Lifebloom
- `clear_cache()` - Clear HoT cache
- `set_cache_ttl(seconds)` - Set cache time-to-live
- `get_cache_stats()` - Get debug statistics

**Supported HoTs:**
- Rejuvenation (all ranks)
- Regrowth (all ranks)
- Renew (all ranks)
- Lifebloom (TBC)

**Used By Specs:**
- EAXDruidResto
- EAXPriestHoly
- EAXPriestDiscipline
- All healing specs with HoTs

**IZI SDK Integration:**
- `unit:has_buff()` for efficient checking
- `unit:buff_remains()` for duration

**Middleware Pattern:** No

---

### 14. `hunter_clip_tracker.lua`

**Primary Purpose:** Hunter Auto Shot clip tracking - detects auto shot clipping with severity analysis and combat summaries.

**Key Exported Functions:**
- `on_auto_shot_fired()` - Call when auto shot fires
- `on_spell_cast(spell_name, is_melee)` - Track spell casts
- `on_auto_shot_cast(spell_id)` - Handler for auto shot cast event
- `on_melee_attack()` - Track melee attacks
- `on_start_moving()` / `on_stop_moving()` - Movement tracking
- `on_combat_start()` / `on_combat_end()` - Combat state
- `update(me)` - Main update loop (call from main.lua)
- `print_combat_summary()` - Print session statistics
- `reset_combat_stats()` - Reset statistics
- `set_enabled(enabled)` / `is_enabled()` - Toggle tracking
- `set_thresholds(green_yellow, yellow_orange, orange_red)` - Set severity thresholds
- `get_csv_export()` - Export data as CSV
- `get_stats()` / `get_recent_clips(count)` - Data getters
- `get_severity_color(severity)` - Get color for severity level

**Severity Levels:**
- GREEN: ≤125ms delay
- YELLOW: ≤250ms delay
- ORANGE: ≤500ms delay
- RED: >500ms delay

**Clip Causes Tracked:**
- Movement
- Melee spells (Raptor Strike, Mongoose Bite, etc.)
- Cast-bar spells (Steady Shot, Aimed Shot)
- Instant casts (Arcane Shot)
- Unknown

**Used By Specs:**
- EAXHunterBM
- EAXHunterMM
- EAXHunterSurvival
- All Hunter specs

**IZI SDK Integration:** None

**Middleware Pattern:** No

---

### 15. `mana_manager.lua`

**Primary Purpose:** Unified mana recovery library for all caster specs - manages mana gems, potions, runes, and class abilities.

**Key Exported Functions:**
- `get_mana_pct(me)` - Get current mana percentage
- `get_first_ready_item(item_ids)` - Find first ready consumable
- `use_consumable(me, item_id)` - Use a consumable
- `resolve_life_tap_rank(me, ranks)` - Find highest learned Life Tap
- `check_and_recover(me, menu, class_recovery)` - Main recovery logic

**Class Recovery Configurations:**
```lua
MAGE = { gems = true, potions = true, runes = true, evocation = 12051 }
PRIEST = { potions = true, runes = true, shadowfiend = 34433 }
DRUID = { potions = true, runes = true, innervate = 29166 }
WARLOCK = { potions = true, runes = true, life_tap = {...} }
SHAMAN = { potions = true, runes = true, mana_tide_totem = 16190 }
```

**Recovery Priority:**
1. Class abilities (Shadowfiend, Innervate, Life Tap)
2. Mana gems (Mage only)
3. Potions
4. Runes
5. Evocation (Mage last resort)

**Used By Specs:**
- EAXMageFrost
- EAXMageFire
- EAXMageArcane
- EAXPriestHoly
- EAXPriestDiscipline
- EAXPriestShadow
- EAXWarlockAffliction
- EAXWarlockDemonology
- EAXWarlockDestruction
- EAXShamanElemental
- EAXShamanRestoration
- All mana-using specs

**IZI SDK Integration:** None

**Middleware Pattern:** No

---

### 16. `middleware.lua`

**Primary Purpose:** Middleware pattern for cross-cutting rotation concerns - allows registering handlers that execute before main rotation logic.

**Key Exported Functions:**
- `register(mw)` - Register a middleware definition
- `unregister(name)` - Remove middleware by name
- `clear()` - Clear all middleware
- `count()` - Get count of registered middleware
- `build_context(me, target, settings, force_commands)` - Build execution context
- `execute(icon, context)` - Execute all middleware in priority order

**Pre-built Middleware Factories:**
- `healthstone(spell_id, threshold_pct, priority)` - Healthstone usage
- `healing_potion(item_id, threshold_pct, priority)` - Healing potion
- `mana_potion(item_id, threshold_pct, priority)` - Mana potion
- `defensive_racial(spell_id, threshold_pct, priority)` - Defensive racials
- `offensive_racial(spell_id, priority)` - Offensive racials
- `emergency_heal(spell_id, threshold_pct, priority, requires_combo_points)` - Self-heals
- `self_buff(spell_id, buff_id, priority, ooc_only)` - Buff maintenance

**Priority Constants:**
```lua
PRIORITY = {
  FORM_RESHIFT = 500,
  EMERGENCY_HEAL = 400,
  RECOVERY_ITEMS = 300,
  MANA_RECOVERY = 280,
  SELF_BUFFS = 150,
  OFFENSIVE_CDS = 100,
  PVP_DEFENSIVE = 90,
  INTERRUPTS = 50,
}
```

**Class Set Creation:**
- `create_class_set(class_name, menu_config)` - Create standard middleware for a class
- `setup_common(config)` - Quick setup for common middleware

**Used By Specs:**
- EAXDruidResto
- EAXDruidFeral
- EAXDruidBear
- EAXDruidBalance
- EAXPaladinRetribution
- EAXPaladinProtection
- EAXPaladinHoly
- EAXMageFrost
- All modern specs

**IZI SDK Integration:**
- Uses `core.spell_queue.add()` if available
- Falls back to `icon:cast()`

**Middleware Pattern:** Yes - this IS the middleware system

---

### 17. `powershift.lua`

**Primary Purpose:** Druid Feral powershift automation - auto-detects Wolfshead Helm and manages energy-efficient shifting.

**Key Exported Functions:**
- `has_wolfshead(me)` - Check if Wolfshead Helm equipped
- `get_shift_energy(me)` - Calculate energy gain from shift (40 + 20 with Wolfshead)
- `get_threshold(me, settings)` - Get energy threshold for powershifting
- `has_sufficient_mana(me, settings)` - Check if enough mana to shift
- `is_in_combat(me)` - Check combat status
- `should_powershift(me, current_energy, energy_tick_module, settings)` - Decision logic
- `execute(me, target, energy_tick_module, cat_form_id)` - Perform powershift
- `get_debug_info(me, current_energy, energy_tick_module)` - Debug data

**Constants:**
- WOLFSHEAD_HELM_ID = 8345
- FUROR_ENERGY = 40
- WOLFSHEAD_BONUS = 20
- DEFAULT_THRESHOLD = 20
- THRESHOLD_WITH_WOLFSHEAD = 25
- MIN_MANA_PCT = 0.25

**Used By Specs:**
- EAXDruidFeral
- EAXDruidResto (commented examples)
- All Druid specs with Cat Form

**IZI SDK Integration:** None

**Middleware Pattern:** No

---

### 18. `smart_defensive.lua`

**Primary Purpose:** Smart defensive cooldown management for tanking specs - uses combat_forecast for predictive mitigation.

**Key Exported Functions:**
- `predict_burst(me, window_seconds)` - Predict if burst damage incoming
- `get_current_mitigation(me)` - Get damage mitigation from stances/buffs
- `count_nearby_enemies(me, radius)` - Count enemies in radius
- `should_use(me, defensive_type, ctx, settings)` - Should use defensive CD?
- `has_similar_buff(me, defensive_type)` - Check for existing similar buff
- `get_recommended_defensive(me, ctx, available_defensives, settings)` - Get best defensive
- `should_defensive_stance_pvp(me, ctx, settings)` - PvP stance switching
- `get_spell_cooldown(spell_id)` - Helper for spell CD
- `get_status(me, ctx)` - Get defensive status summary

**Defensive Types Supported:**
- last_stand, shield_wall, barkskin, frenzied_regen
- divine_shield, lay_on_hands

**Used By Specs:**
- EAXDruidResto
- EAXDruidFeral
- EAXDruidBear
- EAXPaladinRetribution
- EAXPaladinProtection
- EAXPaladinHoly
- EAXWarriorProtection
- EAXWarriorFury
- All tanking specs

**IZI SDK Integration:** None

**Middleware Pattern:** No

---

### 19. `swing_manager.lua`

**Primary Purpose:** Heroic Strike / Cleave next-swing queue management for Warriors - with rage prediction and swing timing.

**Key Exported Functions:**
- `queue_next_swing(me, heroic_strike_id, cleave_id, rage_threshold, use_cleave, target)` - Queue next-swing ability
- `is_queued(spell_id)` - Check if spell already queued
- `get_next_swing_time(me)` - Get time until next swing
- `cancel_queue(me, heroic_strike_id, cleave_id)` - Cancel queued ability
- `update_swing(me)` - Update swing timing info
- `time_until_next_swing()` - Get seconds until main-hand swing
- `time_until_offhand_swing()` - Get seconds until off-hand swing
- `is_swing_landing_soon(threshold)` - Check if swing landing within threshold
- `is_offhand_landing_soon(threshold)` - Check off-hand swing
- `get_swing_progress()` / `get_offhand_progress()` - Get progress 0.0-1.0
- `get_swing_speed()` - Get current weapon speed
- `is_dual_wielding()` - Check if dual wielding
- `predict_rage(me)` - Predict rage from next swing
- `predict_offhand_rage(me)` - Predict off-hand rage
- `predict_rage_in_window(me, time_window)` - Predict rage in time window
- `get_future_rage(current_rage, me)` - Get predicted rage after swing
- `should_delay_for_swing(ability_rage_cost, current_rage, threshold)` - Check if should delay
- `record_rage_gain(rage_gained)` - Record actual rage for calibration
- `get_avg_rage_per_swing()` - Get historical average
- `get_dashboard_data()` - Get data for dashboard
- `update_dashboard(dashboard_module)` - Update dashboard swing timer
- `reset()` - Reset all state
- `would_clip_swing(cast_time, threshold)` - Check if ability would clip swing

**Used By Specs:**
- EAXPaladinRetribution
- EAXWarriorFury
- EAXWarriorArms
- EAXWarriorProtection
- All Warrior specs

**IZI SDK Integration:** None

**Middleware Pattern:** No

---

### 20. `threat_tab_manager.lua`

**Primary Purpose:** Threat-aware tab targeting system for tanking specs - switches targets based on threat situation.

**Key Exported Functions:**
- `get_threat_level(target, me)` - Get threat tier (0-3)
- `get_unit_priority(target)` - Get unit priority (BOSS/ELITE/TRASH)
- `is_manual_target_grace()` - Check if manual target grace period active
- `update_manual_target(current_target)` - Update manual target detection
- `get_best_target(me, current_target, min_priority)` - Get best target for threat
- `should_tab(me, current_target, menu)` - Should we tab target?
- `execute_tab(me)` - Execute tab to desired target
- `get_state()` - Get debug state info
- `reset()` - Reset all state

**Threat Tiers:**
- 0 = Loose mob (not on threat table)
- 1 = Have threat but not tanking (target is someone else)
- 2 = Insecurely tanking (high threat but not highest)
- 3 = Securely tanking (highest threat)

**Switch Logic:**
- Current threat 0: Stay and build threat
- Current threat 1: Switch to loose mobs only
- Current threat 2: Switch to loose mobs, then non-tanking
- Current threat 3: Can switch to any lower tier

**Used By Specs:**
- EAXWarriorProtection
- EAXPaladinProtection
- EAXDruidBear
- All tanking specs

**IZI SDK Integration:** None

**Middleware Pattern:** No

---

### 21. `trinket_manager.lua`

**Primary Purpose:** Trinket automation with offensive/defensive modes, TTD gating, burst conditions, and force command integration.

**Key Exported Functions:**
- `use_trinket_if_ready(slot)` - Use trinket in slot (13 or 14)
- `check_trinkets(me, is_burst_window, menu)` - Basic trinket check
- `get_trinket_status(menu)` - Get status of both trinkets
- `get_trinket_mode(menu, slot)` - Get mode for trinket slot
- `should_fire_offensive(ttd, min_ttd)` - Check if offensive trinket should fire
- `should_fire_defensive(me, threshold)` - Check if defensive trinket should fire
- `check_trinkets_v2(me, target, is_burst_active, force_commands, combat_forecast, menu, opts)` - Enhanced check
- `use_trinket_izi(slot)` - Use trinket via IZI SDK

**Mode Constants:**
- OFF = 0
- OFFENSIVE = 1
- DEFENSIVE = 2

**Menu Values:**
- 1 = Off
- 2 = Offensive
- 3 = Defensive

**Used By Specs:**
- EAXPaladinRetribution
- EAXDruidResto
- EAXDruidFeral
- EAXDruidBear
- EAXDruidBalance
- EAXPaladinProtection
- EAXPaladinHoly
- EAXMageFrost
- All specs with trinket slots

**IZI SDK Integration:**
- `izi.item(item_id)` for trinket usage
- `izi_item:use_self_safe()`

**Middleware Pattern:** No

---

### 22. `ooc_manager.lua`

**Primary Purpose:** Out-of-combat utility system for all EAX specs - handles drinking, eating, resurrection, and buffing.

**Key Exported Functions:**
- `try_drink(me, menu, utils)` - Try to drink when mana low
- `try_eat(me, menu, utils)` - Try to eat when health low
- `try_resurrect(me, rez_spell_id, menu, utils, allow_in_combat)` - Resurrect dead party members
- `try_group_buff(me, spell_id, buff_ids, buff_name, menu_toggle, menu, utils)` - Cast group buffs
- `on_update(me, menu, utils, opts)` - Main entry point called from spec main.lua

**OOC Features:**
- Automatic drinking below mana threshold
- Automatic eating below health threshold
- Party resurrection with role-based priority
- Self and party buff casting
- Throttled scanning to reduce CPU

**Used By Specs:**
- EAXPaladinRetribution
- EAXWarriorFury (archive)
- EAXWarriorProtection (archive)
- All specs with OOC utilities

**IZI SDK Integration:** None (uses spell_queue)

**Middleware Pattern:** No

---

## Usage Matrix Summary

| Library | DPS Specs | Tank Specs | Healer Specs | Hunter | Druid |
|---------|-----------|------------|--------------|--------|-------|
| anti_fake_manager | ✓ | ✓ | - | - | - |
| burst_manager | ✓ | - | - | - | ✓ |
| cc_detector | ✓ | ✓ | ✓ | - | - |
| combat_forecast | ✓ | ✓ | ✓ | - | ✓ |
| compat | ✓ | - | - | - | - |
| context_builder | - | ✓ | - | - | - |
| dashboard | ✓ | ✓ | ✓ | ✓ | ✓ |
| energy_tick | - | - | - | - | ✓ |
| force_commands | ✓ | ✓ | ✓ | - | - |
| form_consumables | - | - | - | - | ✓ |
| heal_context | - | - | ✓ | - | ✓ |
| heal_utils | - | - | ✓ | - | ✓ |
| hot_manager | - | - | ✓ | - | ✓ |
| hunter_clip_tracker | - | - | - | ✓ | - |
| mana_manager | ✓ | - | ✓ | - | - |
| middleware | ✓ | ✓ | ✓ | - | ✓ |
| powershift | - | - | - | - | ✓ |
| smart_defensive | - | ✓ | - | - | ✓ |
| swing_manager | ✓ | ✓ | - | - | - |
| threat_tab_manager | - | ✓ | - | - | - |
| trinket_manager | ✓ | ✓ | ✓ | - | ✓ |
| ooc_manager | ✓ | ✓ | ✓ | - | - |

---

## IZI SDK Integration Summary

| Library | IZI SDK Usage |
|---------|----------------|
| dashboard | `izi.draw_spell_icon()`, `izi.draw_icon()` |
| heal_context | `izi.friends()`, `izi.party()` |
| heal_utils | `izi.friends()` |
| hot_manager | `unit:has_buff()`, `unit:buff_remains()` |
| trinket_manager | `izi.item()` |
| middleware | `izi.spell()` (via spell_queue) |

---

## Middleware Pattern Usage

| Library | Pattern Role |
|---------|--------------|
| middleware | **Core middleware system** - register/execute pattern |
| compat | Middleware registry for legacy specs |

**Middleware Consumers:**
- All specs using `libraries/middleware` for cross-cutting concerns
- Healthstones, potions, racials, emergency heals, self-buffs

---

## Key Design Patterns Observed

1. **API Caching:** All libraries cache hot-path APIs at module load (`local _core_time = core.time`)

2. **Nil Guards:** Menu access uses `(menu.key and menu.key:get()) or default` pattern

3. **Static Table Reuse:** Libraries use `{ n = 0 }` pattern instead of `{}` to avoid GC pressure

4. **pcall Wrappers:** All API calls wrapped in pcall for safety

5. **Throttled Updates:** Context builders use time-based throttling (0.5s, 2s intervals)

6. **IZI SDK Fallbacks:** Libraries check for IZI SDK availability and fall back to core APIs

7. **Squared Distance:** All distance checks use squared values (avoid sqrt)

---

## Recommendations for Wave 2/3

1. **Standardize IZI SDK Usage:** More libraries could benefit from IZI SDK integration
2. **Expand Middleware:** More specs should adopt middleware pattern for consistency
3. **Unify Healing Libraries:** Consider merging heal_context, heal_utils, and hot_manager
4. **Add More Class Sets:** middleware.lua needs more class-specific sets (Warlock, Hunter, etc.)
5. **Documentation:** Each library should have usage examples in header comments

---

## QA Verification

- ✓ All 22 libraries cataloged
- ✓ File names and purposes documented
- ✓ Key functions identified for each
- ✓ Spec usage mapped via grep analysis
- ✓ IZI SDK integration points noted
- ✓ Middleware pattern usage identified

**Total Lines Analyzed:** ~10,000+ lines across 22 libraries

---

*Document generated for EAX TBC Classic Wave 1 Review against Flux reference.*

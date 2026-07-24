-- main_sylvanas.lua — EAX Rotation dispatcher for Project Sylvanas TBC Anniversary (2.5.5).
-- WHAT:  loads spec files, builds context, dispatches to strategy tables.
-- WHEN:  on_update tick; handles playstyle switching and spec resolution.
-- WHY:   single entry point for all 29 specs; centralizes engine wiring.
-- SAFETY: nil-guards on all NS references; throttled playstyle detection.

-- update dispatcher for class middleware and selected playstyle strategies.
local NS = _G.EaxRotations
if not NS then return nil end

-- Pattern 2: cache core.* at module load
local _core = _G.core or {}

local spec_kit = require("shared/spec_kit_sylvanas")
local lazy_context = require("shared/lazy_context_sylvanas")

local M = {}
local _context = lazy_context.create()
_context.lowest = { unit = nil, hp = 100 }
local _combat_start_time = nil
local was_in_combat = false
local _combat_state_last_known = 0  -- timestamp when combat state was last confirmed by API
local _last_target_guid = nil          -- Previous frame's target GUID for manual target change detection
local _manual_target_lockout_until = 0 -- Timestamp when 3s manual target grace period expires
local _pet_cache_data = nil
local _pet_cache_timestamp = 0
local _cached_inventory_time = 0
local _ooc_ok, ooc_manager = pcall(require, "shared/ooc_manager_sylvanas")
if not _ooc_ok then ooc_manager = nil end
local _hyst_ok, EnemyCountHysteresis = pcall(require, "shared/enemy_count_hysteresis_sylvanas")
if not _hyst_ok or type(EnemyCountHysteresis) ~= "table" then EnemyCountHysteresis = { update = function() end, smoothed_count = function() return 0 end } end
local _burst_ok, BurstLogic = pcall(require, "shared/burst_logic_sylvanas")
if not _burst_ok or type(BurstLogic) ~= "table" then BurstLogic = { should_auto_burst = function() return nil end } end
local _forecast_gate_ok = pcall(require, "shared/combat_forecast_gate_sylvanas")
if not _forecast_gate_ok and not NS.should_use_long_cd then NS.should_use_long_cd = function() return true end end
local _combat_forecast_ok, combat_forecast = pcall(require, "common/modules/combat_forecast")
if not _combat_forecast_ok or type(combat_forecast) ~= "table" then combat_forecast = nil end
-- Platform-provided target selector: pre-filtered enemy and heal target lists
local _target_selector_ok, target_selector = pcall(require, "common/modules/target_selector")
if not _target_selector_ok or type(target_selector) ~= "table" then target_selector = nil end
-- unit_helper (from api): recommended optimized path for get_enemy_list_around / get_ally_list_around
-- (see apidocs/pages/dev/api/object-manager.md). Loaded here for context building.
local _uh_ok, unit_helper = pcall(require, "common/utility/unit_helper")
if not _uh_ok or type(unit_helper) ~= "table" then unit_helper = nil end
-- Platform-provided health prediction: tank detection, PvP detection, incoming damage
local _health_pred_ok, health_prediction = pcall(require, "common/modules/health_prediction")
if not _health_pred_ok or type(health_prediction) ~= "table" then health_prediction = nil end
-- Platform-provided inventory helper: consumable tracking, bag scanning
local _inv_ok, inventory_helper = pcall(require, "common/utility/inventory_helper")
if not _inv_ok or type(inventory_helper) ~= "table" then inventory_helper = nil end
local _ttd_tracker_ok, ttd_tracker = pcall(require, "shared/ttd_tracker_sylvanas")
if not _ttd_tracker_ok or type(ttd_tracker) ~= "table" then ttd_tracker = nil end
local _ttd_ema_ok, ttd_ema = pcall(require, "shared/ttd_ema_tracker_sylvanas")
if not _ttd_ema_ok or type(ttd_ema) ~= "table" then ttd_ema = nil end
local _aft_ok, aft = pcall(require, "shared/active_fight_tracker_sylvanas")
if not _aft_ok or type(aft) ~= "table" then aft = nil end
local _tick_profiler_ok, tick_profiler = pcall(require, "shared/tick_profiler_sylvanas")
if not _tick_profiler_ok then tick_profiler = nil end
local _buff_db_ok, buffs = pcall(require, "common/buff_db")
if not _buff_db_ok or type(buffs) ~= "table" then buffs = {} end
local BLOODLUST_IDS = buffs.BLOODLUST or { 2825, 32182 }
local DRUMS_IDS = buffs.DRUMS or { 35475, 35474, 35473, 35476 }

-- Wire native engine combat callbacks (core.register_on_combat_*_callback) for reliable,
-- event-driven live combat state. This reduces dependence on per-tick polling + 1s decay
-- and gives deeper, more accurate understanding of "when combat started" for combat_time,
-- CD gating, burst windows, etc. (per apidocs/pages/dev/api/core.md and API_ADOPTION_ANALYSIS).
-- Falls back gracefully to existing poll logic if engine callbacks unavailable.
-- (pcall-wrapped registration; does not affect context build if the engine lacks the callback).
local _engine_driven_combat = false
if _core and type(_core.register_on_combat_start_callback) == "function" then
    pcall(_core.register_on_combat_start_callback, function()
        local now = _api.time_now and _api.time_now() or 0
        _combat_start_time = now
        was_in_combat = true
        _engine_driven_combat = true
        _combat_state_last_known = now
    end)
end
if _core and type(_core.register_on_combat_end_callback) == "function" then
    pcall(_core.register_on_combat_end_callback, function()
        _combat_start_time = nil
        was_in_combat = false
        _engine_driven_combat = true
        _combat_state_last_known = _api.time_now and _api.time_now() or 0
        if aft and aft.reset then pcall(aft.reset) end
    end)
end

-- PvP context field constants (cc_target, cc_safe, fear_nearby, enemy_healer, melee_on_you)
local FEAR_IDS = {
    5782, 6213, 6215,  -- Fear ranks
    5484, 17928,       -- Howl of Terror
    8122, 8124, 10888, 10890,  -- Psychic Scream (Durnholde Wardens per WoWHead OHF guide)
    33111,             -- Bellowing Roar (Nightbane, Hellmaw)
    30615,             -- Fear (Ramparts Scryers)
    22884,             -- Psychic Scream (Old Hillsbrad)
    12542,             -- Fear (Black Morass etc.)
    19134,             -- Frightening Shout (Fel Overseer, SSC)
    36922,             -- Bellowing Roar (Nightbane)
    39415,             -- Fear (Harbinger Skyriss Arcatraz per WoWHead guide)
    39427,             -- Bellowing Roar (TK advisors)
    46561,             -- Fear (Sunblade Dusk Priest Sunwell Plateau per WoWHead SWP trash guide)
    34984,             -- Psychic Horror (Fen Ray Underbog)
    38660,             -- Fear (Coilfang Siren Steamvault)
    32830,             -- Possess (Phantasmal Possessor Auchenai Crypts MC)
    -- Additional common TBC fear/horror effects from WoWHead dungeon guides
    38759, 38760,      -- Various horror/fear from bosses/trash
}  -- Expanded based on WoWHead TBC dungeon/raid guides (Shadow Labyrinth Hellmaw/Fel Overseers, Ramparts Scryers, OHF Wardens, Sethekk Prophets, Arcatraz Skyriss, Kael'thas, SWP Sunblade Dusk Priests, Underbog Fen Rays, Steamvault Sirens, Botanica, Slave Pens, Auchenai Crypts MC etc.) to prevent tank fears causing wipes

-- Broader control loss for advanced dungeon/raid mechanics (fear, charm/MC, sleep, horror)
-- Covers Blackheart Incite Chaos (MC/charm), other MCs, sleeps (Anetheron), etc.
-- Used for general control_nearby, tank protection, healing priority.
local CONTROL_LOSS_IDS = {
  -- fears (reuse)
  5782,6213,6215,5484,17928,8122,8124,10888,10890,33111,30615,22884,12542,38759,38760,19134,36922,39415,39427,46561,34984,38660,32830,
  -- charm / MC (Blackheart Incite Chaos from WoWHead; Skyriss Domination)
  33676, 33684, 37162,
  -- add more sleep/horror/MC as verified (e.g. from DBC or guides)
  --  e.g. sleep IDs if known
}
local HEALER_CLASS_IDS = { [5]=true, [2]=true, [11]=true, [7]=true }  -- Priest, Paladin, Druid, Shaman
local MELEE_CLASS_IDS = { [1]=true, [4]=true, [2]=true, [7]=true, [11]=true }  -- Warrior, Rogue, Paladin, Shaman, Druid

-- Spell queue module is loaded here so the dispatcher knows it is available.
-- Actual queueing happens inside NS.try_cast() in core_sylvanas.lua.
local _spell_queue_ok, spell_queue_module = pcall(require, "common/modules/spell_queue")
if not _spell_queue_ok or type(spell_queue_module) ~= "table" then spell_queue_module = nil end

-- Expose for strategy access; nil if unavailable.
NS.spell_queue = spell_queue_module

-- Pet manager: loaded at module load (not per-frame) so the hot path doesn't
-- pcall(require, ...) every tick.  Hunter-only at runtime; preloading here
-- means the dispatcher can call pet_manager.on_update unconditionally and
-- the worst case is a single function pointer indirection.
local _pet_manager_mod_ok, pet_manager = pcall(require, "shared/pet_manager_sylvanas")
if not _pet_manager_mod_ok or type(pet_manager) ~= "table" then pet_manager = nil end
NS.pet_manager = pet_manager

-- Auto-loot module (background corpse looting, v1.0)
local _autoloot_ok, auto_loot = pcall(require, "shared/auto_loot_sylvanas")
if not _autoloot_ok or type(auto_loot) ~= "table" then auto_loot = nil end
NS.auto_loot = auto_loot

-- Expose platform-provided modules for spec consumption.
-- health_prediction: tank detection, PvP detection, incoming damage heuristics.
NS.health_prediction = health_prediction

-- health_pred_helper must load AFTER NS.health_prediction is set (it wraps that API).
-- Exposes NS.incoming_damage / NS.predicted_hp_pct / NS.is_tank_role for healers/tanks.
local _hph_ok, health_pred_helper = pcall(require, "shared/health_pred_helper_sylvanas")
if not _hph_ok or type(health_pred_helper) ~= "table" then health_pred_helper = nil end

local _last_error_time = 0
local _trace_strat_last = {}  -- per-list trace throttle (keyed by strategy list name)
local _trace_strategy_last = {}  -- per-strategy trace throttle — keyed by ``list:strategy_name``. Used to suppress the matched=true/executed=false spam from AutoConsumable et al when the executor is a no-op (no setting matches, no item in bags). Default 30s budget per strategy.
local TRACE_PER_STRATEGY_TTL = 30.0  -- seconds between per-strategy trace lines

-- Hot-path NS API references cached at module load in _api table (Pattern 2) to avoid repeated lookups and keep upvalue count low for build_context (Lua 5.1 limit ~60).
local _api = {
    time_now = NS.time_now,
    game_time_ms = NS.game_time_ms,
    unit_health_pct = NS.unit_health_pct,
    mana_pct = NS.mana_pct,
    power_current = NS.power_current,
    buff_up = NS.buff_up,
    debuff_remains = NS.debuff_remains,
    debuff_up = NS.debuff_up,
    unit_alive = NS.unit_alive,
    get_party_members = NS.GetPartyMembers,
    get_focus = NS.GetFocus,
    get_pet = NS.GetPet,
    get_player_stance = NS.get_player_stance,
    is_hostile_unit = NS.is_hostile_unit,
    is_pvp_zone = NS.is_pvp_zone,
    is_in_party = NS.is_in_party,
    player_control_locked = NS.player_control_locked,
    has_breakable_cc_nearby = NS.has_breakable_cc_nearby,
    get_debuff_stacks = NS.get_debuff_stacks,
    same_unit = NS.same_unit,
    gcd_remains = NS.gcd_remains,
    get_global_cooldown = NS.get_global_cooldown,
    safe = NS.safe,
    safe_field = NS.safe_field,
    safe_method = NS.safe_method,
}

-- Local alias for unit alive check (used in build_context for party/fear/cc scans).
-- Falls back to pcall on :is_alive() for robustness when _api.unit_alive is missing/nil.
local _unit_alive = _api.unit_alive or function(unit)
    if not unit then return false end
    local ok, res = pcall(function() return unit:is_alive() end)
    return ok and res == true
end

-- Talent build detection: resolve API reference dynamically (may be nil at load, available later)
local function _get_talent_info(...)
    local fn = _core.game_ui and _core.game_ui.get_talent_info
    if type(fn) == "function" then
        return fn(...)
    end
end
local _cached_talent_build = nil
local _cached_talent_build_time = 0

local _get_expansion_max_level = NS.get_expansion_max_level
local function _get_player()
    local p = NS.GetPlayer and NS.GetPlayer()
    if p then return p end
    local c = rawget(_G, "core")
    if c and c.object_manager and type(c.object_manager.get_local_player) == "function" then
        local ok, fresh = pcall(c.object_manager.get_local_player, c.object_manager)
        if ok and fresh then
            local valid = pcall(function() return fresh:is_valid() end)
            if valid then
                NS.PLAYER_UNIT = fresh
                return fresh
            end
        end
    end
    return nil
end

local _cached_tank_alive, _cached_tank_alive_time = true, -1

-- ============================================================================
-- Event-driven fear / control loss tracking
-- ============================================================================
-- Maintain module-level state of party members (and self) affected by fear or
-- control-loss debuffs.  Updated via COMBAT_LOG_EVENT_UNFILTERED aura events
-- when the engine supports it, with a throttled fallback scan for resync.
-- ============================================================================
local _active_fears = {}      -- guid -> true
local _active_controls = {}   -- guid -> true
local _fear_control_event_mode = false
local _last_fear_control_resync = 0
local FEAR_CONTROL_RESYNC_MS = 3000
local FEAR_CONTROL_FALLBACK_MS = 500

-- Build a lookup of fear/control IDs for fast event filtering.
local _FEAR_ID_SET, _CONTROL_ID_SET = {}, {}
for i = 1, #FEAR_IDS do _FEAR_ID_SET[FEAR_IDS[i]] = true end
for i = 1, #CONTROL_LOSS_IDS do _CONTROL_ID_SET[CONTROL_LOSS_IDS[i]] = true end

-- Register event-driven aura tracking if the engine supports it.
if _core and type(_core.register_on_game_event_callback) == "function" then
    local ok = pcall(function()
        _core.register_on_game_event_callback("COMBAT_LOG_EVENT_UNFILTERED", function(...)
            local _, event, _, source_guid, _, _, _, dest_guid, _, _, spell_id = ...
            if not dest_guid or dest_guid == "" then return end
            if event == "SPELL_AURA_APPLIED" or event == "SPELL_AURA_REFRESH" or event == "SPELL_AURA_APPLIED_DOSE" then
                if _FEAR_ID_SET[spell_id] then
                    _active_fears[dest_guid] = true
                end
                if _CONTROL_ID_SET[spell_id] then
                    _active_controls[dest_guid] = true
                end
            elseif event == "SPELL_AURA_REMOVED" or event == "SPELL_AURA_REMOVED_DOSE" then
                if _FEAR_ID_SET[spell_id] then
                    _active_fears[dest_guid] = nil
                end
                if _CONTROL_ID_SET[spell_id] then
                    _active_controls[dest_guid] = nil
                end
            end
        end)
    end)
    _fear_control_event_mode = ok
end

-- ============================================================================
-- Auto-AoE Toggle State
-- ============================================================================
local _auto_aoe_last_enemy_count = 0
local _auto_aoe_state_changed_at = nil
local _auto_aoe_base_playstyle = nil

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    local now = _core.time and _core.time() or 0
    if now - _last_error_time > 2 then
        _last_error_time = now
        NS.log("Rotation Callback Warning: " .. tostring(a))
    end
    return nil
end

local function fast(fn, ...)
    if type(fn) ~= "function" then return nil end
    return fn(...)
end

-- ============================================================================
-- Global Reaction Delay: simulates human reaction time for ALL classes.
-- When active, blocks BOTH middleware and playstyle strategies.
-- Read from NS.get_setting("reaction_delay_ms", 0). Default 0 = disabled.
-- Burst windows (should_burst) bypass the delay unconditionally.
-- ============================================================================
local _reaction_delay_start = nil
local _reaction_was_on_gcd = false
local _expansion_logged = false

local function log_expansion_once(config, active)
    if _expansion_logged then return end
    if type(NS.is_vanilla) ~= "function" or not NS.is_vanilla() then return end
    _expansion_logged = true
    local spec_display = active
    if config and config.playstyles then
        for _, ps in ipairs(config.playstyles) do
            if ps.name == active then
                spec_display = ps.display_name or ps.name
                break
            end
        end
    end
    local class_name = (config and config.class_name) or "Unknown"
    NS.log("Classic Era (1.12) rotation active: " .. class_name .. " " .. tostring(spec_display))
end

local function reaction_delay_active(context)
    local delay_ms = spec_kit.setting_number(nil, "reaction_delay_ms", 0)
    if delay_ms <= 0 then
        _reaction_delay_start = nil
        _reaction_was_on_gcd = false
        return false
    end
    -- Disable during burst windows (Bloodlust, trinkets, etc.)
    if context.should_burst then
        _reaction_delay_start = nil
        _reaction_was_on_gcd = false
        return false
    end
    -- Only gate when in combat with a valid target
    if not context.in_combat or not context.has_valid_enemy_target then
        _reaction_delay_start = nil
        _reaction_was_on_gcd = false
        return false
    end
    local gcd_remains = context.gcd_remains or 0
    if gcd_remains > 0 then
        _reaction_was_on_gcd = true
        return false  -- Still on GCD, let rotation run normally
    end
    -- GCD just ended — start the reaction delay timer
    if _reaction_was_on_gcd then
        _reaction_delay_start = (_api.time_now and _api.time_now()) or 0
        _reaction_was_on_gcd = false
    end
    if not _reaction_delay_start then return false end
    -- Check if we're still within the delay window
    local now = (_api.time_now and _api.time_now()) or 0
    local elapsed_ms = (now - _reaction_delay_start) * 1000
    if elapsed_ms < delay_ms then return true end
    -- Delay expired, allow rotation
    _reaction_delay_start = nil
    return false
end

local function get_target(me)
    if me then
        local get_t = _api.safe_field and _api.safe_field(me, "get_target") or nil
        if get_t then
            local t = fast(get_t, me)
            if t and _api.unit_alive and _api.unit_alive(t) then return t end
        end
    end
    -- fallback to NS.GetTarget (which has IZI etc) only if needed
    return NS.GetTarget and NS.GetTarget() or nil
end

local function valid_enemy(me, target)
    if not target then return false end
    -- Dead check: don't cast on dead units
    local alive_ok, alive = pcall(function() return target:is_alive() end)
    if alive_ok and alive == false then return false end
    return NS.is_hostile_unit and NS.is_hostile_unit(me, target) or false
end

local function find_enemy_target(me, selected)
    -- Always accept the player's manually selected target, but skip dead units.
    if selected then
        local alive_ok, alive = pcall(function() return selected:is_alive() end)
        if alive_ok and alive == false then return nil end
        return selected
    end
    -- During manual target grace period, skip all fallbacks — respect the player's choice
    if NS.time_now() < _manual_target_lockout_until then
        return nil
    end
    -- Focus target: user-set /focus is intentional, not auto-acquisition
    local focus = NS.GetFocus and NS.GetFocus() or nil
    local focus_ok = valid_enemy(me, focus)
    if focus_ok then return focus end
    return nil
end

local _cached_enemies, _cached_enemies_time = nil, -1
local _fear_boss_scan_time = 0
local FEAR_BOSS_SCAN_INTERVAL_MS = 1500  -- throttle nearby fear caster scan in groups for proactive protection
-- ============================================================================
-- Boss School Immunity Database (TBC)
-- ============================================================================
local BOSS_SCHOOL_IMMUNITIES = {
    -- The Curator (Karazhan) — Arcane immune
    [15691] = { arcane = true },
    -- Hydross the Unstable (SSC) — Nature immune while corrupted
    [21216] = { nature = true },
    -- Void Reaver (TK) — Arcane immune (spell reflect, effectively immune)
    [19516] = { arcane = true },
    -- Al'ar (TK) — Fire immune (DBC SchoolImmuneMask=4; previously mislabeled "not fire immune")
    [19514] = { fire = true },

    -- (stale "not fire immune" comment removed — Al'ar entry added above)
    -- Rage Winterchill (Hyjal) — Frost immune (lich)
    [17767] = { frost = true },
}

local function get_target_school_immunities(target)
    if not target then return {} end
    local id = nil
    local npc_id = NS.safe_field and NS.safe_field(target, "get_npc_id")
    if npc_id then
        local ok, result = pcall(npc_id, target)
        if ok then id = result end
    end
    if type(id) ~= "number" then
        local entry_id = NS.safe_field and NS.safe_field(target, "entry_id")
        if entry_id then
            local ok, result = pcall(entry_id, target)
            if ok then id = result end
        end
    end
    if type(id) ~= "number" then
        id = target.id or target.entry or nil
    end
    if type(id) == "number" then
        return BOSS_SCHOOL_IMMUNITIES[id] or {}
    end
    return {}
end

-- Expose on the namespace so NS.evaluate_cast (core_sylvanas.lua) can consult
-- the boss school-immunity DB. Nil-guarded: only set if the function exists.
if NS then
    NS.get_target_school_immunities = get_target_school_immunities
end

-- ============================================================================
-- Auto-AoE Toggle Logic
-- ============================================================================
local function get_auto_aoe_threshold()
    local threshold = spec_kit.setting_number(nil, "auto_aoe_threshold", 3)
    return type(threshold) == "number" and threshold or 3
end

local function auto_aoe_enabled()
    return spec_kit.setting_bool(nil, "auto_aoe_enabled", true)
end

local function auto_aoe_should_trigger(enemy_count)
    if not auto_aoe_enabled() then return false end
    local threshold = get_auto_aoe_threshold()
    return enemy_count >= threshold
end

local function resolve_auto_aoe_playstyle(registry, active, enemy_count)
    if not registry or not registry.playstyles then return active end
    local now = _api.time_now and _api.time_now() or 0
    local is_aoe = auto_aoe_should_trigger(enemy_count)
    local was_aoe = auto_aoe_should_trigger(_auto_aoe_last_enemy_count or 0)
    -- Debounce: require 0.5s stable state before switching to prevent flicker
    if is_aoe ~= was_aoe then
        _auto_aoe_state_changed_at = now
    end
    _auto_aoe_last_enemy_count = enemy_count
    -- If no state change has ever been recorded, treat as stable (first run)
    local changed_at = _auto_aoe_state_changed_at
    local stable = changed_at == nil or (now - changed_at) >= 0.5
    if is_aoe and stable then
        -- Determine the AoE playstyle we would switch to
        local aoe_playstyle = nil
        if registry.playstyles.aoe then
            aoe_playstyle = "aoe"
        else
            local class_key = registry.class_config and registry.class_config.class_key
            if class_key == "warrior" and registry.playstyles.fury then aoe_playstyle = "fury"
            elseif class_key == "mage" and registry.playstyles.fire then aoe_playstyle = "fire"
            elseif class_key == "warlock" and registry.playstyles.destruction then aoe_playstyle = "destruction"
            elseif class_key == "hunter" and registry.playstyles.survival then aoe_playstyle = "survival"
            elseif class_key == "paladin" and registry.playstyles.retribution then aoe_playstyle = "retribution"
            elseif class_key == "shaman" and registry.playstyles.enhancement then aoe_playstyle = "enhancement"
            elseif class_key == "priest" and registry.playstyles.shadow then aoe_playstyle = "shadow"
            elseif class_key == "rogue" and registry.playstyles.combat then aoe_playstyle = "combat"
            elseif class_key == "druid" and registry.playstyles.feral then aoe_playstyle = "feral"
            end
        end
        -- Only switch (and remember base) if we're not already in the AoE playstyle
        if aoe_playstyle and active ~= aoe_playstyle then
            _auto_aoe_base_playstyle = active
            return aoe_playstyle
        end
        -- Already in AoE mode, just return active unchanged
        return active
    elseif not is_aoe and stable and _auto_aoe_base_playstyle then
        -- Switching BACK from AoE: restore the original base playstyle
        local base = _auto_aoe_base_playstyle
        _auto_aoe_base_playstyle = nil
        return base
    end
    return active
end

local function throttled_enemies()
    local now = NS.game_time_ms and NS.game_time_ms() or 0
    if now - _cached_enemies_time > 100 then
        if target_selector and type(target_selector.get_targets) == "function" then
            _cached_enemies = target_selector:get_targets(40)
        elseif unit_helper and _get_player then
            -- Prefer documented unit_helper path for spatial lists when target_selector unavailable
            -- (apidocs/pages/dev/api/object-manager.md + unit_helper).
            local me = _get_player()
            local pos = me and _api.safe_field and _api.safe_field(me, "get_position") and me:get_position() or nil
            if pos then
                local ok, lst = pcall(unit_helper.get_enemy_list_around, unit_helper, pos, 40, false, false)
                _cached_enemies = ok and lst or nil
            else
                _cached_enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(40) or nil
            end
        else
            _cached_enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(40) or nil
        end
        _cached_enemies_time = now
    end
    return _cached_enemies
end

local function throttled_enemies_count()
    local enemies = throttled_enemies()
    if type(enemies) ~= "table" then return 0 end
    return enemies.n or #enemies
end

local function combo_points(me)
    local combo_points_current = NS.safe_field and NS.safe_field(me, "combo_points_current") or nil
    local v = combo_points_current and fast(combo_points_current, me) or nil
    local get_power = NS.safe_field and NS.safe_field(me, "get_power") or nil
    if type(v) ~= "number" and get_power then v = fast(get_power, me, 4) end
    return type(v) == "number" and v or 0
end

local function target_time_to_die(target)
    local time_to_die = NS.safe_field and (NS.safe_field(target, "time_to_die") or NS.safe_field(target, "get_time_to_death")) or nil
    local value = time_to_die and fast(time_to_die, target) or nil
    return type(value) == "number" and value > 0 and value or nil
end

local function get_linear_regression_ttd(target, settings)
    if not ttd_tracker or not target then return nil end
    local now = _api.time_now and _api.time_now() or 0
    local ok, result = pcall(ttd_tracker.update, target, now, settings)
    if ok and type(result) == "number" and result > 0 then return result end
    return nil
end

local function get_ema_ttd(target)
    if not ttd_ema or not target then return nil end
    local now = _api.time_now and _api.time_now() or 0
    local ok = pcall(ttd_ema.update, target, now)
    if not ok then return nil end
    local ttd = ttd_ema.get_ttd(target, now)
    return type(ttd) == "number" and ttd > 0 and ttd or nil
end

local function unit_bool(unit, ...)
    if not unit or not _api.safe_field then return false end
    for i = 1, select("#", ...) do
        local fn = _api.safe_field(unit, select(i, ...))
        if fn then local ok, result = pcall(fast, fn, unit); if ok and result == true then return true end end
    end
    return false
end

local function unit_number(unit, field)
    if not unit or not _api.safe_field then return nil end
    local fn = _api.safe_field(unit, field)
    if not fn then return nil end
    local ok, value = pcall(fast, fn, unit)
    return ok and type(value) == "number" and value or nil
end

local function core_string(field)
    local fn = _core and _core[field]
    local value = type(fn) == "function" and fast(fn) or nil
    return type(value) == "string" and value or nil
end

local function reset_target_dependent_state(old_guid, new_guid)
    if old_guid == new_guid then return end
    if ttd_ema and ttd_ema.reset then ttd_ema.reset(old_guid) end
    if ttd_tracker and ttd_tracker.reset then ttd_tracker.reset(old_guid) end
    if aft and aft.reset then pcall(aft.reset) end
    -- Swing timer module has no per-target state, but if it ever does, reset here
end


local function build_context()
    -- Create a fresh lazy context each tick so stale caches from the previous
    -- frame cannot leak into the current frame.  Roots are set eagerly below;
    -- everything else is resolved on first access.
    _context = lazy_context.create()
    _context.lowest = { unit = nil, hp = 100 }
    local me = _get_player()
    if not me then
        NS.current_context = nil
        return nil
    end
    local selected_target = get_target(me)
    -- Detect manual target change: if GUID differs from last frame, start 3s grace period
    if selected_target then
        local current_guid = nil
        local get_guid = _api.safe_field and _api.safe_field(selected_target, "get_guid") or nil
        if get_guid then
            local ok, guid = pcall(get_guid, selected_target)
            if ok then current_guid = guid end
        end
        if current_guid and _last_target_guid then
            local ok, diff = pcall(function() return current_guid ~= _last_target_guid end)
            if ok and diff then
                _manual_target_lockout_until = (_api.time_now and _api.time_now() or 0) + 3.0
            end
        end
        reset_target_dependent_state(_last_target_guid, current_guid)
        _last_target_guid = current_guid
    else
        reset_target_dependent_state(_last_target_guid, nil)
        _last_target_guid = nil
    end
    local target = find_enemy_target(me, selected_target)
    local is_in_combat = _api.safe_field and _api.safe_field(me, "is_in_combat") or nil
    local raw_in_combat = is_in_combat and fast(is_in_combat, me) or nil
    local combat_state_known = type(raw_in_combat) == "boolean"
    local in_combat
    if combat_state_known then
        in_combat = raw_in_combat
        _combat_state_last_known = _api.time_now and _api.time_now() or 0
    else
        -- Decay: if API has been returning nil for > 1s, assume out of combat.
        -- Engine callbacks (wired at load) keep was_in_combat and _combat_start_time fresh
        -- via core.register_on_combat_*_callback for more accurate live state.
        if was_in_combat and (_api.time_now and _api.time_now() or 0) - _combat_state_last_known > 1.0 then
            was_in_combat = false
        end
        in_combat = was_in_combat
    end

    if not _combat_start_time and me and in_combat then _combat_start_time = _api.time_now and _api.time_now() or 0 end
    if _combat_start_time and me and combat_state_known and not in_combat then
        _combat_start_time = nil
        -- v1.0: Auto-loot grace period tracking
        if NS.auto_loot and NS.auto_loot.stats then
            NS.auto_loot.stats.last_combat_end = _api.time_now and _api.time_now() or 0
        end
    end
    local enemy_ok = valid_enemy(me, target)
    -- BUGFIX (2026-06-29): ``find_enemy_target`` preserves the player's
    -- manually-selected target even when it is friendly (non-hostile).
    -- ``valid_enemy`` correctly rejects it (``enemy_ok = false``), but
    -- ``target`` was left non-nil and propagated into ``context.target``.
    -- Every DPS spec that only guards on ``not context.target`` (instead of
    -- ``not context.has_valid_enemy_target``) would then fire its execute
    -- with a friendly unit, and the SDK emitted the per-frame "You have no
    -- target" toast.  Clear the target here so no spec ever sees a
    -- non-enemy.  Safe for healers — no healer spec uses context.target
    -- for healing casts.
    if target and not enemy_ok then target = nil end
    local _enemies_cache = throttled_enemies()
    local count = (_enemies_cache and _enemies_cache.n) or (_enemies_cache and #_enemies_cache) or 0
    local engine_ttd = enemy_ok and target_time_to_die(target) or nil
    local instance_type_raw = core_string("get_instance_type")
    if type(instance_type_raw) ~= "string" then
        -- Some PS builds return numeric instance type IDs; coerce to string
        instance_type_raw = tostring(instance_type_raw or "none")
    end
    local instance_type = instance_type_raw:lower()
    local player_level = unit_number(me, "get_effective_level") or unit_number(me, "get_level") or 70
    local target_level = target and (unit_number(target, "get_effective_level") or unit_number(target, "get_level")) or nil
    local target_classification = target and unit_number(target, "get_classification") or nil
    local expansion_max_level = _get_expansion_max_level and _get_expansion_max_level() or 70
    -- Compute boss/elite flag locally before _context is fully populated
    local is_target_boss = target and NS.unit_is_boss and NS.unit_is_boss(target) or false
    -- Use get_boss_frames / get_boss_count for authoritative live raid/dungeon boss awareness (per apidocs object-manager and plan for deeper context).
    _context.boss_count = 0
    _context.has_boss_frames = false
    if _core and _core.object_manager then
        if type(_core.object_manager.get_boss_count) == "function" then
            local ok, bc = pcall(_core.object_manager.get_boss_count)
            if ok and type(bc) == "number" then _context.boss_count = bc end
        end
        if type(_core.object_manager.get_boss_frames) == "function" then
            local ok, bf = pcall(_core.object_manager.get_boss_frames)
            if ok and type(bf) == "table" and #bf > 0 then _context.has_boss_frames = true end
        end
    end
    -- ============================================================================
    -- TTD (Time-To-Death) Fallback Chain (LAZY)
    -- ============================================================================
    -- A single shared resolver computes the TTD fallback chain once per tick;
    -- individual fields (ttd, ttd_source, ttd_known) read from the cached result.
    -- Resolution is deferred until all root fields are populated below.
    -- ============================================================================
    _context._register("ttd_data", {"target", "in_combat", "has_valid_enemy_target", "target_level", "target_is_boss", "player_level"}, function(ctx)
        local t = ctx.target
        if not ctx.in_combat or not ctx.has_valid_enemy_target or not t then
            return { ttd = 999, source = "none", known = false }
        end
        local ema = get_ema_ttd(t)
        if ema then return { ttd = ema, source = "ema", known = true } end
        local lvl = ctx.target_level or 0
        local boss = ctx.target_is_boss or false
        if boss or lvl > ctx.player_level then
            local regression = get_linear_regression_ttd(t, NS.settings)
            if regression then return { ttd = regression, source = "regression", known = true } end
        end
        local engine = target_time_to_die(t)
        if engine then return { ttd = engine, source = "engine", known = true } end
        return { ttd = 999, source = "none", known = false }
    end)
    _context._register("ttd", {"ttd_data"}, function(ctx) return ctx.ttd_data.ttd end)
    _context._register("ttd_source", {"ttd_data"}, function(ctx) return ctx.ttd_data.source end)
    _context._register("ttd_known", {"ttd_data"}, function(ctx) return ctx.ttd_data.known end)
    _context.me = me
    _context.target = target
    _context.target_casting = target and (unit_bool(target, "is_casting") or unit_bool(target, "is_channeling") or false) or false
    _context.has_aggro = false
    if target and me then
        local get_threat = _api.safe_field and _api.safe_field(target, "get_threat_situation")
        if get_threat then
            local ok, result = pcall(get_threat, target, me)
            _context.has_aggro = ok and type(result) == "number" and result >= 2
        end
    end
    _context.in_combat = in_combat
    _context.combat_state_known = combat_state_known
    -- OOC safety: refuse auto-selected targets when out of combat (any zone).
    -- Prevents engine-level auto-targeting from triggering combat initiation
    -- in PvP zones, Booty Bay, or anywhere the player hasn't manually engaged.
    -- Player must start combat manually (tab/click/cast); then rotation takes over.
    -- Only clear auto-selected targets (selected_target nil); preserve manual targets.
    if target and not in_combat and not selected_target then
        target = nil
        _context.target = nil
        _context.target_casting = false
        _context.target_ttd = nil
        _context.has_aggro = false
        enemy_ok = false
    end
    _context.has_target = target ~= nil
    _context.has_valid_enemy_target = enemy_ok
    _context.target_hp = enemy_ok and _api.unit_health_pct(target) or 100
    _context.player_level = player_level
    _context.level = player_level
    _context.expansion_max_level = expansion_max_level
    _context.is_leveling = player_level < expansion_max_level
    _context.target_level = target_level
    _context.target_level_delta = target_level and (target_level - player_level) or 0
    _context.target_classification = target_classification
    _context.hp = _api.unit_health_pct(me)
    _context.player_hp = _context.hp
    _context.mana_pct = _api.mana_pct(me)
    _context.player_mana = _context.mana_pct
    _context.player_mana_pct = _context.mana_pct
    -- Surface native incoming heals (from game_object:get_incoming_heals) for better
    -- live prediction in triage, stopcast, emergency heals (builds directly on api).
    _context.player_incoming_heals = 0
    _context.target_incoming_heals = 0
    if NS.get_incoming_heals then
        local ok_p, pin = pcall(NS.get_incoming_heals, me)
        if ok_p and type(pin) == "number" then _context.player_incoming_heals = pin end
        if target then
            local ok_t, tin = pcall(NS.get_incoming_heals, target)
            if ok_t and type(tin) == "number" then _context.target_incoming_heals = tin end
        end
    end
    _context.gcd_remains = _api.gcd_remains and _api.gcd_remains() or 0
    _context.on_gcd = (_context.gcd_remains or 0) > 0
    _context.gcd_duration = _api.get_global_cooldown and _api.get_global_cooldown() or 1.5
    _context.combat_time = _combat_start_time and (_api.time_now() - _combat_start_time) or 0
    _context.rage = _api.power_current(NS.POWER_RAGE)
    _context.player_rage = _context.rage
    _context.energy = _api.power_current(NS.POWER_ENERGY)
    _context.player_energy = _context.energy
    _context.focus = _api.power_current(NS.POWER_FOCUS)
    -- Attack power for cat druid AP snapshotting (falls back to 0 if unit method unavailable)
    _context.attack_power = unit_number(me, "get_attack_power") or 0
    -- Spell crit chance for paladin Illumination mana-return calculations.
    -- Expected as percentage (0-100); consumer divides by 100. Falls back to 0 if API unavailable.
    _context.crit_chance = unit_number(me, "get_spell_crit_chance") or 0
    -- Target armor for sunder/faerie fire value assessment
    _context.target_armor = unit_number(target, "get_armor") or 0
    _context.bloodlust_active = me and _api.buff_up(me, BLOODLUST_IDS) or false
    _context.drums_active = me and _api.buff_up(me, DRUMS_IDS) or false

    -- Enriched target cast context (centralized for live understanding of enemy casts).
    -- Builds on game_object cast methods + NS.is_interruptible (see apidocs and interrupt_manager).
    -- Allows specs to read context.target_casting_spell_id / target_casting_interruptible
    -- instead of duplicating the logic (seen in arms, fury, prot, ret, hunter, shaman, etc.).
    _context.target_casting_spell_id = nil
    _context.target_casting_interruptible = false
    if target then
        local ok_id, id = pcall(function()
            local fn = _api.safe_field and _api.safe_field(target, "get_active_spell_id")
            return fn and fn(target) or nil
        end)
        if ok_id then _context.target_casting_spell_id = id end

        if NS.is_interruptible then
            local ok_i, intr = pcall(NS.is_interruptible, target)
            _context.target_casting_interruptible = (ok_i and intr == true)
        end
    end
    _context.should_burst = BurstLogic.should_auto_burst(_context, {
        is_bloodlust_active = function() return _context.bloodlust_active end,
        is_drums_active = function() return _context.drums_active end,
    })
    _context.burst_reason = _context.should_burst and "burst_conditions_met" or nil
    -- target_distance uses get_distance when available, otherwise falls back to melee range check
    -- is_in_melee_range is a player method, not a target method
    local in_melee = false
    if me and me.is_in_melee_range then
        local ok, im = pcall(me.is_in_melee_range, me, target, 5)
        in_melee = ok and im == true
    end
    _context.in_melee_range = in_melee
    local dist_ok, dist_val = pcall(function() return target and _api.safe_field(target, "get_distance") and target:get_distance(me) end)
    _context.target_range = (dist_ok and type(dist_val) == "number") and dist_val or (_context.in_melee_range and 5 or 40)
    _context.target_distance = _context.target_range
    _context.combo_points = combo_points(me)
    _context.enemy_count = count
    _context.enemies_count = count
    -- Tune hysteresis from player settings if available; defaults remain 500/2000ms.
    local _hyst_settings = NS.settings and NS.settings.hysteresis or nil
    if type(_hyst_settings) == "table" then
        EnemyCountHysteresis.configure({
            rise_hold_ms = _hyst_settings.rise_hold_ms,
            drop_hold_ms = _hyst_settings.drop_hold_ms,
        })
    end
    -- Feed raw enemy count into the hysteresis smoother; specs opt in via enemy_count_smoothed.
    local _now_ms = NS.game_time_ms and NS.game_time_ms() or 0
    EnemyCountHysteresis.update(count, _now_ms)
    _context.enemy_count_smoothed = EnemyCountHysteresis.smoothed_count()
    -- Reset hysteresis when leaving combat to avoid bleed-over from prior pulls.
    if not in_combat then EnemyCountHysteresis.reset() end
    local now_pet = NS.game_time_ms and NS.game_time_ms() or 0
    if now_pet - _pet_cache_timestamp > 500 then
        _pet_cache_data = _api.get_pet and _api.get_pet()
        _pet_cache_timestamp = now_pet
    end
    _context.pet = _pet_cache_data
    _context.pet_dead = _pet_cache_data and not _pet_cache_data:is_alive() or false
    -- Pet happiness: 1=unhappy, 2=content, 3=happy (nil if no pet or API unavailable)
    local ph_data = nil
    if _core.spell_book and _core.spell_book.get_pet_happiness then
        local ph_ok, ph_result = pcall(_core.spell_book.get_pet_happiness)
        if ph_ok then ph_data = ph_result end
    end
    _context.pet_happiness = ph_data and ph_data.happiness or nil
    _context.stance = _api.get_player_stance() or 0
    _context.player_class = NS.player_class_id
    -- Check for active totems via get_totem_info (shaman only)
    local has_totems = false
    if me and NS.player_class_id == 7 and _core and _core.spell_book and _core.spell_book.get_totem_info then
        for slot = 1, 4 do
            local ok, info = pcall(_core.spell_book.get_totem_info, slot)
            if ok and info and info.have_totem then
                has_totems = true
                break
            end
        end
    end
    _context.has_totems = has_totems
    _context.is_moving = unit_bool(me, "is_moving")
    _context.is_casting = unit_bool(me, "is_casting", "is_casting_spell")
    _context.is_channeling = unit_bool(me, "is_channeling", "is_channelling_spell")
    if not _context.is_casting and not _context.is_channeling then
        _context.is_channeling = unit_bool(me, "is_channeling_or_casting")
    end
    -- PvP detection: health_prediction platform module, fallback to zone-based detection
    if health_prediction and type(health_prediction.is_pvp_situation) == "function" and target then
        local ok, pvp_sit = pcall(health_prediction.is_pvp_situation, health_prediction, target)
        _context.is_pvp = ok and pvp_sit == true
    else
        _context.is_pvp = _api.is_pvp_zone and _api.is_pvp_zone() or false
    end
    _context.instance_type = instance_type
    _context.is_dungeon = instance_type == "party"
    _context.is_raid = instance_type == "raid"
    _context.is_arena = instance_type == "arena"
    _context.is_battleground = instance_type == "pvp"
    _context.is_group = _context.is_dungeon or _context.is_raid or (_api.is_in_party and _api.is_in_party() or false)
    _context.is_solo = not _context.is_group
    -- Party list from the new _core.object_manager.get_party_frames (_core.party) feature via NS.GetPartyMembers().
    -- Key benefit: authoritative UI-backed list (ordered, excl self) for group logic, lowest HP, tank_alive,
    -- fear_nearby, party dispels/buffs in middlewares (druid/priest/paladin etc.), healing collection.
    -- Much more accurate and cheaper than visible object scans.
    local _party_members = nil
    if _context.is_group then
        _party_members = NS.GetPartyMembers and NS.GetPartyMembers() or nil
    end
    _context.party = _party_members
    _context.party_members = _party_members
    _context.group_members = _party_members
    _context.party_count = (_party_members and #_party_members) or 0
    -- Frame count (for awareness; get_party_frames is the source of truth for real party UI)
    _context.party_frame_count = 0
    if _core and _core.object_manager and type(_core.object_manager.get_party_frames) == "function" then
        local ok, pf = pcall(_core.object_manager.get_party_frames)
        if ok and type(pf) == "table" then _context.party_frame_count = #pf end
    end
    -- ============================================================================
    -- Lazy party / group scans
    -- ============================================================================
    -- These fields are expensive and only needed by some specs (healers, tanks,
    -- PvP). They are resolved on first access and cached for the rest of the tick.
    -- A single shared scan computes all party-derived flags in one pass; the
    -- individual resolvers below simply read from the cached scan result.
    --
    -- Fear/control detection is event-driven when the engine supports it; the
    -- scan here is used as a fallback/resync path.
    -- ============================================================================
    _context._register("party_scan", {"is_group", "party", "me", "target"}, function(ctx)
        local result = {
            tank_alive = true,
            group_injured = false,
            fear_nearby = false,
            fear_on_tank = false,
            feared_tank = nil,
            control_nearby = false,
            control_on_tank = false,
            controlled_tank = nil,
            known_fear_boss = false,
            lowest_unit = nil,
            lowest_hp = 100,
            party_injured_count = 0,
            party_tanks = {},
            party_imminent_deaths = 0,
            party_burst_count = 0,
            party_will_die_count = 0,
        }

        -- Event-driven fear/control state: derive from tracked GUIDs.
        -- Build a set of valid party GUIDs so we can ignore stale entries.
        local party_guids = {}
        local party = ctx.party
        local m = ctx.me
        if party then
            for _, u in ipairs(party) do
                if u then
                    local guid = nil
                    if u.get_guid then
                        local ok, g = pcall(u.get_guid, u)
                        if ok then guid = g end
                    end
                    if not guid and u.guid then guid = u.guid end
                    if guid then party_guids[guid] = u end
                end
            end
        end
        -- Include self GUID.
        local self_guid = nil
        if m then
            if m.get_guid then
                local ok, g = pcall(m.get_guid, m)
                if ok then self_guid = g end
            end
            if not self_guid and m.guid then self_guid = m.guid end
            if self_guid then party_guids[self_guid] = m end
        end

        -- Determine if event-driven state indicates fear/control nearby.
        local event_fear_nearby = false
        local event_control_nearby = false
        local event_feared_tank = nil
        local event_controlled_tank = nil
        local event_fear_on_tank = false
        local event_control_on_tank = false

        if _fear_control_event_mode then
            for guid, u in pairs(party_guids) do
                if _active_fears[guid] then
                    event_fear_nearby = true
                    if NS.is_tank_unit then
                        local ok, is_tank = pcall(NS.is_tank_unit, u)
                        if ok and is_tank then
                            event_fear_on_tank = true
                            event_feared_tank = u
                        end
                    end
                end
                if _active_controls[guid] then
                    event_control_nearby = true
                    if NS.is_tank_unit then
                        local ok, is_tank = pcall(NS.is_tank_unit, u)
                        if ok and is_tank then
                            event_control_on_tank = true
                            event_controlled_tank = u
                        end
                    end
                end
            end
        end

        -- Fallback / resync scan: run periodically even in event mode to recover
        -- from missed removals, and always run when event mode is unavailable.
        local now_ms = NS.game_time_ms and NS.game_time_ms() or 0
        local should_scan = not _fear_control_event_mode
            or (now_ms - _last_fear_control_resync > FEAR_CONTROL_RESYNC_MS)
        if should_scan then
            _last_fear_control_resync = now_ms
            -- In event mode, clear stale entries for units no longer in party.
            if _fear_control_event_mode then
                for guid in pairs(_active_fears) do
                    if not party_guids[guid] then _active_fears[guid] = nil end
                end
                for guid in pairs(_active_controls) do
                    if not party_guids[guid] then _active_controls[guid] = nil end
                end
            end

            if party then
                for _, u in ipairs(party) do
                    if not u then
                        -- skip nil slots
                    else
                        local alive = _unit_alive(u)
                        if alive then
                            local has_fear = _api.debuff_up(u, FEAR_IDS)
                            local has_control = has_fear or _api.debuff_up(u, CONTROL_LOSS_IDS)
                            if has_fear then result.fear_nearby = true end
                            if has_control then result.control_nearby = true end
                            if NS.is_tank_unit then
                                local ok, is_tank = pcall(NS.is_tank_unit, u)
                                if ok and is_tank then
                                    if has_fear then
                                        result.fear_on_tank = true
                                        result.feared_tank = u
                                    end
                                    if has_control then
                                        result.control_on_tank = true
                                        result.controlled_tank = u
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- player self fear/control
            if m and _unit_alive(m) then
                if not result.fear_nearby and _api.debuff_up(m, FEAR_IDS) then result.fear_nearby = true end
                if not result.control_nearby and _api.debuff_up(m, CONTROL_LOSS_IDS) then
                    result.control_nearby = true
                    if NS.is_tank_unit and NS.is_tank_unit(m) then
                        result.control_on_tank = true
                        result.controlled_tank = m
                        if _api.debuff_up(m, FEAR_IDS) then
                            result.fear_on_tank = true
                            result.feared_tank = m
                        end
                    end
                end
            end
        end

        -- Merge event-driven state on top of fallback scan results.
        if event_fear_nearby then result.fear_nearby = true end
        if event_control_nearby then result.control_nearby = true end
        if event_fear_on_tank then
            result.fear_on_tank = true
            result.feared_tank = event_feared_tank
        end
        if event_control_on_tank then
            result.control_on_tank = true
            result.controlled_tank = event_controlled_tank
        end

        if not ctx.is_group then return result end

        if party then
            for _, u in ipairs(party) do
                if not u then
                    -- skip nil slots
                else
                    local alive = _unit_alive(u)

                    -- tank_alive: check even dead units so we know if the tank died
                    if result.tank_alive and not alive then
                        local is_tank = false
                        if health_prediction and type(health_prediction.is_tank) == "function" then
                            local ok, res = pcall(health_prediction.is_tank, health_prediction, u)
                            is_tank = ok and res
                        else
                            local ok, res = pcall(function() return u.is_tank and u:is_tank() end)
                            is_tank = ok and res
                        end
                        if is_tank then
                            result.tank_alive = false
                        end
                    end

                    if alive then
                        local hp = _api.unit_health_pct(u)

                        -- group_injured
                        if hp and hp < 90 then
                            result.group_injured = true
                            result.party_injured_count = result.party_injured_count + 1
                        end

                        -- lowest
                        if hp and hp < result.lowest_hp then
                            result.lowest_hp = hp
                            result.lowest_unit = u
                        end

                        -- tanks
                        if NS.is_tank_unit then
                            local ok, res = pcall(NS.is_tank_unit, u)
                            if ok and res then
                                result.party_tanks[#result.party_tanks + 1] = u
                            end
                        end

                        -- imminent deaths / will die
                        if NS.will_die_soon and NS.will_die_soon(u, 3.5, 22) then
                            result.party_will_die_count = result.party_will_die_count + 1
                            result.party_imminent_deaths = result.party_imminent_deaths + 1
                        end
                        if _unit_helper and type(_unit_helper.get_health_percentage_inc) == "function" then
                            local okf, f = pcall(_unit_helper.get_health_percentage_inc, _unit_helper, u, 3)
                            if okf and type(f) == "number" and (f * 100) < 25 then
                                result.party_imminent_deaths = result.party_imminent_deaths + 1
                            end
                        end

                        -- burst
                        local hpred = NS.health_prediction or (NS.GetAPIModule and NS.GetAPIModule("health_prediction"))
                        if hpred and type(hpred.get_incoming_damage) == "function" then
                            local oki, inc = pcall(hpred.get_incoming_damage, hpred, u, 2)
                            if oki and type(inc) == "number" and inc > 1200 then
                                result.party_burst_count = result.party_burst_count + 1
                            end
                        end
                    end
                end
            end
        end

        -- known fear boss
        local t = ctx.target
        if t and NS.AutoTremor and NS.AutoTremor.is_fear_boss then
            if NS.AutoTremor.is_fear_boss(t) then result.known_fear_boss = true end
        end
        if now_ms - _fear_boss_scan_time > FEAR_BOSS_SCAN_INTERVAL_MS then
            _fear_boss_scan_time = now_ms
            if _core.object_manager and type(_core.object_manager.get_enemies) == "function" and NS.AutoTremor and NS.AutoTremor.is_fear_boss then
                local ok, enemies = pcall(_core.object_manager.get_enemies)
                if ok and type(enemies) == "table" then
                    for i = 1, math.min(#enemies, 15) do
                        local e = enemies[i]
                        if e and NS.AutoTremor.is_fear_boss(e) then
                            result.known_fear_boss = true
                            break
                        end
                    end
                end
            end
        end

        return result
    end)

    _context._register("tank_alive", {"party_scan"}, function(ctx) return ctx.party_scan.tank_alive end)
    _context._register("group_injured", {"party_scan"}, function(ctx) return ctx.party_scan.group_injured end)
    _context._register("fear_nearby", {"party_scan"}, function(ctx) return ctx.party_scan.fear_nearby end)
    _context._register("control_nearby", {"party_scan"}, function(ctx) return ctx.party_scan.control_nearby end)
    _context._register("fear_on_tank", {"party_scan"}, function(ctx) return ctx.party_scan.fear_on_tank end)
    _context._register("feared_tank", {"party_scan"}, function(ctx) return ctx.party_scan.feared_tank end)
    _context._register("control_on_tank", {"party_scan"}, function(ctx) return ctx.party_scan.control_on_tank end)
    _context._register("controlled_tank", {"party_scan"}, function(ctx) return ctx.party_scan.controlled_tank end)
    _context._register("known_fear_boss", {"party_scan"}, function(ctx) return ctx.party_scan.known_fear_boss end)
    _context._register("control_risk", {"party_scan"}, function(ctx) return ctx.party_scan.control_nearby or ctx.party_scan.known_fear_boss or false end)
    _context._register("lowest_unit", {"party_scan"}, function(ctx) return ctx.party_scan.lowest_unit end)
    _context._register("lowest_hp", {"party_scan"}, function(ctx) return ctx.party_scan.lowest_hp end)
    _context._register("party_injured_count", {"party_scan"}, function(ctx) return ctx.party_scan.party_injured_count end)
    _context._register("party_tanks", {"party_scan"}, function(ctx) return ctx.party_scan.party_tanks end)
    _context._register("party_imminent_deaths", {"party_scan"}, function(ctx) return ctx.party_scan.party_imminent_deaths end)
    _context._register("party_burst_count", {"party_scan"}, function(ctx) return ctx.party_scan.party_burst_count end)
    _context._register("party_will_die_count", {"party_scan"}, function(ctx) return ctx.party_scan.party_will_die_count end)

    -- `lowest` table is the legacy interface used by healers.  Keep it in sync
    -- with the lazy `lowest_unit` / `lowest_hp` fields.
    _context._register("lowest", {"lowest_unit", "lowest_hp"}, function(ctx)
        return { unit = ctx.lowest_unit, hp = ctx.lowest_hp }
    end)

    _context._register("heal_targets", {}, function(ctx)
        return NS.get_targets_heal and NS.get_targets_heal(5) or {}
    end)
    _context._register("heal_targets_count", {"heal_targets"}, function(ctx) return #ctx.heal_targets end)

    _context.settings = NS.settings or {}
    -- ttd, ttd_source, ttd_known are now lazy (registered above)
    _context.has_breakable_cc_nearby = _api.has_breakable_cc_nearby and _api.has_breakable_cc_nearby() or false
    -- Boss school immunities for strategy gating
    local school_immunities = get_target_school_immunities(target)
    _context.target_arcane_immune = school_immunities.arcane == true
    _context.target_nature_immune = school_immunities.nature == true
    _context.target_fire_immune = school_immunities.fire == true
    _context.target_frost_immune = school_immunities.frost == true
    _context.target_shadow_immune = school_immunities.shadow == true
    _context.target_holy_immune = school_immunities.holy == true
    _context.target_is_player = false
    if target and _api.safe_field then
        local fn = _api.safe_field(target, "is_player")
        if fn then
            local ok, result = pcall(fast, fn, target)
            _context.target_is_player = ok and result == true
        end
    end
    _context.target_is_boss = is_target_boss
    if _context.in_combat and _context.has_valid_enemy_target and _context.target then
        _context.target_ttd = _context.ttd
        _context.target_ttd_source = _context.ttd_source
    end
    -- ============================================================================
    -- Derived context fields (for specs that consume nil-unsafe guards)
    -- ============================================================================
    -- Threat percentage (0-100) for threat-sensitive specs (rogue, warlock, shaman)
    -- NS.threat_status returns raw status (0-3); scale to 0-100 for spec compatibility
    if target and me then
        local raw_threat = NS.threat_status and NS.threat_status(target, me) or 0
        _context.threat_pct = (raw_threat / 3) * 100
    else
        _context.threat_pct = 0
    end
    -- Bleed immune creature types (Elemental=4, Undead=6, Mechanical=9)
    _context.target_bleed_immune = false
    if target then
        local ok_ct, ctype = pcall(function() return target:get_creature_type() end)
        if ok_ct and ctype then
            _context.target_bleed_immune = (ctype == 4 or ctype == 6 or ctype == 9)
        end
    end
    -- DR (diminishing returns) on stun for target.
    -- Defaults to 0 (no DR) — stays 0 if NS.DRTracker module failed to load.
    _context.target_dr_stun = 0
    if target and NS.DRTracker and NS.DRTracker.get_dr_multiplier then
        local ok_dr, dr_mult = pcall(NS.DRTracker.get_dr_multiplier, target, "stun")
        if ok_dr and dr_mult then
            _context.target_dr_stun = dr_mult  -- 1.0 = full, <1.0 = diminished
        end
    end
    -- Sunder Armor presence on target
    _context.has_sunder = false
    if target then
        _context.has_sunder = _api.debuff_remains and _api.debuff_remains(target, { 7386, 7405, 8380, 11596, 11597, 25225 }) > 0 or false
    end
    -- AoE damage incoming (enemy count > 1 as proxy for cleave/AoE packs)
    _context.aoe_damage_incoming = count > 1
    -- Is this a raid boss? (worldboss=3 classification or target_is_boss)
    _context.is_raid_boss = is_target_boss or (target_classification and target_classification >= 3) or false
    -- Fire mage: Improved Scorch maintenance (Scorch debuff = spell ID 22959)
    _context.scorch_stacks = 0
    _context.scorch_remains = 0
    if target then
        _context.scorch_stacks = _api.get_debuff_stacks and _api.get_debuff_stacks(target, { 22959 }) or 0
        _context.scorch_remains = _api.debuff_remains and _api.debuff_remains(target, { 22959 }) or 0
    end
    -- Enemy array for spec-level iteration (frost mage Cone of Cold, prot pally CC checks)
    _context.enemies = _enemies_cache or {}
    -- Legacy aliases for paladin specs that use alternative field names
    _context.enemy_list = _context.enemies
    _context.targets = _context.enemies
    -- PvP: CC target for Polymorph (mage specs) — uses focus target when valid
    _context.cc_target = nil
    if _context.is_pvp and target then
        local focus = _api.get_focus and _api.get_focus() or nil
        if focus and _unit_alive(focus) and valid_enemy(me, focus) and not _api.same_unit(focus, target) then
            _context.cc_target = focus
        end
    end
    -- PvP: CC-safe flag for AoE (shaman elemental) — false when nearby enemies are CC'd
    _context.cc_safe = true
    if _context.is_pvp and target then
        local enemies = _enemies_cache
        if type(enemies) == "table" then
            local n = enemies.n or #enemies
            for i = 1, n do
                local e = enemies[i]
                if e and _unit_alive(e) then
                    -- Use API CC check when available (replaces hardcoded NS.CC_DEBUFFS)
                    local is_cc_fn = NS.safe_field and NS.safe_field(e, "is_cc")
                    if is_cc_fn then
                        local ok, is_cc = pcall(is_cc_fn, e)
                        if ok and is_cc then
                            _context.cc_safe = false
                            break
                        end
                    elseif _api.debuff_up(e, NS.CC_DEBUFFS) then
                        _context.cc_safe = false
                        break
                    end
                end
            end
        end
    end
    -- PvP: Enemy healer detection for curse selection (warlock specs)
    _context.enemy_healer = false
    if _context.is_pvp and target and _api.safe_field then
        local get_class = _api.safe_field(target, "get_class")
        if get_class then
            local ok, class_id = pcall(fast, get_class, target)
            if ok and class_id and HEALER_CLASS_IDS[class_id] then
                _context.enemy_healer = true
            end
        end
    end
    -- PvP: Melee enemy targeting player for defensive curse/Howl (warlock specs)
    _context.melee_on_you = false
    if _context.is_pvp and target and me and _api.safe_field then
        local enemies = _enemies_cache
        if type(enemies) == "table" then
            local n = enemies.n or #enemies
            for i = 1, n do
                local e = enemies[i]
                if e and _unit_alive(e) then
                    local get_class_e = _api.safe_field and _api.safe_field(e, "get_class")
                    local ok_ec, class_id = pcall(fast, get_class_e, e)
                    if ok_ec and class_id and MELEE_CLASS_IDS[class_id] then
                        local get_target_fn = _api.safe_field(e, "get_target")
                        if get_target_fn then
                            local ok, e_target = pcall(get_target_fn, e)
                            if ok and e_target and _api.same_unit(e_target, me) then
                                _context.melee_on_you = true
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    -- Is the player mounted? (guards OOC buffs, aspect switching)
    _context.is_mounted = false
    if me and _api.safe_field then
        local fn = _api.safe_field(me, "is_mounted")
        if fn then
            local ok, result = pcall(fast, fn, me)
            _context.is_mounted = ok and result == true
        end
    end
    -- Is player control locked? (fear, charm, mind control — stop casting/gcd)
    _context.player_control_locked = _api.player_control_locked and _api.player_control_locked() or false
    _context.combat_length_forecast = _context.ttd or 999
    if combat_forecast and type(combat_forecast.get_forecast_single) == "function" then
        local ok, forecast = pcall(combat_forecast.get_forecast_single, target)
        if ok and type(forecast) == "number" and forecast > 0 then
            _context.combat_length_forecast = forecast
        end
    end
    -- Fallback: damage meter session duration (more accurate for ongoing fights)
    if _context.combat_length_forecast == 999 then
        local dm_dur = NS.damage_meter_session_duration and NS.damage_meter_session_duration()
        if type(dm_dur) == "number" and dm_dur > 5 then
            _context.combat_length_forecast = dm_dur
        end
    end
    -- ttd_known is now lazy (registered above)
    -- Consumable inventory: throttled to 1000ms (was every frame)
    if inventory_helper and type(inventory_helper.update_consumables_list) == "function" then
        local now = NS.game_time_ms and NS.game_time_ms() or 0
        if now - (_cached_inventory_time or 0) > 1000 then
            pcall(inventory_helper.update_consumables_list, inventory_helper)
            _cached_inventory_time = now
        end
    end
    _context.has_mana_potion = false
    _context.has_health_potion = false
    _context.has_damage_potion = false
    _context.has_food_or_drink = false
    if inventory_helper and type(inventory_helper.get_current_consumables_list) == "function" then
        local ok, consumables = pcall(inventory_helper.get_current_consumables_list, inventory_helper)
        if ok and type(consumables) == "table" then
            for i = 1, #consumables do
                local c = consumables[i]
                if c.is_mana_potion then _context.has_mana_potion = true end
                if c.is_health_potion then _context.has_health_potion = true end
                if c.is_damage_bonus_potion then _context.has_damage_potion = true end
                if c.is_food_or_drink then _context.has_food_or_drink = true end
            end
        end
    end
    -- Talent build: per-tree invested points from classic talent API.
    -- Throttled: recomputed OOC (every 5s) or every 30s in combat.
    -- Nil when API unavailable (backward compatible).
    -- Check talent API availability at call time (not just load time)
    local _has_talent_api = core and core.game_ui and type(core.game_ui.get_talent_info) == "function"
    if _has_talent_api then
        local now_tb = _api.time_now()
        local tb_age = now_tb - (_cached_talent_build_time or 0)
        local recompute = not _cached_talent_build or (not in_combat and tb_age > 5) or tb_age > 30
        if recompute then
            local tb = { tree1 = 0, tree2 = 0, tree3 = 0 }
            local ok, info
            for tab = 0, 2 do
                local tab_points = 0
                for idx = 0, 20 do
                    ok, info = pcall(_get_talent_info, tab, idx, false)
                    if ok and type(info) == "table" then
                        tab_points = tab_points + (info.rank or 0)
                    end
                end
                tb["tree" .. tostring(tab + 1)] = tab_points
            end
            _cached_talent_build = tb
            _cached_talent_build_time = now_tb
        end
        _context.talent_build = _cached_talent_build
    else
        _cached_talent_build = nil
        _cached_talent_build_time = 0
        _context.talent_build = nil
    end
    _context.now = _api.time_now and _api.time_now() or 0
    NS.current_context = _context
    -- Trace context state (throttled to 2s in combat)
    -- Fire combat start/end callbacks AFTER context is fully built so subscribers
    -- can safely read fields like settings, hp, mana_pct, ttd, enemy_count.
    if combat_state_known then
        if in_combat and not was_in_combat then
            if NS._fire_combat_start then NS._fire_combat_start(_context) end
        elseif not in_combat and was_in_combat then
            _manual_target_lockout_until = 0
            _last_target_guid = nil
            if NS._fire_combat_end then NS._fire_combat_end(_context) end
        end
        was_in_combat = in_combat
    end
    return _context
end

local last_playstyle_warning = nil

local function normalize_playstyle(registry, active)
    if type(registry) ~= "table" or type(registry.playstyles) ~= "table" then return active end
    if active ~= nil and registry.playstyles[active] then return active end

    local wanted = tostring(active or ""):lower()
    if registry.playstyles[wanted] then return wanted end
    if wanted == "affinity" and registry.playstyles.affliction then return "affliction" end

    local config = registry.class_config or {}
    for i = 1, #(config.playstyles or {}) do
        local entry = config.playstyles[i]
        local name = type(entry) == "table" and entry.name or entry
        local display = type(entry) == "table" and entry.display_name or entry
        if type(name) == "string" and (wanted == name:lower() or wanted == tostring(display or ""):lower()) then
            return name
        end
    end

    local fallback = config.default_playstyle
    if fallback and registry.playstyles[fallback] then
        local key = tostring(active or "nil") .. "->" .. tostring(fallback)
        if last_playstyle_warning ~= key then
            last_playstyle_warning = key
            NS.log_warning("Invalid playstyle '" .. tostring(active) .. "'; falling back to " .. tostring(fallback))
        end
        return fallback
    end
    return active
end

local HEALING_PLAYSTYLES = {
    holy = true,
    discipline = true,
    restoration = true,
    resto = true,
}

local function contains_any(value, needles)
    if type(value) ~= "string" then return false end
    for i = 1, #needles do
        if value:find(needles[i], 1, true) then return true end
    end
    return false
end

local HEALING_NAMES = {
    "heal", "renew", "mending", "lifebloom", "rejuvenation", "regrowth",
    "powerwordshield", "pws", "circleofhealing", "prayerofhealing",
    "bindingheal", "holyshock", "layonhands", "earthshield", "smartgroupheal",
    "smartheal", "naturesswiftness", "tranquility", "divineillumination",
}

local DAMAGE_NAMES = {
    "idle", "smite", "shadowwordpain", "holyfire", "mindblast",
    "shadowworddeath", "mindflay", "judgement", "crusaderstrike",
    "consecration", "execute", "mortalstrike", "whirlwind", "bloodthirst",
    "fireball", "frostbolt", "arcane", "scorch", "shadowbolt",
}

local COOLDOWN_NAMES = {
    "avengingwrath", "combustion", "icyveins", "arcanepower", "rapidfire",
    "bestialwrath", "bloodfury", "berserking", "innervate", "shadowfiend",
    "innerfocus", "sweepingstrikes", "recklessness", "deathwish",
    "bladeflurry", "adrenalinerush", "bloodlust", "shamanisticrage", "powerinfusion", "berserker", "trinket",
}

local UTILITY_NAMES = {
    "interrupt", "kick", "pummel", "counterspell", "spelllock", "silence",
    "cleanse", "dispel", "purify", "cure", "fade", "feign", "vanish",
    "evasion", "sprint", "cower", "righteousfury", "battletrance",
    "battleshout", "commandingshout", "watershield", "shadowform",
    "bearform", "catform", "moonkinform", "stance", "thunderclap",
    "demoshout", "demoralizing", "sunder", "faeriefire", "soulshatter", "soulstone",
}

local DEFENSIVE_NAMES = {
    "shieldblock", "barkskin", "iceblock", "manashield", "divineshield",
    "frenziedregeneration", "shieldwall", "laststand", "holyshield",
}

local function strategy_category(strategy, list_name, active)
    if type(strategy) ~= "table" then return "damage" end
    if type(strategy.category) == "string" then return strategy.category end
    -- Per-playstyle cache: category is stable for the same active playstyle.
    -- Eliminates ~3160 string.find calls/frame after first evaluation per playstyle.
    local cat_cache = strategy._cat_cache
    if active and cat_cache and cat_cache[active] then return cat_cache[active] end
    if active and not cat_cache then cat_cache = {}; strategy._cat_cache = cat_cache end

    local name = tostring(strategy.name or ""):lower():gsub("%s+", "")

    local cat
    if contains_any(name, HEALING_NAMES) then cat = "healing"
    elseif contains_any(name, DEFENSIVE_NAMES) then cat = "utility"
    elseif strategy.is_burst or contains_any(name, COOLDOWN_NAMES) then cat = "cooldown"
    elseif contains_any(name, UTILITY_NAMES) then cat = "utility"
    elseif list_name == "middleware" then cat = "utility"
    elseif HEALING_PLAYSTYLES[tostring(active or ""):lower()] then
        if contains_any(name, DAMAGE_NAMES) then cat = "damage"
        else cat = "healing" end
    else cat = "damage"
    end

    if active then cat_cache[active] = cat end
    return cat
end

local function strategy_allowed(strategy, list_name, active, context)
    local category = strategy_category(strategy, list_name, active)
    local is_healer = HEALING_PLAYSTYLES[tostring(active or ""):lower()] == true

    if is_healer and category == "damage" then return false, "healer_damage_blocked", category end
    if not spec_kit.setting_bool(context, "utility_enabled", true) and category == "utility" then return false, "utility_disabled", category end
    if not spec_kit.setting_bool(context, "healing_enabled", true) and (category == "healing" or (is_healer and category == "cooldown")) then return false, "healing_disabled", category end
    if not spec_kit.setting_bool(context, "damage_enabled", true) and (category == "damage" or (category == "cooldown" and not is_healer)) then return false, "damage_disabled", category end
    if not spec_kit.setting_bool(context, "use_cooldowns", true) and category == "cooldown" and not context.should_burst then return false, "cooldowns_disabled", category end
    return true, "allowed", category
end

local function run_list(name, list, options, context)
    if type(list) ~= "table" then
        return false
    end
    local state = context
    if options and options.get_state then
        state = safe(options.get_state, context) or context
    end
    if options and options.context_builder then
        state = safe(options.context_builder, context) or context
    end
    for i = 1, #list do
        local strategy = list[i]
        if type(strategy) == "table" then
            local allowed = strategy_allowed(strategy, name, context.active_playstyle, context)
            if not allowed then
            elseif type(strategy.execute) ~= "function" then
                NS.log_warning(name .. " Strategy '" .. tostring(strategy.name or i) .. "' Is Missing An Execute Action")
            else
                local ok = true
                if type(strategy.matches) == "function" then
                    local ok_match, match_result = pcall(strategy.matches, context, state)
                    if not ok_match then
                        NS.log_warning(name .. " matches error in '" .. tostring(strategy.name or i) .. "': " .. tostring(match_result))
                        ok = false
                    else
                        ok = match_result == true
                    end
                end
                if ok then
                    local ok_exec, exec_result = pcall(strategy.execute, context, state)
                    if not ok_exec then
                        NS.log_warning(name .. " execute error in '" .. tostring(strategy.name or i) .. "': " .. tostring(exec_result))
                    end
                    local executed = ok_exec and exec_result == true
                    local _now_trace = _api.time_now()
                    -- BUGFIX (2026-06-29): two-tier trace throttle.
                    --   1. Per-list throttle (existing, 2s budget per list)
                    --      keeps the per-list output stream alive so other
                    --      strategies in the same list still show up.
                    --   2. NEW per-strategy throttle (30s budget per
                    --      ``list:strategy_name`` pair) suppresses the
                    --      AutoConsumable ``matched=true, executed=false``
                    --      spam when the executor is a no-op (no items in
                    --      bags, no setting enabled, HP/mana not in
                    --      threshold).  Worked-example: with auto-consume
                    --      on but no consumables in bags, the manager used
                    --      to spam 1 trace line every ~3s; now it's
                    --      suppressed for 30s after the first miss.
                    --   3. When the executor DID fire (executed=true) we
                    --      force-log immediately — single trace per real
                    --      cast is the most-useful information for the user.
                    local _tt_key = name or "default"
                    local _strat_key = (name or "default") .. ":" .. tostring(strategy.name or ("idx_" .. i))
                    local _strat_last = _trace_strategy_last[_strat_key] or 0
                    local _strat_loggable = executed
                        or (_now_trace - _strat_last) > TRACE_PER_STRATEGY_TTL
                    local _list_loggable = (_now_trace - (_trace_strat_last[_tt_key] or 0)) > 2
                    if _strat_loggable and _list_loggable then
                        _trace_strat_last[_tt_key] = _now_trace
                        _trace_strategy_last[_strat_key] = _now_trace
                    end
                    if executed then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function M.on_rotation_update()
    local _tick_start = tick_profiler and tick_profiler.begin_tick() or nil
    local context = build_context()
    if not context then
        return false
    end
    if context.in_combat and aft and aft.on_update then pcall(aft.on_update, context) end
    -- Get class_key early so we can run middleware for OOC utilities even in pure no-target non-leveling cases.
    local registry = NS.rotation_registry
    local config = registry and registry.class_config or nil
    local class_key = config and config.class_key
    if not (context.in_combat or context.has_valid_enemy_target or context.target) then
        if ooc_manager and ooc_manager.on_update and safe(ooc_manager.on_update, context) then
            return true
        end
        if not context.is_leveling then
            if run_list("middleware", class_key and NS.class_middleware[class_key], nil, context) then
                return true
            end
            return false
        end
    end
    if context.on_gcd and context.in_combat and context.is_casting then
        return true
    end
    -- Optimization: skip strategy evaluation while player is casting or channeling.
    -- The evaluate_cast guard in try_cast already blocks re-casts, but this early exit
    -- prevents running the entire strategy match/execute loop (saves CPU every frame
    -- during cast-time spells and prevents OOC buff spam like Aspect of the Hawk).
    if context.is_casting or context.is_channeling then
        return true
    end
    if reaction_delay_active(context) then
        return true
    end
    local registry = NS.rotation_registry
    local config = registry and registry.class_config or nil
    -- Prefer injected context.settings (from quick toggles widget) so playstyle changes
    -- in the UI take effect immediately. Fall back to NS.get_setting for persisted values.
    local requested_playstyle = nil
    if context and context.settings then
        requested_playstyle = context.settings.playstyle or context.settings.active_playstyle
    end
    if requested_playstyle == nil and NS.get_setting then
        requested_playstyle = NS.get_setting("playstyle", nil)
    end
    -- v2.5.1: treat "auto" as no-preference (delegate to talent inference)
    if requested_playstyle == "auto" then requested_playstyle = nil end
    local active_source = (type(requested_playstyle) == "string" and requested_playstyle ~= "") and requested_playstyle
        or (NS.get_setting and NS.get_setting("active_playstyle", config and config.default_playstyle) or (config and config.default_playstyle))
    local active = normalize_playstyle(registry, active_source)
    local auto_detected = false
    if (not requested_playstyle or requested_playstyle == "") and (context.is_leveling or context.is_solo) and registry and registry.playstyles and registry.playstyles.leveling then
        active = "leveling"
        auto_detected = true
    end
    -- Talent-based spec auto-detection (when no manual playstyle selected, not leveling/solo)
    if not auto_detected and (not requested_playstyle or requested_playstyle == "") and config and config.class_key then
        local TI = NS.TalentInference
        if TI and TI.infer_cached then
            local inferred = TI.infer_cached(config.class_key)
            if inferred and inferred.primary_tree and registry and registry.playstyles and registry.playstyles[inferred.primary_tree] then
                active = inferred.primary_tree
                auto_detected = true
            end
        end
    end
    context.active_playstyle = active
    log_expansion_once(config, active)
    local class_key = config and config.class_key

    -- Pet manager update (hunter + warlock + mage): runs every frame to keep pet
    -- attacking target and casting pet abilities (Growl, Claw, Bite, Imp Firebolt,
    -- Water Elemental Freeze, etc.).
    if (class_key == "hunter" or class_key == "warlock" or class_key == "mage") and context.me and pet_manager and pet_manager.on_update then
        pet_manager.on_update(context.me, context.target, active, context)
    end

    if run_list("middleware", class_key and NS.class_middleware[class_key], nil, context) then
        return true
    end
    local fired = run_list(tostring(active), registry and registry.playstyles[active], registry and registry.options[active], context)
    -- v1.0: Auto-loot corpses (background service, never blocks rotation)
    if NS.auto_loot and NS.auto_loot.on_tick then
        pcall(NS.auto_loot.on_tick, context)
    end
    -- Swing timer offset/haste tracking for hunter_adaptive + melee consumers
    if NS.SwingTimer and type(NS.SwingTimer.on_update) == "function" then
        pcall(NS.SwingTimer.on_update)
    end
    if _tick_start and tick_profiler then tick_profiler.end_tick(_tick_start) end
    return fired
end

--[[
Unified dispatcher — available for classes that migrate to NS.register_strategy().
Combines middleware + playstyle strategies into a single priority-ordered dispatch list
registered via NS.register_strategy(). Uses NS.run_unified_strategies() instead of
the legacy two-loop run_list() approach.

Class middleware is still executed FIRST (via run_list) so existing class_middleware
files continue to work. As classes migrate middleware entries to register_strategy(),
that pre-flight will naturally become a no-op.
]]
function M.on_rotation_update_unified()
    local _tick_start = tick_profiler and tick_profiler.begin_tick() or nil
    local context = build_context()
    if not context then
        return false
    end
    if context.in_combat and aft and aft.on_update then pcall(aft.on_update, context) end
    -- Get class_key early so we can run middleware for OOC utilities even in pure no-target non-leveling cases.
    local registry = NS.rotation_registry
    local config = registry and registry.class_config or nil
    local class_key = config and config.class_key
    if not (context.in_combat or context.has_valid_enemy_target or context.target) then
        if ooc_manager and ooc_manager.on_update and safe(ooc_manager.on_update, context) then
            return true
        end
        if not context.is_leveling then
            if run_list("middleware", class_key and NS.class_middleware[class_key], nil, context) then
                return true
            end
            return false
        end
    end
    if context.on_gcd and context.in_combat and context.is_casting then
        return true
    end
    if reaction_delay_active(context) then
        return true
    end
    local registry = NS.rotation_registry
    local config = registry and registry.class_config or nil
    -- Prefer injected context.settings (from quick toggles widget) so playstyle changes
    -- in the UI take effect immediately. Fall back to NS.get_setting for persisted values.
    local requested_playstyle = nil
    if context and context.settings then
        requested_playstyle = context.settings.playstyle or context.settings.active_playstyle
    end
    if requested_playstyle == nil and NS.get_setting then
        requested_playstyle = NS.get_setting("playstyle", nil)
    end
    -- v2.5.1: treat "auto" as no-preference (delegate to talent inference)
    if requested_playstyle == "auto" then requested_playstyle = nil end
    local active_source = (type(requested_playstyle) == "string" and requested_playstyle ~= "") and requested_playstyle
        or (NS.get_setting and NS.get_setting("active_playstyle", config and config.default_playstyle) or (config and config.default_playstyle))
    local active = normalize_playstyle(registry, active_source)
    local auto_detected = false
    if (not requested_playstyle or requested_playstyle == "") and (context.is_leveling or context.is_solo) and registry and registry.playstyles and registry.playstyles.leveling then
        active = "leveling"
        auto_detected = true
    end
    -- Talent-based spec auto-detection (when no manual playstyle selected, not leveling/solo)
    if not auto_detected and (not requested_playstyle or requested_playstyle == "") and config and config.class_key then
        local TI = NS.TalentInference
        if TI and TI.infer_cached then
            local inferred = TI.infer_cached(config.class_key)
            if inferred and inferred.primary_tree and registry and registry.playstyles and registry.playstyles[inferred.primary_tree] then
                active = inferred.primary_tree
                auto_detected = true
            end
        end
    end
    context.active_playstyle = active
    log_expansion_once(config, active)
    local class_key = config and config.class_key

    -- Pet manager update (hunter + warlock + mage): runs every frame to keep pet
    -- attacking target and casting pet abilities (Growl, Claw, Bite, Imp Firebolt,
    -- Water Elemental Freeze, etc.).
    if (class_key == "hunter" or class_key == "warlock" or class_key == "mage") and context.me and pet_manager and pet_manager.on_update then
        pet_manager.on_update(context.me, context.target, active, context)
    end

    if run_list("middleware", class_key and NS.class_middleware[class_key], nil, context) then
        return true
    end
    local fired = NS.run_unified_strategies(context)
    -- v1.0: Auto-loot corpses (background service, never blocks rotation)
    if NS.auto_loot and NS.auto_loot.on_tick then
        pcall(NS.auto_loot.on_tick, context)
    end
    -- Swing timer offset/haste tracking for hunter_adaptive + melee consumers
    if NS.SwingTimer and type(NS.SwingTimer.on_update) == "function" then
        pcall(NS.SwingTimer.on_update)
    end
    if _tick_start and tick_profiler then tick_profiler.end_tick(_tick_start) end
    return fired
end

NS.on_rotation_update = M.on_rotation_update
NS.on_rotation_update_unified = M.on_rotation_update_unified
-- rotation dispatcher initialized

return M

-- update dispatcher for class middleware and selected playstyle strategies.
local NS = _G.EaxRotations
if not NS then return nil end

local M = {}
local _context = {}
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
local _burst_ok, BurstLogic = pcall(require, "shared/burst_logic_sylvanas")
if not _burst_ok or type(BurstLogic) ~= "table" then BurstLogic = { should_auto_burst = function() return nil end } end
local _forecast_gate_ok = pcall(require, "shared/combat_forecast_gate_sylvanas")
if not _forecast_gate_ok and not NS.should_use_long_cd then NS.should_use_long_cd = function() return true end end
local _combat_forecast_ok, combat_forecast = pcall(require, "common/modules/combat_forecast")
if not _combat_forecast_ok or type(combat_forecast) ~= "table" then combat_forecast = nil end
-- Platform-provided target selector: pre-filtered enemy and heal target lists
local _target_selector_ok, target_selector = pcall(require, "common/modules/target_selector")
if not _target_selector_ok or type(target_selector) ~= "table" then target_selector = nil end
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
local _tick_profiler_ok, tick_profiler = pcall(require, "shared/tick_profiler_sylvanas")
if not _tick_profiler_ok then tick_profiler = nil end
-- PvP trinket tracker: self-registers NS.PvPTrinket + spell cast + update callbacks
pcall(require, "shared/pvp_trinket_tracker_sylvanas")
local _buff_db_ok, buffs = pcall(require, "common/buff_db")
if not _buff_db_ok or type(buffs) ~= "table" then buffs = {} end
local BLOODLUST_IDS = buffs.BLOODLUST or { 2825, 32182 }
local DRUMS_IDS = buffs.DRUMS or { 35475, 35474, 35473, 35476 }

-- PvP context field constants (cc_target, cc_safe, fear_nearby, enemy_healer, melee_on_you)
local FEAR_IDS = { 6215, 6213, 5782, 8122, 8124, 10888, 10890, 5484, 17928 }  -- Fear, Psychic Scream, Howl of Terror
local HEALER_CLASS_IDS = { [5]=true, [2]=true, [11]=true, [7]=true }  -- Priest, Paladin, Druid, Shaman
local MELEE_CLASS_IDS = { [1]=true, [4]=true, [2]=true, [7]=true, [11]=true }  -- Warrior, Rogue, Paladin, Shaman, Druid

-- Spell queue module is loaded here so the dispatcher knows it is available.
-- Actual queueing happens inside NS.try_cast() in core_sylvanas.lua.
local _spell_queue_ok, spell_queue_module = pcall(require, "common/modules/spell_queue")
if not _spell_queue_ok or type(spell_queue_module) ~= "table" then spell_queue_module = nil end

-- Expose for strategy access; nil if unavailable.
NS.spell_queue = spell_queue_module

local _last_error_time = 0

-- Hot-path NS API references cached at module load to avoid table lookups and pcall overhead per frame.
-- Safe to cache: these are stable functions set during NS initialization (see core_sylvanas.lua).
-- DO NOT cache APIs that may not exist at load time (optional modules loaded via pcall).
local _time_now = NS.time_now
local _game_time_ms = NS.game_time_ms
local _unit_health_pct = NS.unit_health_pct
local _mana_pct = NS.mana_pct
local _power_current = NS.power_current
local _buff_up = NS.buff_up
local _debuff_remains = NS.debuff_remains
local _debuff_up = NS.debuff_up
local _unit_alive = NS.unit_alive
local _get_party_members = NS.GetPartyMembers
local _get_focus = NS.GetFocus
local _get_pet = NS.GetPet
local _get_player_stance = NS.get_player_stance
local _is_hostile_unit = NS.is_hostile_unit
local _is_pvp_zone = NS.is_pvp_zone
local _is_in_party = NS.is_in_party
local _player_control_locked = NS.player_control_locked
local _has_breakable_cc_nearby = NS.has_breakable_cc_nearby
local _get_debuff_stacks = NS.get_debuff_stacks
local _same_unit = NS.same_unit
local _gcd_remains = NS.gcd_remains
local _get_setting = NS.get_setting

local _get_expansion_max_level = NS.get_expansion_max_level
local _get_player = NS.GetPlayer

local _cached_tank_alive, _cached_tank_alive_time = true, -1

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
    local now = core.time and core.time() or 0
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
    local delay_ms = (NS.get_setting and NS.get_setting("reaction_delay_ms", 0)) or 0
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
        _reaction_delay_start = (NS.time_now and NS.time_now()) or 0
        _reaction_was_on_gcd = false
    end
    if not _reaction_delay_start then return false end
    -- Check if we're still within the delay window
    local now = (NS.time_now and NS.time_now()) or 0
    local elapsed_ms = (now - _reaction_delay_start) * 1000
    if elapsed_ms < delay_ms then return true end
    -- Delay expired, allow rotation
    _reaction_delay_start = nil
    return false
end

local function get_target(me)
    local fallback_get_target = NS.safe_field and NS.safe_field(me, "get_target") or nil
    return NS.GetTarget and NS.GetTarget() or (fallback_get_target and fast(fallback_get_target, me) or nil)
end

local function valid_enemy(me, target)
    return NS.is_hostile_unit and NS.is_hostile_unit(me, target) or false
end

local function find_enemy_target(me, selected)
    -- Always accept the player's manually selected target (even neutral/yellow NPCs).
    -- The player explicitly chose to attack it. Hostility check is only for auto-acquisition.
    if selected then
        return selected
    end
    -- During manual target grace period, skip all fallbacks — respect the player's choice
    if NS.time_now() < _manual_target_lockout_until then
        return nil
    end
    -- IZI-selected target fallback (for scripts that use the IZI target helper)
    local izi_target = NS.izi and NS.izi.target and NS.izi.target()
    if izi_target then
        local izi_ok = valid_enemy(me, izi_target)
        if izi_ok then return izi_target end
    end
    local focus = NS.GetFocus and NS.GetFocus() or nil
    local focus_ok = valid_enemy(me, focus)
    if focus_ok then return focus end
    return nil  -- Never auto-acquire enemies without a valid target
end

local _cached_enemies, _cached_enemies_time = nil, -1
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
    -- Al'ar (TK) — removed: not actually fire immune in TBC
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

-- ============================================================================
-- Auto-AoE Toggle Logic
-- ============================================================================
local function get_auto_aoe_threshold()
    local threshold = NS.get_setting and NS.get_setting("auto_aoe_threshold", 3)
    return type(threshold) == "number" and threshold or 3
end

local function auto_aoe_enabled()
    return NS.get_setting and NS.get_setting("auto_aoe_enabled", true) or true
end

local function auto_aoe_should_trigger(enemy_count)
    if not auto_aoe_enabled() then return false end
    local threshold = get_auto_aoe_threshold()
    return enemy_count >= threshold
end

local function resolve_auto_aoe_playstyle(registry, active, enemy_count)
    if not registry or not registry.playstyles then return active end
    local now = NS.time_now and NS.time_now() or 0
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
    local now = NS.time_now and NS.time_now() or 0
    local ok, result = pcall(ttd_tracker.update, target, now, settings)
    if ok and type(result) == "number" and result > 0 then return result end
    return nil
end

local function get_ema_ttd(target)
    if not ttd_ema or not target then return nil end
    local now = NS.time_now and NS.time_now() or 0
    local ok = pcall(ttd_ema.update, target, now)
    if not ok then return nil end
    local ttd = ttd_ema.get_ttd(target, now)
    return type(ttd) == "number" and ttd > 0 and ttd or nil
end

local function unit_bool(unit, ...)
    if not unit or not NS.safe_field then return false end
    for i = 1, select("#", ...) do
        local fn = NS.safe_field(unit, select(i, ...))
        if fn and fast(fn, unit) == true then return true end
    end
    return false
end

local function unit_number(unit, field)
    if not unit or not NS.safe_field then return nil end
    local fn = NS.safe_field(unit, field)
    local value = fn and fast(fn, unit) or nil
    return type(value) == "number" and value or nil
end

local function core_string(field)
    local fn = core and core[field]
    local value = type(fn) == "function" and fast(fn) or nil
    return type(value) == "string" and value or nil
end

local function build_context()
    for k in pairs(_context) do _context[k] = nil end
    local me = _get_player()
    if not me then
        NS.current_context = nil
        return nil
    end
    local selected_target = get_target(me)
    -- Detect manual target change: if GUID differs from last frame, start 3s grace period
    if selected_target then
        local current_guid = nil
        local get_guid = NS.safe_field and NS.safe_field(selected_target, "get_guid") or nil
        if get_guid then
            local ok, guid = pcall(get_guid, selected_target)
            if ok then current_guid = guid end
        end
        if current_guid and _last_target_guid and current_guid ~= _last_target_guid then
            _manual_target_lockout_until = (NS.time_now and NS.time_now() or 0) + 3.0
        end
        _last_target_guid = current_guid
    else
        _last_target_guid = nil
    end
    local target = find_enemy_target(me, selected_target)
    local is_in_combat = NS.safe_field and NS.safe_field(me, "is_in_combat") or nil
    local raw_in_combat = is_in_combat and fast(is_in_combat, me) or nil
    local combat_state_known = type(raw_in_combat) == "boolean"
    local in_combat
    if combat_state_known then
        in_combat = raw_in_combat
        was_in_combat = in_combat
        _combat_state_last_known = NS.time_now()
    else
        -- Decay: if API has been returning nil for > 1s, assume out of combat
        if was_in_combat and NS.time_now() - _combat_state_last_known > 1.0 then
            was_in_combat = false
        end
        in_combat = was_in_combat
    end

    if not _combat_start_time and me and in_combat then _combat_start_time = NS.time_now() end
    if _combat_start_time and me and combat_state_known and not in_combat then _combat_start_time = nil end
    local enemy_ok = valid_enemy(me, target)
    local _enemies_cache = throttled_enemies()
    local count = (_enemies_cache and _enemies_cache.n) or (_enemies_cache and #_enemies_cache) or 0
    local engine_ttd = enemy_ok and target_time_to_die(target) or nil
    local instance_type = tostring(core_string("get_instance_type") or "none"):lower()
    local player_level = unit_number(me, "get_effective_level") or unit_number(me, "get_level") or 70
    local target_level = target and (unit_number(target, "get_effective_level") or unit_number(target, "get_level")) or nil
    local target_classification = target and unit_number(target, "get_classification") or nil
    local expansion_max_level = _get_expansion_max_level and _get_expansion_max_level() or 70
    -- Compute boss/elite flag locally before _context is fully populated
    local is_target_boss = target and NS.safe_field and NS.safe_field(target, "is_boss") and fast(target.is_boss, target) == true or false
    -- ============================================================================
    -- TTD (Time-To-Death) Fallback Chain
    -- ============================================================================
    -- The system resolves a single TTD value through a priority fallback chain:
    --
    --   1st: EMA TTD (ttd_ema_tracker_sylvanas.lua)
    --        - Combat-log-driven exponential moving average of incoming DPS.
    --        - Available ~1.5-3s after first damage event (requires 2+ hits + 1.5s elapsed).
    --        - Most reliable: adapts to real-time combat log data.
    --        - Returns nil when: no combat log data, target not valid, or insufficient samples.
    --
    --   2nd: Regression TTD (ttd_tracker_sylvanas.lua — linear regression)
    --        - Uses HP/time samples to project a straight-line TTD.
    --        - ONLY attempted when: EMA is nil AND target is boss, or targets above player level.
    --        - More stable than engine TTD but slower to converge (needs multiple HP readings).
    --        - Skipped for non-boss targets at or below player level — regression needs sustained
    --          HP/time samples to converge.
    --
    --   3rd: Engine TTD (target:time_to_die() or target:get_time_to_death())
    --        - Provided by the game client/PS framework.
    --        - Last resort: often returns nil or unreliable values on private servers.
    --        - When this fires, it means neither EMA nor regression had data.
    --
    --   4th (implicit): nil
    --        - No TTD source could provide a value.
    --        - _context.ttd defaults to 999 (\"infinite\"), _context.ttd_known is false.
    --
    -- _context.ttd_known == false when:
    --   - No valid enemy target (target is nil or friendly).
    --   - All three TTD sources returned nil (early combat, OOC, insufficient data).
    --   - The target lacks health or incoming damage data entirely.
    --
    -- Downstream consumers: always check context.ttd_known before using context.ttd.
    -- Strategies with require_ttd=true will be skipped when ttd_known is false
    -- (see NS.action_execute() in core_sylvanas.lua).
    -- ============================================================================
    local ema_ttd = nil
    local regression_ttd = nil
    if in_combat and enemy_ok then
        ema_ttd = get_ema_ttd(target)
        if not ema_ttd and (is_target_boss or (target_level and target_level > player_level)) then
            regression_ttd = get_linear_regression_ttd(target, NS.settings)
        end
    end
    -- Resolve TTD from the fallback chain: EMA → regression → engine → nil
    local ttd_source = "none"
    local ttd = nil
    if ema_ttd then
        ttd = ema_ttd
        ttd_source = "ema"
    elseif regression_ttd then
        ttd = regression_ttd
        ttd_source = "regression"
    elseif engine_ttd then
        ttd = engine_ttd
        ttd_source = "engine"
    end
    _context.me = me
    _context.target = target
    _context.target_casting = target and (unit_bool(target, "is_casting") or unit_bool(target, "is_channeling") or false) or false
    _context.target_ttd = ttd
    _context.has_aggro = (target and me) and (function()
        local get_threat = NS.safe_field and NS.safe_field(target, "get_threat_situation")
        if not get_threat then return false end
        local ok, result = pcall(get_threat, target, me)
        return ok and type(result) == "number" and result >= 2
    end)() or false
    _context.in_combat = in_combat
    _context.combat_state_known = combat_state_known
    _context.has_target = target ~= nil
    _context.has_valid_enemy_target = enemy_ok
    _context.target_hp = enemy_ok and _unit_health_pct(target) or 100
    _context.player_level = player_level
    _context.level = player_level
    _context.expansion_max_level = expansion_max_level
    _context.is_leveling = player_level < expansion_max_level
    _context.target_level = target_level
    _context.target_level_delta = target_level and (target_level - player_level) or 0
    _context.target_classification = target_classification
    _context.hp = _unit_health_pct(me)
    _context.player_hp = _context.hp
    _context.mana_pct = _mana_pct(me)
    _context.player_mana = _context.mana_pct
    _context.player_mana_pct = _context.mana_pct
    _context.gcd_remains = _gcd_remains and _gcd_remains() or 0
    _context.on_gcd = (_context.gcd_remains or 0) > 0
    _context.combat_time = _combat_start_time and (_time_now() - _combat_start_time) or 0
    _context.rage = _power_current(NS.POWER_RAGE)
    _context.player_rage = _context.rage
    _context.energy = _power_current(NS.POWER_ENERGY)
    _context.player_energy = _context.energy
    _context.focus = _power_current(NS.POWER_FOCUS)
    -- Attack power for cat druid AP snapshotting (falls back to 0 if unit method unavailable)
    _context.attack_power = unit_number(me, "get_attack_power") or 0
    -- Spell crit chance for paladin Illumination mana-return calculations.
    -- Expected as percentage (0-100); consumer divides by 100. Falls back to 0 if API unavailable.
    _context.crit_chance = unit_number(me, "get_spell_crit_chance") or 0
    -- Target armor for sunder/faerie fire value assessment
    _context.target_armor = unit_number(target, "get_armor") or 0
    _context.bloodlust_active = me and _buff_up(me, BLOODLUST_IDS) or false
    _context.drums_active = me and _buff_up(me, DRUMS_IDS) or false
    _context.should_burst = BurstLogic.should_auto_burst(_context, {
        is_bloodlust_active = function() return _context.bloodlust_active end,
        is_drums_active = function() return _context.drums_active end,
    })
    _context.burst_reason = _context.should_burst and "burst_conditions_met" or nil
    -- target_distance uses get_distance when available, otherwise falls back to melee range check
    _context.in_melee_range = target and target.is_in_melee_range and target:is_in_melee_range(5) or false
    local dist_ok, dist_val = pcall(function() return target and NS.safe_field(target, "get_distance") and target:get_distance(me) end)
    _context.target_range = (dist_ok and type(dist_val) == "number") and dist_val or (_context.in_melee_range and 5 or 40)
    _context.target_distance = _context.target_range
    _context.combo_points = combo_points(me)
    _context.enemy_count = count
    _context.enemies_count = count
    local now_pet = NS.game_time_ms and NS.game_time_ms() or 0
    if now_pet - _pet_cache_timestamp > 500 then
        _pet_cache_data = _get_pet and _get_pet()
        _pet_cache_timestamp = now_pet
    end
    _context.pet = _pet_cache_data
    _context.pet_dead = _pet_cache and not _pet_cache:is_alive() or false
    _context.stance = _get_player_stance() or 0
    _context.player_class = NS.player_class_id
    _context.has_totems = _context.in_combat
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
        _context.is_pvp = _is_pvp_zone and _is_pvp_zone() or false
    end
    _context.instance_type = instance_type
    _context.is_dungeon = instance_type == "party"
    _context.is_raid = instance_type == "raid"
    _context.is_arena = instance_type == "arena"
    _context.is_battleground = instance_type == "pvp"
    _context.is_group = _context.is_dungeon or _context.is_raid or (_is_in_party and _is_in_party() or false)
    _context.is_solo = not _context.is_group
    -- Cache GetPartyMembers() once per frame for all downstream consumers
    local _party_members = nil
    if _context.is_group then
        _party_members = NS.GetPartyMembers and NS.GetPartyMembers() or nil
    end
    _context.party = _party_members
    _context.party_members = _party_members
    _context.group_members = _party_members
    _context.party_count = (_party_members and #_party_members) or 0
    -- Combined party scan: tank_alive, group_injured, fear_nearby in a single ipairs pass.
    -- Replaces 3 separate loops (was: tank_alive 568-612, group_injured 679-690, fear_nearby 715-729).
    -- tank_alive detection is throttled to 500ms; other flags are per-frame but early-exit on first match.
    local tank_alive = _cached_tank_alive
    _context.group_injured = false
    _context.fear_nearby = false
    if _context.is_group then
        local now = NS.game_time_ms and NS.game_time_ms() or 0
        local refresh_tank = now - _cached_tank_alive_time > 500
        if refresh_tank then
            tank_alive = true
            _cached_tank_alive_time = now
        end
        local party = _party_members
        if party then
            for _, u in ipairs(party) do
                if u then
                    local alive = _unit_alive(u)
                    if not alive then
                        if refresh_tank and tank_alive then
                            local is_tank = false
                            if health_prediction and type(health_prediction.is_tank) == "function" then
                                local ok, result = pcall(health_prediction.is_tank, health_prediction, u)
                                if ok and result then is_tank = true end
                            else
                                local ok, result = pcall(function() return u.is_tank and u:is_tank() end)
                                if ok and result then is_tank = true end
                            end
                            if is_tank then tank_alive = false end
                        end
                    else
                        if not _context.group_injured and _unit_health_pct(u) < 90 then
                            _context.group_injured = true
                        end
                    end
                end
            end
        end
        -- fear_nearby: check party members for fear debuffs (PvP-specific)
        if _context.is_pvp then
            local party2 = _party_members
            if party2 then
                for _, u in ipairs(party2) do
                    if u and _unit_alive(u) and _debuff_up(u, FEAR_IDS) then
                        _context.fear_nearby = true
                        break
                    end
                end
            end
            if not _context.fear_nearby and me and _debuff_up(me, FEAR_IDS) then
                _context.fear_nearby = true
            end
        end
    end
    _cached_tank_alive = tank_alive
    _context.tank_alive = tank_alive
    _context.lowest_unit = nil
    _context.lowest_hp = 100
    _context.lowest = { unit = nil, hp = 100 }
    _context.lowest_ally_hp = 100
    _context.lowest_group_hp = 100
    if _context.is_group and _party_members then
        local lowest_val, lowest_unit = 100, nil
        for _, u in ipairs(_party_members) do
            if u and _unit_alive(u) then
                local hp = _unit_health_pct(u)
                if hp and hp < lowest_val then
                    lowest_val = hp
                    lowest_unit = u
                end
            end
        end
        _context.lowest_unit = lowest_unit
        _context.lowest_hp = lowest_val
        _context.lowest = { unit = lowest_unit, hp = lowest_val }
        _context.lowest_ally_hp = lowest_val
        _context.lowest_group_hp = lowest_val
    end
    _context.settings = NS.settings or {}
    _context.ttd = ttd or 999
    _context.ttd_source = ttd_source
    _context.has_breakable_cc_nearby = _has_breakable_cc_nearby and _has_breakable_cc_nearby() or false
    -- Boss school immunities for strategy gating
    local school_immunities = get_target_school_immunities(target)
    _context.target_arcane_immune = school_immunities.arcane == true
    _context.target_nature_immune = school_immunities.nature == true
    _context.target_fire_immune = school_immunities.fire == true
    _context.target_frost_immune = school_immunities.frost == true
    _context.target_shadow_immune = school_immunities.shadow == true
    _context.target_holy_immune = school_immunities.holy == true
    _context.target_is_player = target and NS.safe_field and NS.safe_field(target, "is_player") and fast(target.is_player, target) == true or false
    _context.target_is_boss = is_target_boss
    -- ============================================================================
    -- Derived context fields (for specs that consume nil-unsafe guards)
    -- ============================================================================
    -- Threat percentage (0-100) for threat-sensitive specs (rogue, warlock, shaman)
    if target and me then
        local ok_ts, ts = pcall(function() return target:get_threat_situation() end)
        local ts_num = (ok_ts and type(ts) == "number") and ts or 0
        -- Threat zones: 0=none, 1=low, 2=medium, 3=aggro; scale to 0-100%
        _context.threat_pct = (ts_num / 3) * 100
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
        _context.has_sunder = _debuff_remains and _debuff_remains(target, { 7386, 7405, 8380, 11596, 11597, 25225 }) > 0 or false
    end
    -- AoE damage incoming (enemy count > 1 as proxy for cleave/AoE packs)
    _context.aoe_damage_incoming = count > 1
    -- Is this a raid boss? (worldboss=3 classification or target_is_boss)
    _context.is_raid_boss = is_target_boss or (target_classification and target_classification >= 3) or false
    -- Fire mage: Improved Scorch maintenance (Scorch debuff = spell ID 22959)
    _context.scorch_stacks = 0
    _context.scorch_remains = 0
    if target then
        _context.scorch_stacks = _get_debuff_stacks and _get_debuff_stacks(target, { 22959 }) or 0
        _context.scorch_remains = _debuff_remains and _debuff_remains(target, { 22959 }) or 0
    end
    -- Enemy array for spec-level iteration (frost mage Cone of Cold, prot pally CC checks)
    _context.enemies = _enemies_cache or {}
    -- Legacy aliases for paladin specs that use alternative field names
    _context.enemy_list = _context.enemies
    _context.targets = _context.enemies
    -- PvP: CC target for Polymorph (mage specs) — uses focus target when valid
    _context.cc_target = nil
    if _context.is_pvp and target then
        local focus = _get_focus and _get_focus() or nil
        if focus and _unit_alive(focus) and valid_enemy(me, focus) and not _same_unit(focus, target) then
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
                if e and _unit_alive(e) and _debuff_up(e, NS.CC_DEBUFFS) then
                    _context.cc_safe = false
                    break
                end
            end
        end
    end
    -- PvP: Enemy healer detection for curse selection (warlock specs)
    _context.enemy_healer = false
    if _context.is_pvp and target and NS.safe_field then
        local get_class = NS.safe_field and NS.safe_field(target, "get_class")
        local class_id = get_class and fast(get_class, target) or nil
        if class_id and HEALER_CLASS_IDS[class_id] then
            _context.enemy_healer = true
        end
    end
    -- PvP: Melee enemy targeting player for defensive curse/Howl (warlock specs)
    _context.melee_on_you = false
    if _context.is_pvp and target and me and NS.safe_field then
        local enemies = _enemies_cache
        if type(enemies) == "table" then
            local n = enemies.n or #enemies
            for i = 1, n do
                local e = enemies[i]
                if e and _unit_alive(e) then
                    local get_class = NS.safe_field and NS.safe_field(e, "get_class")
                    local class_id = get_class and fast(get_class, e) or nil
                    if class_id and MELEE_CLASS_IDS[class_id] then
                        local get_target_fn = NS.safe_field(e, "get_target")
                        if get_target_fn then
                            local ok, e_target = pcall(get_target_fn, e)
                            if ok and e_target and _same_unit(e_target, me) then
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
    _context.is_mounted = me and NS.safe_field and NS.safe_field(me, "is_mounted") and fast(me.is_mounted, me) == true or false
    -- Is player control locked? (fear, charm, mind control — stop casting/gcd)
    _context.player_control_locked = _player_control_locked and _player_control_locked() or false
    if combat_forecast and type(combat_forecast.get_forecast_single) == "function" then
        local ok, forecast = pcall(combat_forecast.get_forecast_single, target)
        if ok and type(forecast) == "number" and forecast > 0 then
            _context.combat_length_forecast = forecast
        else
            _context.combat_length_forecast = _context.ttd or 999
        end
    else
        _context.combat_length_forecast = _context.ttd or 999
    end
    _context.ttd_known = ttd ~= nil
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
    _context.now = NS.time_now()
    NS.current_context = _context
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
        if NS.set_setting then NS.set_setting("active_playstyle", fallback) end
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
    "smartheal", "naturesswiftness",
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
    "bladeflurry", "adrenalinerush", "bloodlust", "shamanisticrage",
}

local UTILITY_NAMES = {
    "interrupt", "kick", "pummel", "counterspell", "spelllock", "silence",
    "cleanse", "dispel", "purify", "cure", "fade", "feign", "vanish",
    "evasion", "sprint", "cower", "righteousfury", "battletrance",
    "battleshout", "commandingshout", "watershield", "shadowform",
    "bearform", "catform", "moonkinform", "stance", "thunderclap",
    "demoshout", "demoralizing", "sunder", "faeriefire",
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
    local settings = context.settings or {}
    local category = strategy_category(strategy, list_name, active)
    local is_healer = HEALING_PLAYSTYLES[tostring(active or ""):lower()] == true

    if is_healer and category == "damage" then return false, "healer_damage_blocked", category end
    if settings.utility_enabled == false and category == "utility" then return false, "utility_disabled", category end
    if settings.healing_enabled == false and (category == "healing" or (is_healer and category == "cooldown")) then return false, "healing_disabled", category end
    if settings.damage_enabled == false and (category == "damage" or (category == "cooldown" and not is_healer)) then return false, "damage_disabled", category end
    if settings.use_cooldowns == false and category == "cooldown" and not context.should_burst then return false, "cooldowns_disabled", category end
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
                if type(strategy.matches) == "function" then ok = strategy.matches(context, state) == true end
                if ok then
                    local executed = fast(strategy.execute, context, state) == true
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
    if not (context.in_combat or context.has_valid_enemy_target or context.target) then
        -- OOC: try OOC manager (handles class buff refresh, pet summon, food/flask)
        if ooc_manager and ooc_manager.on_update and safe(ooc_manager.on_update, context) then
            return true
        end
        -- OOC with no target and OOC manager has nothing to do: skip expensive
        -- playstyle rotation evaluation. Strategies need a target to do damage.
        return false
    end
    -- GCD gate: while on global cooldown in combat, skip strategy evaluation entirely.
    -- No spell can be cast during GCD; evaluating 20-40 strategies is wasted CPU.
    -- OOC manager (lines 969-974) still fires — GCD gate only applies after OOC check.
    if context.on_gcd and context.in_combat then
        return true
    end
    -- Global reaction delay: blocks ALL middleware + playstyle strategies for reaction_delay_ms after GCD ends.
    -- Applies to all 9 classes. Bypassed during burst windows and out of combat.
    if reaction_delay_active(context) then
        return true
    end
    local registry = NS.rotation_registry
    local config = registry and registry.class_config or nil
    local requested_playstyle = NS.get_setting("playstyle", nil)
    local active_source = (type(requested_playstyle) == "string" and requested_playstyle ~= "") and requested_playstyle
        or NS.get_setting("active_playstyle", config and config.default_playstyle)
    local active = normalize_playstyle(registry, active_source)
    local auto_detected = false
    if (not requested_playstyle or requested_playstyle == "") and (context.is_leveling or context.is_solo) and registry and registry.playstyles and registry.playstyles.leveling then
        active = "leveling"
        auto_detected = true
    end
    active = resolve_auto_aoe_playstyle(registry, active, context.enemy_count or 0)
    if not auto_detected and NS.set_setting and active ~= NS.get_setting("active_playstyle", nil) then
        NS.set_setting("active_playstyle", active)
    end
    context.active_playstyle = active
    log_expansion_once(config, active)
    local class_key = config and config.class_key
    if run_list("middleware", class_key and NS.class_middleware[class_key], nil, context) then
        return true
    end
    local fired = run_list(tostring(active), registry and registry.playstyles[active], registry and registry.options[active], context)
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
    if not (context.in_combat or context.has_valid_enemy_target or context.target) then
        -- OOC: try OOC manager (handles class buff refresh, pet summon, food/flask)
        if ooc_manager and ooc_manager.on_update and safe(ooc_manager.on_update, context) then
            return true
        end
        -- Fall through to the playstyle rotation so OOC strategies
        -- (WeaponImbue, LightningShield, WaterShield, GhostWolf, etc.) get a
        -- chance to fire. Their matches() functions gate on state.in_combat ==
        -- false, so they naturally no-op in combat. In OOC they cover what the
        -- shared OOC manager doesn't: e.g., a level-1 Shaman has no Lightning
        -- Shield or Water Shield entry the manager can refresh, but the leveling
        -- playstyle's WeaponImbue strategy still applies RockbiterWeapon.
        -- Bug fix: previously this branch returned false unconditionally when
        -- the OOC manager had nothing to do, which meant a solo low-level
        -- character sitting in a starter zone would never see the playstyle
        -- rotation execute anything.
    end
    if context.on_gcd and context.in_combat then
        return true
    end
    -- Global reaction delay: blocks ALL middleware + playstyle strategies.
    if reaction_delay_active(context) then
        return true
    end
    local registry = NS.rotation_registry
    local config = registry and registry.class_config or nil
    local requested_playstyle = NS.get_setting("playstyle", nil)
    local active_source = (type(requested_playstyle) == "string" and requested_playstyle ~= "") and requested_playstyle
        or NS.get_setting("active_playstyle", config and config.default_playstyle)
    local active = normalize_playstyle(registry, active_source)
    local auto_detected = false
    if (not requested_playstyle or requested_playstyle == "") and (context.is_leveling or context.is_solo) and registry and registry.playstyles and registry.playstyles.leveling then
        active = "leveling"
        auto_detected = true
    end
    active = resolve_auto_aoe_playstyle(registry, active, context.enemy_count or 0)
    if not auto_detected and NS.set_setting and active ~= NS.get_setting("active_playstyle", nil) then
        NS.set_setting("active_playstyle", active)
    end
    context.active_playstyle = active
    log_expansion_once(config, active)
    local class_key = config and config.class_key
    -- Run legacy class middleware first; new unified entries are in NS.unified_registry
    if run_list("middleware", class_key and NS.class_middleware[class_key], nil, context) then
        return true
    end
    local fired = NS.run_unified_strategies(context)
    if _tick_start and tick_profiler then tick_profiler.end_tick(_tick_start) end
    return fired
end

NS.on_rotation_update = M.on_rotation_update
NS.on_rotation_update_unified = M.on_rotation_update_unified
NS.log("Rotation dispatcher loaded")

return M

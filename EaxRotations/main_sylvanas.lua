-- update dispatcher for class middleware and selected playstyle strategies.
local NS = _G.EaxRotations
if not NS then return nil end

local M = {}
local _context = {}
local _combat_start_time = nil
local was_in_combat = false
local _ooc_ok, ooc_manager = pcall(require, "shared/ooc_manager_sylvanas")
if not _ooc_ok then ooc_manager = nil end
local _burst_ok, BurstLogic = pcall(require, "shared/burst_logic_sylvanas")
if not _burst_ok or type(BurstLogic) ~= "table" then BurstLogic = { should_auto_burst = function() return nil end } end
local _forecast_gate_ok = pcall(require, "shared/combat_forecast_gate_sylvanas")
if not _forecast_gate_ok and not NS.should_use_long_cd then NS.should_use_long_cd = function() return true end end
local _combat_forecast_ok, combat_forecast = pcall(require, "common/modules/combat_forecast")
if not _combat_forecast_ok or type(combat_forecast) ~= "table" then combat_forecast = nil end
local _ttd_tracker_ok, ttd_tracker = pcall(require, "shared/ttd_tracker_sylvanas")
if not _ttd_tracker_ok or type(ttd_tracker) ~= "table" then ttd_tracker = nil end
local _ttd_ema_ok, ttd_ema = pcall(require, "shared/ttd_ema_tracker_sylvanas")
if not _ttd_ema_ok or type(ttd_ema) ~= "table" then ttd_ema = nil end
local _buff_db_ok, buffs = pcall(require, "common/buff_db")
if not _buff_db_ok or type(buffs) ~= "table" then buffs = {} end
local BLOODLUST_IDS = buffs.BLOODLUST or { 2825, 32182 }
local DRUMS_IDS = buffs.DRUMS or { 35475, 35474, 35473, 35476 }

-- Spell queue module is loaded here so the dispatcher knows it is available.
-- Actual queueing happens inside NS.try_cast() in core_sylvanas.lua.
local _spell_queue_ok, spell_queue_module = pcall(require, "common/modules/spell_queue")
if not _spell_queue_ok or type(spell_queue_module) ~= "table" then spell_queue_module = nil end

-- Expose for strategy access; nil if unavailable.
NS.spell_queue = spell_queue_module

local _last_error_time = 0
local _trace_times = {}

local _cached_tank_alive, _cached_tank_alive_time = true, -1

-- ============================================================================
-- Auto-AoE Toggle State
-- ============================================================================
local _auto_aoe_last_enemy_count = 0
local _auto_aoe_state_changed_at = nil
local _auto_aoe_base_playstyle = nil

-- ============================================================================
-- Force Flag State (slash-command overrides)
-- ============================================================================
local _force_flags = {
    burst = { active = false, expires = 0 },
    defensive = { active = false, expires = 0 },
    gap = { active = false, expires = 0 },}

local FORCE_FLAG_TIMEOUT = 3.0

local function trace(key, message, interval_ms)
    if not NS.get_setting("debug_system", false) then return end
    local now = NS.game_time_ms and NS.game_time_ms() or 0
    local interval = interval_ms or 500
    local last = _trace_times[key] or -100000
    if now - last < interval then return end
    _trace_times[key] = now
    NS.log("[ROTDBG] " .. tostring(message))
end

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a = pcall(fn, ...)
    if ok then return a end
    local now = core.time and core.time() or 0
    if now - _last_error_time > 2 then
        _last_error_time = now
        NS.log("rotation callback warning: " .. tostring(a))
    end
    return nil
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
    return NS.GetTarget and NS.GetTarget() or (fallback_get_target and safe(fallback_get_target, me) or nil)
end

local function update_force_flags()
    local now = NS.time_now and NS.time_now() or 0
    for _, flag in pairs(_force_flags) do
        if flag.active and now > flag.expires then
            flag.active = false
        end
    end
end

local function set_force_flag(flag_name)
    local now = NS.time_now and NS.time_now() or 0
    if _force_flags[flag_name] then
        _force_flags[flag_name].active = true
        _force_flags[flag_name].expires = now + FORCE_FLAG_TIMEOUT
    end
end

function NS.force_burst_active()
    update_force_flags()
    return _force_flags.burst.active
end

function NS.force_defensive_active()
    update_force_flags()
    return _force_flags.defensive.active
end

function NS.force_gap_active()
    update_force_flags()
    return _force_flags.gap.active
end

function NS.set_force_burst()
    if NS.get_setting and not NS.get_setting("force_burst_enabled", true) then
        NS.log("Force burst disabled in settings")
        return
    end
    set_force_flag("burst")
    NS.log("Force burst active for " .. tostring(FORCE_FLAG_TIMEOUT) .. "s")
end

function NS.set_force_defensive()
    if NS.get_setting and not NS.get_setting("force_defensive_enabled", true) then
        NS.log("Force defensive disabled in settings")
        return
    end
    set_force_flag("defensive")
    NS.log("Force defensive active for " .. tostring(FORCE_FLAG_TIMEOUT) .. "s")
end

function NS.set_force_gap()
    if NS.get_setting and not NS.get_setting("force_gap_enabled", true) then
        NS.log("Force gap disabled in settings")
        return
    end
    set_force_flag("gap")
    NS.log("Force gap active for " .. tostring(FORCE_FLAG_TIMEOUT) .. "s")
end

local function valid_enemy(me, target)
    return NS.is_hostile_unit and NS.is_hostile_unit(me, target) or false
end

local function find_enemy_target(me, selected)
    local selected_ok = valid_enemy(me, selected)
    trace("target:selected", "[EaxRotations:target] selected=" .. tostring(selected ~= nil) .. " valid=" .. tostring(selected_ok), 2000)
    if selected_ok then
        trace("target:selected_ok", "target selected=valid_enemy", 1000)
        return selected
    end
    -- IZI-selected target fallback (for scripts that use the IZI target helper)
    if not selected then
        local izi_target = NS.izi and NS.izi.target and NS.izi.target()
        if izi_target then
            local izi_ok = valid_enemy(me, izi_target)
            trace("target:izi", "[EaxRotations:target] izi_target=" .. tostring(izi_target ~= nil) .. " valid=" .. tostring(izi_ok), 2000)
            if izi_ok then return izi_target end
        end
    end
    local focus = NS.GetFocus and NS.GetFocus() or nil
    local focus_ok = valid_enemy(me, focus)
    trace("target:focus", "[EaxRotations:target] focus=" .. tostring(focus ~= nil) .. " valid=" .. tostring(focus_ok), 2000)
    trace("target:pick", "target pick selected=" .. tostring(selected ~= nil) .. " selected_ok=" .. tostring(selected_ok) .. " focus=" .. tostring(focus ~= nil) .. " focus_ok=" .. tostring(focus_ok), 2000)
    if focus_ok then return focus end
    trace("target:no_valid", "[EaxRotations:target] NO VALID TARGET - selected invalid, focus invalid or missing", 2000)
    return nil  -- Never auto-acquire enemies; only cast on selected or focus target
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
        _cached_enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(40) or nil
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
    local v = combo_points_current and safe(combo_points_current, me) or nil
    local get_power = NS.safe_field and NS.safe_field(me, "get_power") or nil
    if type(v) ~= "number" and get_power then v = safe(get_power, me, 4) end
    return type(v) == "number" and v or 0
end

local function target_time_to_die(target)
    local time_to_die = NS.safe_field and (NS.safe_field(target, "time_to_die") or NS.safe_field(target, "get_time_to_death")) or nil
    local value = time_to_die and safe(time_to_die, target) or nil
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
        if fn and safe(fn, unit) == true then return true end
    end
    return false
end

local function unit_number(unit, field)
    if not unit or not NS.safe_field then return nil end
    local fn = NS.safe_field(unit, field)
    local value = fn and safe(fn, unit) or nil
    return type(value) == "number" and value or nil
end

local function core_string(field)
    local fn = core and core[field]
    local value = type(fn) == "function" and safe(fn) or nil
    return type(value) == "string" and value or nil
end

local function build_context()
    for k in pairs(_context) do _context[k] = nil end
    local me = NS.GetPlayer()
    if not me then
        trace("context:no_player", "build_context failed: no player", 1000)
        NS.current_context = nil
        return nil
    end
    local selected_target = get_target(me)
    local target = find_enemy_target(me, selected_target)
    local is_in_combat = NS.safe_field and NS.safe_field(me, "is_in_combat") or nil
    local raw_in_combat = is_in_combat and safe(is_in_combat, me) or nil
    local combat_state_known = type(raw_in_combat) == "boolean"
    local in_combat = combat_state_known and raw_in_combat or was_in_combat
    
    -- Combat start/end detection for callbacks
    if combat_state_known then
        if in_combat and not was_in_combat then
            -- Combat started
            if NS._fire_combat_start then NS._fire_combat_start(_context) end
        elseif not in_combat and was_in_combat then
            -- Combat ended
            if NS._fire_combat_end then NS._fire_combat_end(_context) end
        end
        was_in_combat = in_combat
    end
    
    if not _combat_start_time and me and in_combat then _combat_start_time = NS.time_now() end
    if _combat_start_time and me and combat_state_known and not in_combat then _combat_start_time = nil end
    local enemy_ok = valid_enemy(me, target)
    local count = throttled_enemies_count()
    local engine_ttd = enemy_ok and target_time_to_die(target) or nil
    local instance_type = tostring(core_string("get_instance_type") or "none"):lower()
    local player_level = unit_number(me, "get_effective_level") or unit_number(me, "get_level") or 70
    local target_level = target and (unit_number(target, "get_effective_level") or unit_number(target, "get_level")) or nil
    local target_classification = target and unit_number(target, "get_classification") or nil
    local expansion_max_level = NS.get_expansion_max_level and NS.get_expansion_max_level() or 70
    -- Compute boss/elite flag locally before _context is fully populated
    local is_target_boss = target and NS.safe_field and NS.safe_field(target, "is_boss") and safe(target.is_boss, target) == true or false
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
    --        - _context.ttd defaults to 999 ("infinite"), _context.ttd_known is false.
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
    local ema_ttd = enemy_ok and get_ema_ttd(target) or nil
    local regression_ttd = nil
    if enemy_ok and not ema_ttd and (is_target_boss or (target_level and target_level > player_level)) then
        regression_ttd = get_linear_regression_ttd(target, NS.settings)
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
    trace("ttd:source", "[TTD] source=" .. ttd_source .. " value=" .. tostring(ttd) .. " ema=" .. tostring(ema_ttd) .. " reg=" .. tostring(regression_ttd) .. " eng=" .. tostring(engine_ttd), 2000)
    _context.me = me
    _context.target = target
    _context.in_combat = in_combat
    _context.combat_state_known = combat_state_known
    _context.has_target = target ~= nil
    _context.has_valid_enemy_target = enemy_ok
    _context.target_hp = enemy_ok and NS.unit_health_pct(target) or 100
    _context.player_level = player_level
    _context.level = player_level
    _context.expansion_max_level = expansion_max_level
    _context.is_leveling = player_level < expansion_max_level
    _context.target_level = target_level
    _context.target_level_delta = target_level and (target_level - player_level) or 0
    _context.target_classification = target_classification
    _context.hp = NS.unit_health_pct(me)
    _context.player_hp = _context.hp
    _context.mana_pct = NS.mana_pct(me)
    _context.player_mana = _context.mana_pct
    _context.player_mana_pct = _context.mana_pct
    _context.gcd_remains = NS.gcd_remains and NS.gcd_remains() or 0
    _context.on_gcd = (_context.gcd_remains or 0) > 0
    _context.combat_time = _combat_start_time and (NS.time_now() - _combat_start_time) or 0
    _context.rage = NS.power_current(NS.POWER_RAGE)
    _context.player_rage = _context.rage
    _context.energy = NS.power_current(NS.POWER_ENERGY)
    _context.player_energy = _context.energy
    _context.focus = NS.power_current(NS.POWER_FOCUS)
    _context.bloodlust_active = me and NS.buff_up(me, BLOODLUST_IDS) or false
    _context.drums_active = me and NS.buff_up(me, DRUMS_IDS) or false
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
    _context.stance = NS.get_player_stance()
    _context.is_moving = unit_bool(me, "is_moving")
    _context.is_casting = unit_bool(me, "is_casting", "is_casting_spell")
    _context.is_channeling = unit_bool(me, "is_channeling", "is_channelling_spell")
    if not _context.is_casting and not _context.is_channeling then
        _context.is_channeling = unit_bool(me, "is_channeling_or_casting")
    end
    _context.is_pvp = NS.is_pvp_zone and NS.is_pvp_zone() or false
    _context.instance_type = instance_type
    _context.is_dungeon = instance_type == "party"
    _context.is_raid = instance_type == "raid"
    _context.is_arena = instance_type == "arena"
    _context.is_battleground = instance_type == "pvp"
    _context.is_group = _context.is_dungeon or _context.is_raid or (NS.is_in_party and NS.is_in_party() or false)
    _context.is_solo = not _context.is_group
    -- Tank-alive detection for Rebirth safety gating (throttled to 500ms)
    local tank_alive = _cached_tank_alive
    if _context.is_group then
        local now = NS.game_time_ms and NS.game_time_ms() or 0
        if now - _cached_tank_alive_time > 500 then
            tank_alive = true
            local party = NS.GetPartyMembers and NS.GetPartyMembers() or nil
            if party then
                for _, u in ipairs(party) do
                    if u then
                        local ok, is_tank = pcall(function() return u.is_tank and u:is_tank() end)
                        if ok and is_tank then
                            local ok2, alive = pcall(function() return u.is_alive and u:is_alive() end)
                            if ok2 and not alive then
                                tank_alive = false
                                break
                            end
                        end
                    end
                end
            end
            _cached_tank_alive = tank_alive
            _cached_tank_alive_time = now
        end
    end
    _context.tank_alive = tank_alive
    _context.settings = NS.settings or {}
    _context.ttd = ttd or 999
    _context.ttd_source = ttd_source
    _context.force_burst = NS.force_burst_active and NS.force_burst_active() or false
    _context.force_defensive = NS.force_defensive_active and NS.force_defensive_active() or false
    _context.force_gap = NS.force_gap_active and NS.force_gap_active() or false
    _context.has_breakable_cc_nearby = NS.has_breakable_cc_nearby and NS.has_breakable_cc_nearby() or false
    -- Boss school immunities for strategy gating
    local school_immunities = get_target_school_immunities(target)
    _context.target_arcane_immune = school_immunities.arcane == true
    _context.target_nature_immune = school_immunities.nature == true
    _context.target_fire_immune = school_immunities.fire == true
    _context.target_frost_immune = school_immunities.frost == true
    _context.target_shadow_immune = school_immunities.shadow == true
    _context.target_holy_immune = school_immunities.holy == true
    _context.target_is_player = target and NS.safe_field and NS.safe_field(target, "is_player") and safe(target.is_player, target) == true or false
    _context.target_is_boss = is_target_boss
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
    NS.current_context = _context
    trace("context:summary",
        "ctx raw_combat=" .. tostring(raw_in_combat) ..
        " known=" .. tostring(combat_state_known) ..
        " in_combat=" .. tostring(in_combat) ..
        " selected=" .. tostring(selected_target ~= nil) ..
        " target=" .. tostring(target ~= nil) ..
        " enemy_ok=" .. tostring(enemy_ok) ..
        " enemies=" .. tostring(count) ..
        " hp=" .. tostring(_context.hp) ..
        " mana=" .. tostring(_context.mana_pct) ..
        " gcd=" .. tostring(_context.gcd_remains) ..
        " moving=" .. tostring(_context.is_moving) ..
        " casting=" .. tostring(_context.is_casting) ..
        " channeling=" .. tostring(_context.is_channeling),
        2000)
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

local last_trace_ms = -10000
local function trace_no_action(active, context, reason)
    if not NS.get_setting or not (NS.get_setting("debug_system", false) or NS.get_setting("log_context", false)) then return end
    local now = NS.game_time_ms and NS.game_time_ms() or 0
    if now - last_trace_ms < 1000 then return end
    last_trace_ms = now
    local gates = NS.explain_context_gates and NS.explain_context_gates(context) or "context=?"
    NS.log("[TRACE] no action active=" .. tostring(active) .. " reason=" .. tostring(reason or "none") .. " " .. gates)
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
    local name = tostring(strategy.name or ""):lower():gsub("%s+", "")

    if contains_any(name, HEALING_NAMES) then return "healing" end
    if contains_any(name, DEFENSIVE_NAMES) then return "utility" end
    if strategy.is_burst or contains_any(name, COOLDOWN_NAMES) then return "cooldown" end
    if contains_any(name, UTILITY_NAMES) then return "utility" end
    if list_name == "middleware" then return "utility" end
    if HEALING_PLAYSTYLES[tostring(active or ""):lower()] then
        if contains_any(name, DAMAGE_NAMES) then return "damage" end
        return "healing"
    end

    return "damage"
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
        trace("list:" .. tostring(name) .. ":missing", "list " .. tostring(name) .. " missing type=" .. type(list), 1000)
        return false
    end
    trace("list:" .. tostring(name) .. ":start", "list " .. tostring(name) .. " start count=" .. tostring(#list), 2000)
    local state = context
    if options and options.get_state then
        state = safe(options.get_state, context) or context
        trace("list:" .. tostring(name) .. ":state", "list " .. tostring(name) .. " get_state returned " .. tostring(state ~= context and state ~= nil), 1000)
    end
    if options and options.context_builder then
        state = safe(options.context_builder, context) or context
        trace("list:" .. tostring(name) .. ":builder", "list " .. tostring(name) .. " context_builder returned " .. tostring(state ~= context and state ~= nil), 1000)
    end
    for i = 1, #list do
        local strategy = list[i]
        if type(strategy) == "table" then
            local sname = tostring(strategy.name or i)
            local allowed, allow_reason, category = strategy_allowed(strategy, name, context.active_playstyle, context)
            if not allowed then
                trace("strategy:" .. tostring(name) .. ":" .. sname .. ":blocked", "strategy " .. tostring(name) .. "[" .. tostring(i) .. "] " .. sname .. " blocked category=" .. tostring(category) .. " reason=" .. tostring(allow_reason), 2000)
            elseif type(strategy.execute) ~= "function" then
                NS.log_warning(name .. " strategy " .. tostring(strategy.name or i) .. " missing execute")
            else
                local ok = true
                if type(strategy.matches) == "function" then ok = safe(strategy.matches, context, state) == true end
                trace("strategy:" .. tostring(name) .. ":" .. sname .. ":match", "strategy " .. tostring(name) .. "[" .. tostring(i) .. "] " .. sname .. " category=" .. tostring(category) .. " match=" .. tostring(ok), 2000)
                if ok then
                    local executed = safe(strategy.execute, context, state) == true
                    trace("strategy:" .. tostring(name) .. ":" .. sname .. ":exec", "strategy " .. tostring(name) .. "[" .. tostring(i) .. "] " .. sname .. " execute=" .. tostring(executed), 2000)
                    if executed then
                        trace("strategy:" .. tostring(name) .. ":" .. tostring(sname) .. ":fired", "[EaxRotations:strategy] FIRED: " .. tostring(name) .. "[" .. tostring(i) .. "] " .. sname, 2000)
                        return true
                    else
                        trace("strategy:" .. tostring(name) .. ":" .. tostring(sname) .. ":failed", "[EaxRotations:strategy] MATCHED but execute FAILED: " .. tostring(name) .. "[" .. tostring(i) .. "] " .. sname, 2000)
                    end
                end
            end
        else
            trace("strategy:" .. tostring(name) .. ":" .. tostring(i) .. ":bad", "strategy " .. tostring(name) .. "[" .. tostring(i) .. "] invalid type=" .. type(strategy), 1000)
        end
    end
    trace("list:" .. tostring(name) .. ":none", "list " .. tostring(name) .. " finished without action", 2000)
    trace("strategy:" .. tostring(name) .. ":no_fires", "[EaxRotations:strategy] " .. tostring(name) .. " list finished - NO strategies fired (checked " .. tostring(#list) .. " entries)", 2000)
    return false
end

function M.on_rotation_update()
    local context = build_context()
    if not context then
        trace("update:no_context", "[EaxRotations:update] EXIT: build_context returned nil - no player object?", 2000)
        trace("update:no_context", "on_rotation_update stop: no context", 1000)
        return false
    end
    trace("update:vars", "[EaxRotations:update] in_combat=" .. tostring(context.in_combat) .. " has_valid_enemy_target=" .. tostring(context.has_valid_enemy_target) .. " combat_state_known=" .. tostring(context.combat_state_known) .. " hp=" .. tostring(context.hp) .. " gcd=" .. tostring(context.gcd_remains) .. " level=" .. tostring(context.player_level) .. " is_leveling=" .. tostring(context.is_leveling), 2000)
    if not (context.in_combat or context.has_valid_enemy_target) then
        trace("gate:blocked", "[EaxRotations:gate] BLOCKED: not in_combat AND no valid enemy target. combat_state_known=" .. tostring(context.combat_state_known) .. " has_target=" .. tostring(context.has_target), 2000)
        -- Only run OOC manager when there's no valid enemy target (even if combat_state_known is false)
        trace("gate:ooc_path", "[EaxRotations:gate] EXIT: OOC path - in_combat=false, has_enemy=false, trying ooc_manager=" .. tostring(ooc_manager ~= nil), 2000)
        trace("gate:ooc", "gate OOC: in_combat=false has_enemy=false ooc_manager=" .. tostring(ooc_manager ~= nil), 2000)
        if ooc_manager and ooc_manager.on_update and safe(ooc_manager.on_update, context) then
            trace("gate:ooc_fired", "[EaxRotations:gate] OOC manager fired successfully", 2000)
            trace("gate:ooc_fired", "OOC manager executed", 500)
            return true
        end
        trace_no_action("none", context, "idle_no_enemy")
        return false
    end
    -- Global reaction delay: blocks ALL middleware + playstyle strategies for reaction_delay_ms after GCD ends.
    -- Applies to all 9 classes. Bypassed during burst windows and out of combat.
    if reaction_delay_active(context) then
        trace("gate:reaction_delay", "[EaxRotations:gate] REACTION DELAY active - blocking all strategies", 1000)
        return true
    end
    local registry = NS.rotation_registry
    local config = registry and registry.class_config or nil
    trace("registry:summary", "registry config=" .. tostring(config ~= nil) .. " class_key=" .. tostring(config and config.class_key) .. " playstyles=" .. tostring(registry and registry.playstyles ~= nil), 1000)
    local requested_playstyle = NS.get_setting("playstyle", nil)
    local active_source = (type(requested_playstyle) == "string" and requested_playstyle ~= "") and requested_playstyle
        or NS.get_setting("active_playstyle", config and config.default_playstyle)
    local active = normalize_playstyle(registry, active_source)
    -- Auto-detect leveling/solo context: switch to leveling playstyle when no explicit playstyle is set
    if (not requested_playstyle or requested_playstyle == "") and (context.is_leveling or context.is_solo) and registry and registry.playstyles and registry.playstyles.leveling then
        active = "leveling"
        trace("playstyle:auto_leveling", "auto-detected leveling/solo context, switching to leveling playstyle", 500)
    end
    -- Dynamic Auto-AoE: automatically switch to AoE playstyle when enemy_count >= threshold
    active = resolve_auto_aoe_playstyle(registry, active, context.enemy_count or 0)
    if NS.set_setting and active ~= NS.get_setting("active_playstyle", nil) then
        NS.set_setting("active_playstyle", active)
    end
    context.active_playstyle = active
    trace("playstyle:active", "playstyle requested=" .. tostring(requested_playstyle) .. " source=" .. tostring(active_source) .. " active=" .. tostring(active), 2000)
    log_expansion_once(config, active)
    local class_key = config and config.class_key
    if run_list("middleware", class_key and NS.class_middleware[class_key], nil, context) then
        trace("update:middleware_fired", "on_rotation_update fired middleware class_key=" .. tostring(class_key), 2000)
        trace("update:middleware_fired", "[EaxRotations:update] MIDDLEWARE FIRED - BLOCKING playstyle rotation. class_key=" .. tostring(class_key) .. " active=" .. tostring(active), 2000)
        return true
    end
    trace("update:running_playstyle", "[EaxRotations:update] running playstyle=" .. tostring(active) .. " list_count=" .. tostring(registry and registry.playstyles and registry.playstyles[active] and #registry.playstyles[active] or 0) .. " options=" .. tostring(registry and registry.options and registry.options[active] ~= nil), 2000)
    local fired = run_list(tostring(active), registry and registry.playstyles[active], registry and registry.options[active], context)
    trace("update:done", "on_rotation_update finished active=" .. tostring(active) .. " fired=" .. tostring(fired), 2000)
    if fired then
        trace("update:playstyle_fired", "[EaxRotations:update] playstyle=" .. tostring(active) .. " FIRED a strategy", 2000)
    else
        trace("update:playstyle_idle", "[EaxRotations:update] playstyle=" .. tostring(active) .. " finished WITHOUT firing any strategy", 2000)
        trace_no_action(active, context, "strategies_blocked")
    end
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
    local context = build_context()
    if not context then
        trace("unified:no_context", "on_rotation_update_unified stop: no context", 1000)
        return false
    end
    if not (context.in_combat or context.has_valid_enemy_target) then
        if context.combat_state_known == false then
            trace("unified:combat_pending", "unified gate stop: combat_state_pending target=" .. tostring(context.has_valid_enemy_target), 500)
            trace_no_action("none", context, "combat_state_pending")
            return false
        end
        -- Only run OOC manager when there's no valid enemy target
        trace("unified:ooc", "unified gate OOC: in_combat=false has_enemy=false ooc_manager=" .. tostring(ooc_manager ~= nil), 500)
        if ooc_manager and ooc_manager.on_update and safe(ooc_manager.on_update, context) then
            trace("unified:ooc_fired", "unified OOC manager executed", 500)
            return true
        end
        trace_no_action("none", context, "idle_no_enemy")
        return false
    end
    -- Global reaction delay: blocks ALL middleware + playstyle strategies.
    if reaction_delay_active(context) then
        trace("unified:reaction_delay", "[EaxRotations:unified] REACTION DELAY active - blocking all strategies", 500)
        return true
    end
    local registry = NS.rotation_registry
    local config = registry and registry.class_config or nil
    local requested_playstyle = NS.get_setting("playstyle", nil)
    local active_source = (type(requested_playstyle) == "string" and requested_playstyle ~= "") and requested_playstyle
        or NS.get_setting("active_playstyle", config and config.default_playstyle)
    local active = normalize_playstyle(registry, active_source)
    -- Auto-detect leveling/solo context: switch to leveling playstyle when no explicit playstyle is set
    if (not requested_playstyle or requested_playstyle == "") and (context.is_leveling or context.is_solo) and registry and registry.playstyles and registry.playstyles.leveling then
        active = "leveling"
        trace("unified:auto_leveling", "auto-detected leveling/solo context, switching to leveling playstyle", 500)
    end
    -- Dynamic Auto-AoE: automatically switch to AoE playstyle when enemy_count >= threshold
    active = resolve_auto_aoe_playstyle(registry, active, context.enemy_count or 0)
    if NS.set_setting and active ~= NS.get_setting("active_playstyle", nil) then
        NS.set_setting("active_playstyle", active)
    end
    context.active_playstyle = active
    trace("unified:playstyle", "unified playstyle requested=" .. tostring(requested_playstyle) .. " source=" .. tostring(active_source) .. " active=" .. tostring(active), 500)
    log_expansion_once(config, active)
    local class_key = config and config.class_key
    -- Run legacy class middleware first; new unified entries are in NS.unified_registry
    if run_list("middleware", class_key and NS.class_middleware[class_key], nil, context) then
        trace("unified:middleware_fired", "on_rotation_update_unified fired middleware class_key=" .. tostring(class_key), 500)
        return true
    end
    local fired = NS.run_unified_strategies(context)
    trace("unified:done", "on_rotation_update_unified finished active=" .. tostring(active) .. " fired=" .. tostring(fired), 500)
    if not fired then trace_no_action(active, context, "unified_strategies_blocked") end
    return fired
end

NS.on_rotation_update = M.on_rotation_update
NS.on_rotation_update_unified = M.on_rotation_update_unified
NS.log("Rotation dispatcher loaded")

return M

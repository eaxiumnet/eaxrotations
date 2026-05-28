-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/healer_engine_sylvanas.lua"
local __eax_version = "1.1.1"
local __eax_modified = "2026-05-27"
local __eax_change = "File version stamp for runtime load verification"
local __eax_versions = rawget(_G, "EaxRotationsFileVersions") or {}
_G.EaxRotationsFileVersions = __eax_versions
__eax_versions[__eax_file] = { version = __eax_version, modified = __eax_modified, change = __eax_change }
local __eax_core = rawget(_G, "core")
if type(__eax_core) == "table" and type(__eax_core.log) == "function" then
    pcall(__eax_core.log, "[EaxRotations] Loaded " .. __eax_file .. " v" .. __eax_version)
end
local __eax_ns = rawget(_G, "EaxRotations")
if type(__eax_ns) == "table" then __eax_ns.file_versions = __eax_versions end
-- ============================================================================
-- DEPRECATED: This module is no longer loaded by the framework.
--   Healer logic has been inlined into class-specific helpers (resto, holy,
--   discipline) and core_sylvanas.lua (NS.healing_get_tank, NS.build_healing_entries).
--   Kept for backward compatibility with external test files only.
--   Do not add new production consumers.
-- ============================================================================
-- What: Shared healer engine for stop-cast, pre-heal, and target scoring (deprecated)
-- When: Per tick during healing decisions
-- Why: Reduce overheal and choose better heal targets
-- Safety: Throttled cancel checks, nil-guarded targets, and conservative thresholds
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations
local _core_time = core and core.time
local om = core and core.object_manager or {}
local _get_local_player = om.get_local_player
local _get_enemies = om.get_enemy_list
local _get_party = om.get_party_frames

local function unit_is_live(unit)
    if not unit then return false end
    local ok_valid, is_valid = pcall(function()
        if unit.is_valid then return unit:is_valid() end
        return true
    end)
    if not ok_valid or is_valid == false then return false end

    local ok_alive, is_alive = pcall(function()
        if unit.is_alive then return unit:is_alive() end
        return true
    end)
    return ok_alive and is_alive ~= false
end

local function unit_health_pct(unit)
    if not unit then return nil end
    local ok, hp = pcall(function()
        if unit.get_health_percentage then return unit:get_health_percentage() end
        return nil
    end)
    return ok and type(hp) == "number" and hp or nil
end

local function unit_distance_from(me, unit)
    if not me or not unit then return nil end
    local ok, dist = pcall(function()
        if me.get_distance then return me:get_distance(unit) end
        return nil
    end)
    return ok and type(dist) == "number" and dist or nil
end

-- ============================================================================
-- Internal state
-- ============================================================================

local _stopcast = {
    checkpoints = {},  -- { pct = 30, id = 1 }, { pct = 50, id = 2 }, ...
    last_cancel = 0,
}

local _preheal = {
    active = false,
    target_guid = nil,
    spell_id = nil,
    start_time = 0,
}

local _target_cache = {
    last_build = 0,
    units = {},
}

-- ============================================================================
-- Stop-cast engine
-- ============================================================================

--- Configures stop-cast checkpoints
---@param checkpoints table Array of { pct: number, id: number } — progress % to cancel
function M.configure_stopcast(checkpoints)
    _stopcast.checkpoints = checkpoints or {}
end

--- Checks if current heal cast should be cancelled (target recovered enough)
---@param target game_object The heal target
---@param cast_start_time number Time the cast started (core.time())
---@param cast_duration number Cast duration in seconds
---@param heal_threshold number HP % above which to consider cancelling (default 85)
---@return boolean cancel True if cast should be cancelled
function M.check_stopcast(target, cast_start_time, cast_duration, heal_threshold)
    if not target then return false end
    if not cast_start_time or not cast_duration then return false end
    if type(cast_duration) ~= "number" or cast_duration <= 0 then return false end
    if not heal_threshold then heal_threshold = 85 end

    local now = _core_time()
    local progress = (now - cast_start_time) / cast_duration

    -- Only check between 30% and 80% cast progress
    if progress < 0.3 or progress > 0.8 then return false end

    -- Throttle cancel checks to every 100ms
    if now - _stopcast.last_cancel < 0.1 then return false end

    -- Check if target HP recovered above threshold
    local hp = unit_health_pct(target)
    if not hp or hp < heal_threshold then return false end

    -- Check if we should cancel at this checkpoint
    for _, cp in ipairs(_stopcast.checkpoints) do
        local cp_pct = cp.pct / 100
        if progress >= cp_pct - 0.05 and progress <= cp_pct + 0.05 then
            _stopcast.last_cancel = now
            -- Cancel current cast
            -- Cancel current cast via API surface
            pcall(function() return NS.cancel_spells() end)
            return true
        end
    end

    -- Also check if HP recovered above threshold regardless of checkpoint
    if hp >= heal_threshold + 5 then
        _stopcast.last_cancel = now
        pcall(function() return NS.cancel_spells() end)
        return true
    end

    return false
end

--- Returns current cast progress as a fraction (0-1)
---@return number|nil
function M.get_cast_progress()
    local me = _get_local_player()
    if not me then return nil end
    if not me:is_casting() then return nil end

    local ok, percent = pcall(function() return me:get_casting_percent() end)
    if ok and percent then
        return percent / 100
    end
    return nil
end

-- ============================================================================
-- Pre-heal system
-- ============================================================================

--- Attempts a pre-heal on a target
---@param target game_object Heal target
---@param spell_id integer Spell to cast
---@param ctx table Combat context (needs mana_pct, in_combat)
---@param opts table Options:
---   mana_floor number Min mana % to allow pre-heal (default 50)
---   stop_hp number HP % above which to stop pre-healing (default 90)
---   emergency_hp number HP % for unconditional cast (default 60)
---   is_moving_fn function Check if player is moving
---@return boolean used
function M.pre_heal(target, spell_id, ctx, opts)
    if not target or not spell_id or not ctx then return false end
    if not unit_is_live(target) then return false end
    opts = opts or {}

    local mana_floor = opts.mana_floor or 50
    local stop_hp = opts.stop_hp or 90
    local emergency_hp = opts.emergency_hp or 60

    -- Don't pre-heal if target is already healthy
    local hp = unit_health_pct(target)
    if hp and hp >= stop_hp then
        _preheal.active = false
        return false
    end

    -- Emergency: cast regardless if target is low
    if hp and hp <= emergency_hp then
        -- Fall through to cast below
    end

    -- Mana gate
    local mana_pct = ctx.mana_pct or 100
    if mana_pct < mana_floor then
        _preheal.active = false
        return false
    end

    -- Don't pre-heal while in combat if not engaged
    if ctx.in_combat then
        -- Only pre-heal if the target is taking damage or there's downtime
        local incoming = ctx.incoming_dps or 0
        if incoming <= 0 and hp and hp > emergency_hp then
            return false
        end
    end

    -- Check movement
    if opts.is_moving_fn then
        local is_moving = opts.is_moving_fn()
        if is_moving then return false end
    end

    -- Intent-only: return what should be cast, never cast directly.
    local ok_cd, cd = pcall(core.spell_book.get_spell_cooldown, spell_id)
    if ok_cd and cd and cd <= 0 then
        return {
            target = target,
            spell_id = spell_id,
            label = "[pre_heal] " .. tostring(spell_id),
        }
    end

    return false
end

--- Checks if pre-heal is currently active
---@return boolean
function M.is_preheal_active()
    return _preheal.active
end

--- Resets pre-heal state (call on combat end)
function M.reset_preheal()
    _preheal.active = false
    _preheal.target_guid = nil
    _preheal.spell_id = nil
end

-- ============================================================================
-- Target scoring (for intelligent heal target selection)
-- ============================================================================

--- Score priority for heal targets
local HEAL_SCORE = {
    TANK_BIAS = 50,       -- Points added for tank targets
    FOCUS_BIAS = 25,      -- Points added for focus target
    SELF_INFLATE = 20,    -- Points added to self (to deprioritize Binding Heal self-target)
    CRITICAL_HP = 500,    -- HP < 30%
    LOW_HP = 300,         -- HP 30-50%
    MEDIUM_HP = 100,      -- HP 50-75%
    MISSING_HP_SCALE = 5, -- Points per missing HP % for granularity
}

--- Determines if a unit is a tank (based on class, stance, or manual marking)
---@param unit game_object Unit to check
---@return boolean is_tank
function M.is_tank(unit)
    if not unit then return false end

    -- Check class: Warrior (stance) or Druid (bear form)
    local ok, class = pcall(function() return unit:get_class() end)
    if ok and class then
        -- Warrior in Defensive stance
        if class == 1 then  -- WARRIOR
            if NS.buff_up(unit, {7372, 7166, 7165}) then return true end
        end
        -- Druid in Bear form
        if class == 11 then  -- DRUID
            if NS.buff_up(unit, {5487, 9634, 26989}) then return true end
        end
        -- Paladin
        if class == 2 then  -- PALADIN
            -- Check for Righteous Fury
            if NS.buff_up(unit, {25780}) then return true end
        end
    end

    return false
end

--- Scores a potential heal target (higher = more urgent)
---@param unit game_object Unit to score
---@param opts table Options:
---   self_bias number Additional self-bias (for Binding Heal deprioritization)
---   tank_bias number Additional tank bias
---   focus_unit game_object Focus target to check
---   max_distance number Max range to consider
---@return number score Urgency score (higher = more urgent)
function M.score_heal_target(unit, opts)
    if not unit then return -999 end
    if not unit_is_live(unit) then return -999 end

    opts = opts or {}
    local me = _get_local_player()
    if not me then return -999 end

    -- Check distance
    local max_dist = opts.max_distance or 40
    local dist = unit_distance_from(me, unit)
    if dist and dist > max_dist then return -999 end

    local hp = unit_health_pct(unit)
    if not hp then return -999 end

    local score = 0

    -- Critical HP urgency
    if hp < 30 then
        score = score + HEAL_SCORE.CRITICAL_HP + (100 - hp) * HEAL_SCORE.MISSING_HP_SCALE
    elseif hp < 50 then
        score = score + HEAL_SCORE.LOW_HP + (50 - hp) * HEAL_SCORE.MISSING_HP_SCALE
    elseif hp < 75 then
        score = score + HEAL_SCORE.MEDIUM_HP + (75 - hp) * 2
    end

    -- Tank bias
    if M.is_tank(unit) then
        score = score + (opts.tank_bias or HEAL_SCORE.TANK_BIAS)
    end

    -- Focus bias
    if opts.focus_unit then
        local ok, f_guid = pcall(function() return opts.focus_unit:get_guid() end)
        local ok2, u_guid = pcall(function() return unit:get_guid() end)
        if ok and ok2 and f_guid and u_guid and tostring(f_guid) == tostring(u_guid) then
            score = score + (opts.focus_bias or HEAL_SCORE.FOCUS_BIAS)
        end
    end

    -- Self-inflation for Binding Heal deprioritization
    local ok_me, me_guid = pcall(function() return me:get_guid() end)
    local ok_u, uu_guid = pcall(function() return unit:get_guid() end)
    if ok_me and ok_u and me_guid and uu_guid and tostring(me_guid) == tostring(uu_guid) then
        score = score - (opts.self_bias or HEAL_SCORE.SELF_INFLATE)
    end

    return score
end

--- Selects the best heal target from a set of candidates
---@param units game_object[] Array of candidate units
---@param opts table Same as score_heal_target opts
---@return game_object|nil best Best target
function M.select_best_heal_target(units, opts)
    if not units or #units == 0 then return nil end

    opts = opts or {}
    local best = nil
    local best_score = -999

    for i = 1, #units do
        local unit = units[i]
        local score = M.score_heal_target(unit, opts)
        if score > best_score then
            best_score = score
            best = unit
        end
    end

    return best
end

--- Builds a heal target list (party + self + raid)
---@param include_self boolean Include self in the list
---@param max_range number Maximum range in yards
---@return game_object[] targets
function M.get_heal_targets(include_self, max_range)
    if include_self == nil then include_self = true end
    if not max_range then max_range = 40 end

    local now = _core_time()
    local me = _get_local_player()
    if not me then return {} end

    -- Cache for 500ms
    if now - _target_cache.last_build < 0.5 then
        return _target_cache.units
    end

    local targets = {}
    local idx = 1

    -- Add self
    if include_self then
        targets[idx] = me
        idx = idx + 1
    end

    -- Add party members
    local ok_party, party = pcall(_get_party)
    if ok_party and party then
        for i = 1, #party do
            local member = party[i]
            if unit_is_live(member) then
                local dist = unit_distance_from(me, member)
                if dist and dist <= max_range then
                    targets[idx] = member
                    idx = idx + 1
                end
            end
        end
    end

    -- Trim and cache
    for i = idx, #_target_cache.units do
        _target_cache.units[i] = nil
    end

    _target_cache.units = targets
    _target_cache.last_build = now

    return targets
end

-- ============================================================================
-- Heal state
-- ============================================================================

--- Builds a heal context for the current frame
---@param me game_object Local player
---@return table ctx Heal context
function M.build_heal_context(me)
    if not me then return {} end

    local ctx = {
        hp = me:get_health_percentage() or 100,
        mana_pct = me:get_mana_percentage() or 100,
        in_combat = false,
        target = me:get_target(),
        is_casting = false,
        incoming_dps = 0,
    }

    local ok, combat = pcall(function() return me:is_in_combat() end)
    if ok then ctx.in_combat = combat end

    local ok2, casting = pcall(function() return me:is_casting() end)
    if ok2 then ctx.is_casting = casting end

    return ctx
end

-- ============================================================================
-- Export
-- ============================================================================

NS.HealerEngine = M

return M

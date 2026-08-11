-- hunter_core_sylvanas.lua -- shared Hunter core: auto-shot timer + shot weaving + sting/aspect/pet helpers.
-- WHAT:   shared Hunter core: auto-shot timer + shot weaving + sting/aspect/pet helpers.
-- WHEN:   called per-frame by all 3 Hunter specs and shot_timer module
-- WHY:    centralises Hunter timing logic into one module
-- SAFETY: auto_shot_active nil-guarded; ms_until_auto(0) means no pending
-- DECISION: pure helper consumed via require() by specs; no on_update side-effects.


-- ============================================================================
-- Shared Hunter Core: auto-shot timer, shot weaving, sting/aspect/pet helpers
-- ============================================================================
local M = {}
local _G = _G
local NS = _G.EaxRotations
if not NS then return M end

-- IZI SDK cache for spell sequences
local _izi = nil
do
    local ok, mod = pcall(require, "common/izi_sdk")
    if ok and type(mod) == "table" then _izi = mod end
end

-- ============================================================================
-- Auto-shot timer state (prevents clipping)
-- ============================================================================
local shot_state = {
    last_auto_time = 0,
    weapon_speed = 0,
    base_weapon_speed = 0,
    auto_shot_active = false,
}

local AUTO_SHOT_ID = 75
local DEFAULT_WEAPON_SPEED = 2.9

-- Popular TBC Hunter Weapons for Base Speed lookup
local WEAPON_BASE_SPEEDS = {
    [28772] = 2.9, -- Sunfury Bow of the Phoenix
    [32336] = 3.0, -- Black Bow of the Betrayer
    [30906] = 3.0, -- Bristleblitz Striker
    [34195] = 3.0, -- Golden Bow of Quel'Thalas
    [34334] = 2.7, -- Thori'dal, the Stars' Fury
    [32253] = 2.9, -- Gladiator's Crossbow
    [28673] = 2.8, -- Valanos' Longbow
    [31303] = 2.9, -- Veteran's Musket
    [29943] = 2.8, -- Serpent Spine Longbow
    [28504] = 2.7, -- Steelhawk Crossbow
    [28297] = 2.6, -- Don Santos' Famous Hunting Rifle
    [27503] = 3.0, -- Gladiator's Heavy Crossbow
}

local function now()
    return NS and NS.time_now and NS.time_now() or 0
end

--- Get the player's current ranged weapon speed (including haste).
function M.get_weapon_speed()
    local me = NS.GetPlayer and NS.GetPlayer()
    if me and me.get_ranged_weapon_speed then
        local ok, speed = pcall(me.get_ranged_weapon_speed, me)
        if ok and speed and speed > 0 then
            shot_state.weapon_speed = speed
            return speed
        end
    end
    return (shot_state.weapon_speed or 0) > 0 and shot_state.weapon_speed or DEFAULT_WEAPON_SPEED
end

--- Get the player's base ranged weapon speed (from item).
function M.get_base_weapon_speed()
    if shot_state.base_weapon_speed > 0 then return shot_state.base_weapon_speed end
    if not NS.get_equipped_item_id then return DEFAULT_WEAPON_SPEED end
    
    local item_id = NS.get_equipped_item_id(18) -- RANGED slot
    if item_id and WEAPON_BASE_SPEEDS[item_id] then
        shot_state.base_weapon_speed = WEAPON_BASE_SPEEDS[item_id]
        return shot_state.base_weapon_speed
    end
    
    -- Heuristic: if out of combat and no haste buffs, current speed is base speed
    if not shot_state.in_combat then
        local current = M.get_weapon_speed()
        if current > 2.0 then -- Avoid detecting while some permanent haste is active
            shot_state.base_weapon_speed = current
            return current
        end
    end
    
    return DEFAULT_WEAPON_SPEED
end

--- Get current Steady Shot cast time in MS, adjusted for haste.
function M.get_steady_cast_ms()
    local current_speed = M.get_weapon_speed()
    local base_speed = M.get_base_weapon_speed()
    -- TBC Formula: CastTime = BaseCastTime / (BaseWeaponSpeed / CurrentWeaponSpeed)
    local cast_ms = (1.5 * current_speed / base_speed) * 1000
    return math.max(500, cast_ms) -- Floor at 0.5s
end

--- Record an auto-shot event (called from spell cast callback).
function M.record_auto_shot()
    shot_state.last_auto_time = now()
    shot_state.auto_shot_active = true
end

--- Record an instant shot (Arcane Shot, Multi-Shot, etc).
function M.record_instant_shot()
end

--- Record the start of a Steady Shot cast.
function M.record_steady_start()
end


--- Milliseconds until the next auto-shot.
--- Returns 0 if no auto is queued/pending.
function M.ms_until_auto()
    if not shot_state.auto_shot_active or shot_state.weapon_speed == 0 then
        return 0
    end
    local elapsed = (now() - shot_state.last_auto_time) * 1000
    local total_ms = shot_state.weapon_speed * 1000
    local remaining = total_ms - elapsed
    return math.max(0, remaining)
end

--- Dynamic auto-shot buffer per wowsims APL style.
--- Buffer = min(500ms, 25% of current swing time).
--- This improves non-clip decisions and Multi/Arcane insertion timing.
function M.get_auto_shot_buffer_ms()
    local speed = M.get_weapon_speed()
    if not speed or speed <= 0 then return 150 end
    local swing_ms = speed * 1000
    return math.min(500, math.floor(swing_ms * 0.25 + 0.5))
end

--- Milliseconds until next auto, plus the dynamic buffer.
function M.ms_until_auto_with_buffer()
    local remain = M.ms_until_auto()
    if remain == 0 then return 0 end
    return remain + M.get_auto_shot_buffer_ms()
end

--- Can cast Steady Shot without clipping auto-shot?
-- TBC Hunter shot-weave rules:
--   1. If no auto pending → safe to cast.
--   2. If window fits Steady + buffer + 500ms safety → safe to cast.
--   3. High-haste (weapon speed too fast to fit): still cast Steady (1:1
--      rotation intentionally delays the auto), but NEVER during the 500ms
--      auto-shot wind-up window.
function M.can_cast_steady(buffer_ms)
    buffer_ms = buffer_ms or M.get_auto_shot_buffer_ms()
    M.get_weapon_speed()  -- refresh cached speed before ms_until_auto uses it
    local remain = M.ms_until_auto()
    local steady_cast_ms = M.get_steady_cast_ms()
    -- Case 1: no auto-shot pending (just fired or not yet synced)
    if remain == 0 then return true end
    -- Case 2: normal weave — enough time to fit Steady before next auto
    local needed = steady_cast_ms + buffer_ms + 500
    if remain > needed then return true end
    -- Case 3: high haste — weapon speed is shorter than Steady cast time.
    -- In TBC the optimal play is the 1:1 rotation (one Steady per auto),
    -- which intentionally delays the auto. We only avoid the 500ms wind-up.
    local weapon_speed_ms = M.get_weapon_speed() * 1000
    if weapon_speed_ms <= needed and remain > 500 then return true end
    return false
end

--- Can cast an instant shot (Arcane/Multi/Sting) without clipping auto-shot?
function M.can_cast_instant(cast_ms, buffer_ms)
    cast_ms = cast_ms or 500  -- Heuristic for GCD start? No, GCD is 1500.
    buffer_ms = buffer_ms or M.get_auto_shot_buffer_ms()
    local remain = M.ms_until_auto()
    -- [ARTISTRY] Improved: Account for the 500ms "Auto-Shot window".
    -- Casting an instant shot triggers the GCD, but also blocks the auto if within the 0.5s window.
    return remain == 0 or remain > (buffer_ms + 500)
end

--- Initialize auto-shot tracking via spell cast callback.
function M.init()
    if NS.register_on_spell_cast then
        NS.register_on_spell_cast(function(spell_id, target, data)
            if spell_id == AUTO_SHOT_ID then
                M.record_auto_shot()
            end
        end)
    elseif core and core.register_on_spell_cast_callback then
        core.register_on_spell_cast_callback(function(data)
            if data and data.spell_id == AUTO_SHOT_ID then
                M.record_auto_shot()
            end
        end)
    end
end

-- ============================================================================
-- Sting debuff IDs
-- ============================================================================
local STING_IDS = {
    serpent = { 27016, 25295, 13555, 13554, 13553, 13552, 13551, 13550, 13549, 1978 },
    scorpid = { 3043 },
    viper   = { 27018, 14280, 14279, 3034 },
}


--- Get remaining time for a specific sting type.
---@param target game_object
---@param sting_type string 'serpent', 'scorpid', 'viper'
---@return number seconds
function M.sting_remains(target, sting_type)
    if not target then return 0 end
    local ids = STING_IDS[sting_type]
    if not ids then return 0 end
    for _, id in ipairs(ids) do
        if NS.debuff_up and NS.debuff_up(target, id) then
            return NS.debuff_remains and NS.debuff_remains(target, id) or 0
        end
    end
    return 0
end

-- ============================================================================
-- Aspect helpers
-- ============================================================================
--- Should we switch to Aspect of the Viper based on mana %?
---@param mana_pct number (0-100)
---@param viper_threshold number (default 30)
---@return boolean
function M.should_viper(mana_pct, viper_threshold)
    viper_threshold = viper_threshold or 30
    return mana_pct < viper_threshold
end

--- Should we switch back to Aspect of the Hawk based on mana %?
---@param mana_pct number
---@param hawk_threshold number (default 50)
---@return boolean
function M.should_hawk(mana_pct, hawk_threshold)
    hawk_threshold = hawk_threshold or 50
    return mana_pct > hawk_threshold
end

-- ============================================================================
-- Threat helpers
-- ============================================================================
--- Should we Feign Death?
---@param threat_level number (0-3 from get_threat_situation)
---@param fd_mode string 'off', 'high_threat', 'aggro_only'
---@return boolean
function M.should_feign_death(threat_level, fd_mode)
    if fd_mode == 'off' or not fd_mode then return false end
    if fd_mode == 'high_threat' and threat_level >= 2 then return true end
    if fd_mode == 'aggro_only' and threat_level >= 3 then return true end
    return false
end

-- ============================================================================
-- Pet management helpers
-- ============================================================================
local _last_mend_time = 0
local _last_pet_scan = 0
local _cached_pet = nil

function M.get_pet()
    if now() - _last_pet_scan > 1 then
        _last_pet_scan = now()
        _cached_pet = NS.GetPet and NS.GetPet() or nil
    end
    return _cached_pet
end

function M.pet_alive()
    local pet = M.get_pet()
    if not pet then return false end
    -- Fail-open alive check (mirrors NS.unit_alive): is_alive() is not present
    -- on every PS build; is_dead()/is_valid()/is_ghost() decide instead.
    -- Failing closed here silently killed the whole BM pet lane (Kill Command,
    -- Bestial Wrath, Mend Pet, Intimidation) on the live client.
    if NS.unit_alive then
        local ok, alive = pcall(NS.unit_alive, pet)
        if ok then return alive == true end
    end
    local ok, alive = pcall(function() return pet:is_alive() end)
    if ok and type(alive) == "boolean" then return alive end
    local okd, dead = pcall(function() return pet:is_dead() end)
    if okd and type(dead) == "boolean" then return not dead end
    return true
end

function M.pet_hp_pct()
    local pet = M.get_pet()
    if not pet then return 0 end
    local ok, hp = pcall(function() return pet:get_health_percentage() end)
    return ok and hp or 0
end


function M.record_mend()
    _last_mend_time = now()
end

-- ============================================================================
-- IZI SDK Spell Sequences
-- ============================================================================


-- ============================================================================
-- Shot Priority Calculator
-- ============================================================================

--- Calculate the available window for casting between auto-shots.
---@param buffer_ms number|nil Safety buffer in ms (default 150)
---@return boolean steady_ok Can fit a Steady Shot
---@return boolean instant_ok Can fit an instant (GCD)
---@return number window_ms Remaining window in ms
function M.calculate_shot_window(buffer_ms)
    buffer_ms = buffer_ms or 150
    local remain_ms = M.ms_until_auto()
    local weapon_speed_ms = M.get_weapon_speed() * 1000
    local steady_cast_ms = 1500  -- Steady Shot cast time (TBC base)
    local gcd_ms = (NS.get_global_cooldown and NS.get_global_cooldown() or 1.5) * 1000

    if remain_ms == 0 then
        -- No auto-shot pending, full window available
        return true, true, weapon_speed_ms
    end

    -- Can we fit a Steady Shot? (cast + buffer + 500ms safety)
    local steady_ok = remain_ms > (steady_cast_ms + buffer_ms + 500)

    -- Can we fit an instant (GCD + buffer + 500ms safety)
    local instant_ok = remain_ms > (gcd_ms + buffer_ms + 500)

    return steady_ok, instant_ok, remain_ms
end


-- ============================================================================
-- Exposure
-- ============================================================================

if NS then
    NS.HunterCore = M
end

return M


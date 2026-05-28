-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "shared/warrior_core_sylvanas.lua"
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
-- What: Shared helper for warrior stance, opener, shout, and rage logic
-- When: Loaded once and consulted during per-tick combat decisions
-- Why: Centralize warrior-specific shared behavior for all specs
-- Safety: Nil-guards stance/target checks, conservative defaults, and NS.* helpers
-- ============================================================================
-- Shared Helper: Warrior Core
-- Stance management, aggro opener, shout handling, rage utilities
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player
local _get_spell_cd = core.spell_book.get_spell_cooldown
local _is_spell_learned = core.spell_book.is_spell_learned

local function cast_guarded(spell_id, target, reason, opts)
    if not NS or type(NS.try_cast) ~= "function" then return false end
    -- Legacy warrior helpers used raw cast_target_spell; route through
    -- NS.try_cast so evaluate_cast enforces GCD/cooldown/resource/target gates.
    return NS.try_cast(spell_id, target, reason, opts) == true
end

-- ============================================================================
-- Spell ID tables
-- ============================================================================

local STANCES = {
    BATTLE_STANCE = {
        2458, 7164, 7162, 7160,
    },
    DEFENSIVE_STANCE = {
        7372, 7165,
    },
    BERSERKER_STANCE = {
        7373, 7369, 27580,
    },
}

local SHOUTS = {
    BATTLE_SHOUT = {
        25289, 2048, 11551, 11550, 11549, 6673,
    },
    COMMANDING_SHOUT = {
        469, 5242, 6192, 11554, 11555, 11556, 25288,
    },
    DEMORALIZING_SHOUT = {
        25203, 19778, 11601, 11600, 11597, 11596, 11556,
    },
}

local OPENERS = {
    CHARGE = {
        35589, 35588, 35587, 35586, 26251, 26252, 26253, 6178, 100,
    },
    INTERCEPT = {
        30224, 30225, 30152, 30153, 30154, 20252, 20616, 20617,
    },
    TAUNT = {
        38464, 38463, 38462, 38461, 29707, 29708, 30356, 30357, 355,
    },
    CHALLENGING_SHOUT = {
        38468, 38467, 38466, 38465, 29711, 29712, 30358, 1161,
    },
}

-- ============================================================================
-- Stance management
-- ============================================================================

--- Known stances by name
M.STANCE_BATTLE = 1
M.STANCE_DEFENSIVE = 2
M.STANCE_BERSERKER = 3

local _stance_cache = {
    current = nil,
    last_check = 0,
}

--- Detects current stance by checking known stance spells
---@param me game_object|nil Local player
---@return integer|nil stance_id Stance ID (1=Battle, 2=Defensive, 3=Berserker) or nil
function M.get_current_stance(me)
    if not me then me = _get_local_player() end
    if not me then return nil end

    local now = _core_time()
    if _stance_cache.current and now - _stance_cache.last_check < 0.5 then
        return _stance_cache.current
    end

    -- Check via shapeshift form ID if available
    local ok, form_id = pcall(core.spell_book.get_shapeshift_form_id)
    if ok and form_id and form_id > 0 then
        -- Map form IDs: Battle=1, Defensive=2, Berserker=3
        if form_id == 1 then _stance_cache.current = M.STANCE_BATTLE
        elseif form_id == 2 then _stance_cache.current = M.STANCE_DEFENSIVE
        elseif form_id == 3 then _stance_cache.current = M.STANCE_BERSERKER
        end
        if _stance_cache.current then
            _stance_cache.last_check = now
            return _stance_cache.current
        end
    end

    -- Fallback: check buffs
    if NS.buff_up(me, STANCES.BATTLE_STANCE) then
        _stance_cache.current = M.STANCE_BATTLE
        _stance_cache.last_check = now
        return M.STANCE_BATTLE
    end
    if NS.buff_up(me, STANCES.DEFENSIVE_STANCE) then
        _stance_cache.current = M.STANCE_DEFENSIVE
        _stance_cache.last_check = now
        return M.STANCE_DEFENSIVE
    end
    if NS.buff_up(me, STANCES.BERSERKER_STANCE) then
        _stance_cache.current = M.STANCE_BERSERKER
        _stance_cache.last_check = now
        return M.STANCE_BERSERKER
    end

    return nil
end

--- Switches to a specific stance
---@param target_stance integer M.STANCE_BATTLE|M.STANCE_DEFENSIVE|M.STANCE_BERSERKER
---@return boolean switched True if stance switch was initiated
function M.switch_to_stance(target_stance)
    local me = _get_local_player()
    if not me then return false end

    local current = M.get_current_stance(me)
    if current == target_stance then return false end

    local stance_ids
    if target_stance == M.STANCE_BATTLE then
        stance_ids = STANCES.BATTLE_STANCE
    elseif target_stance == M.STANCE_DEFENSIVE then
        stance_ids = STANCES.DEFENSIVE_STANCE
    elseif target_stance == M.STANCE_BERSERKER then
        stance_ids = STANCES.BERSERKER_STANCE
    else
        return false
    end

    for _, id in ipairs(stance_ids) do
        if _is_spell_learned(id) then
            local cd = _get_spell_cd(id)
            if cd == 0 then
                return cast_guarded(id, me, "[WARRIOR CORE] Stance", { skip_range = true })
            end
        end
    end

    return false
end

--- Checks if the player should be in a stance for an ability (auto-stance-dance)
---@param required_stance integer Required stance
---@param ctx table Combat context
---@return boolean in_correct_stance
function M.in_stance(required_stance, ctx)
    if not required_stance then return true end
    local me = (ctx and ctx.me) or _get_local_player()
    if not me then return false end

    local current = M.get_current_stance(me)
    return current == required_stance
end

--- Returns stance name string for display
---@param stance_id integer|nil
---@return string name
function M.stance_name(stance_id)
    if stance_id == M.STANCE_BATTLE then return "Battle"
    elseif stance_id == M.STANCE_DEFENSIVE then return "Defensive"
    elseif stance_id == M.STANCE_BERSERKER then return "Berserker"
    end
    return "Unknown"
end

-- ============================================================================
-- Aggro opener sequence (Charge → Berserker → Whirlwind → Defensive)
-- ============================================================================

local _opener = {
    phase = 0,
    started = false,
    start_time = 0,
}

--- Begins the aggro opener sequence
---@param charge_id integer Charge spell ID
---@param whirlwind_id integer Whirlwind spell ID
---@param me game_object Local player
---@param target game_object Target
function M.start_aggro_opener(charge_id, whirlwind_id, me, target)
    _opener.phase = 1
    _opener.started = true
    _opener.start_time = _core_time()
    -- Phase 1: Charge (already handled by caller, we start post-charge)
end

--- Processes the aggro opener state machine
---@param charge_id integer Charge spell ID
---@param whirlwind_id integer Whirlwind spell ID
---@param me game_object Local player
---@param target game_object Target
---@return boolean active True if opener is still running (block rotation)
function M.process_aggro_opener(charge_id, whirlwind_id, me, target)
    if not _opener.started then return false end

    local now = _core_time()
    -- Timeout after 10 seconds
    if now - _opener.start_time > 10 then
        _opener.started = false
        _opener.phase = 0
        return false
    end

    local current = M.get_current_stance(me)

    if _opener.phase == 1 then
        -- Phase 1: After Charge, we should be in Battle stance or en route
        -- Check if Whirlwind was already queued
        if current == M.STANCE_BERSERKER then
            local cd = _get_spell_cd(whirlwind_id)
            if cd == 0 then
                if cast_guarded(whirlwind_id, target, "[WARRIOR CORE] Aggro opener Whirlwind") then
                    _opener.phase = 2
                    _opener.start_time = now
                end
            end
        else
            -- Switch to Berserker stance for Whirlwind
            M.switch_to_stance(M.STANCE_BERSERKER)
        end
        return true

    elseif _opener.phase == 2 then
        -- Phase 2: After Whirlwind, switch to Defensive stance
        if current == M.STANCE_DEFENSIVE then
            _opener.started = false
            _opener.phase = 0
            return false
        end
        M.switch_to_stance(M.STANCE_DEFENSIVE)
        return true
    end

    _opener.started = false
    return false
end

--- Resets the opener state
function M.reset_opener()
    _opener.started = false
    _opener.phase = 0
end

-- ============================================================================
-- Shout management
-- ============================================================================

local _last_shout_time = 0

--- Determines the best available shout spell ID
---@param shout_type string \"battle\"|\"commanding\"
---@return integer|nil spell_id
function M.get_shout_id(shout_type)
    local ids
    if shout_type == "battle" then
        ids = SHOUTS.BATTLE_SHOUT
    elseif shout_type == "commanding" then
        ids = SHOUTS.COMMANDING_SHOUT
    else
        return nil
    end

    for _, id in ipairs(ids) do
        if _is_spell_learned(id) then
            return id
        end
    end
    return nil
end

--- Checks if a shout should be refreshed
---@param shout_type string \"battle\"|\"commanding\"
---@param me game_object Local player
---@param min_rage number Minimum rage required
---@return integer|nil spell_id Shout ID to cast, or nil
function M.should_shout(shout_type, me, min_rage)
    if not me then return nil end
    if not min_rage then min_rage = 10 end

    local now = _core_time()
    if now - _last_shout_time < 25 then return nil end

    -- Check rage
    local rage = me:get_power() or 0
    if rage < min_rage then return nil end

    -- Check we don't have a stronger shout from another warrior
    local own_ids
    if shout_type == "battle" then
        own_ids = SHOUTS.BATTLE_SHOUT
    else
        own_ids = SHOUTS.COMMANDING_SHOUT
    end

    -- Find our highest known rank
    local my_highest = nil
    for _, id in ipairs(own_ids) do
        if _is_spell_learned(id) then
            my_highest = id
            break
        end
    end

    -- Check if we have the buff
    if my_highest then
        if NS.buff_up(me, {my_highest}) then
            -- Check remaining duration
            if (NS.buff_remains(me, {my_highest}) or 0) > 20 then
                return nil -- Still fresh
            end
        end
    end

    _last_shout_time = now
    return my_highest
end

--- Casts Demoralizing Shout if target is nearby and debuff is missing
---@param me game_object Local player
---@param target game_object Target
---@param min_rage number Minimum rage required
---@return boolean used
function M.use_demo_shout(me, target, min_rage)
    if not me or not target then return false end
    if not min_rage then min_rage = 10 end

    local rage = me:get_power() or 0
    if rage < min_rage then return false end

    -- Check if target already has demo shout
    if NS.debuff_up and NS.debuff_up(target, SHOUTS.DEMORALIZING_SHOUT) then return false end

    -- Find highest known rank
    for _, id in ipairs(SHOUTS.DEMORALIZING_SHOUT) do
        if _is_spell_learned(id) then
            local cd = _get_spell_cd(id)
            if cd == 0 then
                return cast_guarded(id, me, "[WARRIOR CORE] Demoralizing Shout", { skip_range = true })
            end
        end
    end

    return false
end

-- ============================================================================
-- Rage utilities
-- ============================================================================

--- Checks if player has enough rage after reserving for key abilities
---@param required_rage number Rage cost of the spell to check
---@param reserve number Rage to reserve for high-priority abilities
---@param me game_object|nil Local player
---@return boolean has_rage
function M.has_rage_after_reserve(required_rage, reserve, me)
    if not me then me = _get_local_player() end
    if not me then return false end
    local rage = me:get_power() or 0
    return rage >= required_rage + reserve
end

--- Determines if a rage dump is appropriate
---@param rage_threshold number Minimum rage to dump
---@param me game_object|nil Local player
---@param max_rage number|nil Max rage cap (default 100)
---@return boolean should_dump
function M.should_rage_dump(rage_threshold, me, max_rage)
    if not me then me = _get_local_player() end
    if not me then return false end
    local rage = me:get_power() or 0
    max_rage = max_rage or 100
    return rage >= math.min(rage_threshold, max_rage - 10)
end

-- ============================================================================
-- Export
-- ============================================================================

NS.WarriorCore = M

return M

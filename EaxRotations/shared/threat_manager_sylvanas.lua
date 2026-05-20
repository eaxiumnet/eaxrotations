-- ============================================================================
-- Shared Helper: Threat Manager
-- Threat zone detection (green/yellow/orange/red), FD + Soulshatter modes
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations
local _core_time = core.time
local _get_local_player = core.object_manager.get_local_player

-- ============================================================================
-- Internal state
-- ============================================================================

local _last_threat_check = 0
local _cached_threat_zone = 0
local _last_fd_time = 0
local _last_soulshatter_time = 0

-- ============================================================================
-- Threat zone detection
-- ============================================================================

--- Gets the player's current threat zone:
---   0 = safe (green), 1 = moderate (yellow),
---   2 = high (orange), 3 = critical (red/aggro)
---@param me game_object|nil The local player
---@return integer zone Threat zone (0-3)
function M.get_threat_zone(me)
    me = me or _get_local_player()
    if not me then return 0 end

    local now = _core_time()

    -- Throttle to ~500ms
    if now - _last_threat_check < 0.5 then
        return _cached_threat_zone
    end
    _last_threat_check = now

    local target = me:get_target()
    if not target or not target:is_valid() then
        _cached_threat_zone = 0
        return 0
    end

    local ok, situation = pcall(function() return target:get_threat_situation() end)
    if ok and situation then
        local zone = tonumber(situation) or 0
        -- Clamp to 0-3
        if zone < 0 then zone = 0
        elseif zone > 3 then zone = 3 end
        _cached_threat_zone = zone
        return zone
    end

    return _cached_threat_zone
end

--- Checks if the player is in or above a specific threat zone
---@param zone integer Threat zone threshold (1 = moderate, 2 = high, 3 = aggro)
---@param me game_object|nil
---@return boolean in_zone
function M.is_threat_zone(zone, me)
    return M.get_threat_zone(me) >= zone
end

--- Checks if the player should use a threat drop ability
---@param mode string off, high_threat, or aggro_only
---@param me game_object|nil
---@return boolean should_drop
function M.should_drop_threat(mode, me)
    if mode == 'off' then return false end

    local zone = M.get_threat_zone(me)

    if mode == 'aggro_only' then
        return zone >= 3
    elseif mode == 'high_threat' then
        return zone >= 2
    end

    return false
end

-- ============================================================================
-- Feign Death management
-- ============================================================================

--- Attempts Feign Death based on mode and throttle
---@param spell_id integer Feign Death spell ID
---@param mode string off, high_threat, or aggro_only
---@param ctx table|nil Combat context
---@return boolean used True if FD was used
function M.use_feign_death(spell_id, mode, ctx)
    if mode == 'off' then return false end
    if not spell_id then return false end

    local me = (ctx and ctx.me) or _get_local_player()
    if not me then return false end

    -- Throttle FD to once per 10 seconds max
    local now = _core_time()
    if now - _last_fd_time < 10 then return false end

    if M.should_drop_threat(mode, me) then
        -- Check spell is ready
        local ok, cd = pcall(core.spell_book.get_spell_cooldown, spell_id)
        if ok and cd and cd == 0 then
            local ok2 = pcall(core.input.cast_target_spell, spell_id, me)
            if ok2 then
                _last_fd_time = now
                return true
            end
        end
    end

    return false
end

-- ============================================================================
-- Soulshatter management
-- ============================================================================

--- Attempts Soulshatter based on mode and throttle
---@param spell_id integer Soulshatter spell ID
---@param mode string off, high_threat, or aggro_only
---@param ctx table|nil Combat context
---@return boolean used True if Soulshatter was used
function M.use_soulshatter(spell_id, mode, ctx)
    if mode == 'off' then return false end
    if not spell_id then return false end

    local me = (ctx and ctx.me) or _get_local_player()
    if not me then return false end

    -- Throttle Soulshatter to once per 30 seconds
    local now = _core_time()
    if now - _last_soulshatter_time < 30 then return false end

    if M.should_drop_threat(mode, me) then
        local ok, cd = pcall(core.spell_book.get_spell_cooldown, spell_id)
        if ok and cd and cd == 0 then
            local ok2 = pcall(core.input.cast_target_spell, spell_id, me)
            if ok2 then
                _last_soulshatter_time = now
                return true
            end
        end
    end

    return false
end

-- ============================================================================
-- Misdirection
-- ============================================================================

--- Sends Misdirection to a target (pet or focus)
---@param spell_id integer Misdirection spell ID
---@param target_type string pet, focus, or party unit identifier
---@param ctx table|nil Combat context
---@return boolean used
function M.use_misdirection(spell_id, target_type, ctx)
    if not spell_id then return false end

    local me = (ctx and ctx.me) or _get_local_player()
    if not me then return false end

    -- Determine target unit
    local target
    if target_type == 'pet' then
        local ok, pet = pcall(function() return me:get_pet() end)
        if ok and pet then target = pet end
    elseif target_type == 'focus' then
        local ok, focus = pcall(core.object_manager.get_focus)
        if ok and focus then target = focus end
    else
        -- Party member by index or name
        target = target_type
    end

    if not target then return false end

    local ok, cd = pcall(core.spell_book.get_spell_cooldown, spell_id)
    if not ok or not cd or cd > 0 then return false end

    local ok2 = pcall(core.input.cast_target_spell, spell_id, target)
    return ok2 or false
end

-- ============================================================================
-- Export
-- ============================================================================

NS.ThreatManager = M

return M

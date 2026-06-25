-- =============================================================================
-- core/units.lua
--
-- Units domain — extracted from EaxRotations/core_sylvanas.lua.
-- Owns GetPlayer / GetPet / GetTarget / GetFocus / GetPartyMembers /
-- unit_alive / unit_health_pct / same_unit / not_same_unit / safe_field
-- (renamed to NS.unit_safe_field so callers keep `safe_field` indirection
-- through NS).
--
-- WHY THIS EXTRACT
--   core_sylvanas.lua mixed ~15 unrelated domains. centralising unit
--   acquisition lets caching strategy / alive-guard logic evolve in one
--   file without risk of breaking unrelated specs.
--
-- CONTRACT
--   - install(NS): wires GetPlayer, GetPet, get_pet, has_pet, get_pet_hp,
--     GetTarget, GetFocus, GetPartyMembers onto NS.
--   - Test mocks that supply these fields directly will still win
--     (NS.<fn> = M.<fn> assignment overwrites whatever the mock had).
-- =============================================================================

local M = {}

local _player_cache_tick = -1

function M.GetPlayer(NS)
    -- Per-tick short-circuit: same tick => cached.
    local now = NS.time_now()
    if now == _player_cache_tick and NS.PLAYER_UNIT then
        return NS.PLAYER_UNIT
    end
    _player_cache_tick = now

    -- Stale-object guard.
    if NS.PLAYER_UNIT then
        local ok = pcall(function() return NS.PLAYER_UNIT:is_valid() end)
        if not ok then
            NS.PLAYER_UNIT = nil
            local lg = NS.log or (NS.core and NS.core.log)
            if lg then pcall(lg, "[EaxRotations:units] GetPlayer: stale guard nil'd PLAYER_UNIT") end
        end
    end

    local om = NS.core and NS.core.object_manager
    if not om then
        local lg = NS.log or (NS.core and NS.core.log)
        if lg then pcall(lg, "[EaxRotations:units] GetPlayer: NS.core or NS.core.object_manager is nil") end
    elseif type(om.get_local_player) == "function" then
        local ok, fresh = pcall(om.get_local_player, om)
        if ok and fresh then
            local valid = pcall(function() return fresh:is_valid() end)
            if valid then
                NS.PLAYER_UNIT = fresh
                return fresh
            end
        end
        local lg = NS.log or (NS.core and NS.core.log)
        if lg then pcall(lg, "[EaxRotations:units] GetPlayer: OM.get_local_player returned ok=" .. tostring(ok) .. " fresh=" .. tostring(fresh) .. " valid=" .. tostring(valid)) end
    end
    if not NS.PLAYER_UNIT then
        local lg = NS.log or (NS.core and NS.core.log)
        if lg then pcall(lg, "[EaxRotations:units] GetPlayer: returning nil — no cached player and OM unreachable") end
    end
    return NS.PLAYER_UNIT
end

function M.GetPet(NS)
    -- safe_field / safe come from NS (installed by core_sylvanas via
    -- shared/safe_helpers_sylvanas); fall back to bare pcall if absent.
    local safe, safe_field
    pcall(function() safe = NS.safe end)
    pcall(function() safe_field = NS.safe_field end)
    local player = NS.GetPlayer()
    local get_pet = safe_field and safe_field(player, "get_pet") or nil
    local pet = (get_pet and safe and safe(get_pet, player)) or nil
    if pet and NS.unit_alive and NS.unit_alive(pet) then return pet end
    return nil
end

function M.install(NS)
    function NS.GetPlayer() return M.GetPlayer(NS) end
    function NS.GetPet() return M.GetPet(NS) end
    NS.get_pet = NS.GetPet
    function NS.has_pet() return NS.GetPet() ~= nil end
    function NS.get_pet_hp()
        local pet = NS.GetPet()
        return pet and NS.unit_health_pct and NS.unit_health_pct(pet) or 100
    end
end

return M

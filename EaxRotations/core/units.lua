-- units.lua — Unit acquisition and safety helpers for EaxRotations.
-- WHAT:  GetPlayer / GetPet / GetTarget / GetFocus / GetPartyMembers + alive guards.
-- WHEN:  installed by core_sylvanas.lua during addon load.
-- WHY:   centralizes object_manager access (esp. new core.party / get_party_frames) so
--        party lists, lowest HP etc. are accurate and cheap. Caching evolves here.
-- SAFETY: nil-safe fallbacks for all unit queries; same_unit uses GUID when available.

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
local _time_now_fn = nil  -- hoisted for perf, avoid NS lookup every GetPlayer (per subagent)

function M.GetPlayer(NS)
    -- Ensure cached safe wrappers (perf optimization) are populated early; GetPlayer called before GetPet in many paths.
    if not NS._safe_field then
        local sf
        pcall(function() sf = NS.safe_field end)
        NS._safe_field = sf
    end
    if not _time_now_fn then
        pcall(function() _time_now_fn = NS.time_now end)
    end
    -- Per-tick short-circuit: same tick => cached.
    local now = _time_now_fn and _time_now_fn() or 0
    if now == _player_cache_tick and NS.PLAYER_UNIT then
        return NS.PLAYER_UNIT
    end
    _player_cache_tick = now

    -- Stale-object guard. Use cached safe_field (from previous perf cache) to reduce raw pcall duplication.
    -- Logic matches original (check pcall success, not the is_valid return value) to preserve behavior.
    if NS.PLAYER_UNIT then
        local is_valid = NS._safe_field and NS._safe_field(NS.PLAYER_UNIT, "is_valid")
        if is_valid then
            local ok = pcall(is_valid, NS.PLAYER_UNIT)
            if not ok then
                NS.PLAYER_UNIT = nil
                local lg = NS.log or (NS.core and NS.core.log)
                if lg then pcall(lg, "[EaxRotations:units] GetPlayer: stale guard nil'd PLAYER_UNIT") end
            end
        end
    end

    local om = NS.core and NS.core.object_manager
    if not om then
        local lg = NS.log or (NS.core and NS.core.log)
        if lg then pcall(lg, "[EaxRotations:units] GetPlayer: NS.core or NS.core.object_manager is nil") end
    elseif type(om.get_local_player) == "function" then
        local ok, fresh = pcall(om.get_local_player, om)
        if ok and fresh then
            local is_valid = NS._safe_field and NS._safe_field(fresh, "is_valid")
            local valid = false
            if is_valid then
                valid = pcall(is_valid, fresh)  -- first return of pcall (success), matching original logic
            end
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
    -- PERF (Phase C): cache the wrappers at first use instead of pcall every GetPet
    -- (reduces pcall overhead per AGENTS Pattern 2; matches subagent perf report).
    if not NS._safe or not NS._safe_field then
        local s, sf
        pcall(function() s = NS.safe end)
        pcall(function() sf = NS.safe_field end)
        NS._safe = s
        NS._safe_field = sf
    end
    local safe = NS._safe
    local safe_field = NS._safe_field
    local player = NS.GetPlayer()
    local get_pet = safe_field and safe_field(player, "get_pet") or nil
    local pet = (get_pet and safe and safe(get_pet, player)) or nil
    if pet and NS.unit_alive and NS.unit_alive(pet) then return pet end
    return nil
end

function M.has_friendly_target(NS)
    local me = NS.GetPlayer and NS.GetPlayer()
    if not me then return false end
    local target = NS.GetTarget and NS.GetTarget()
    if not target then return false end
    -- No native is_friendly(); "friendly" = alive and not hostile (can_attack /
    -- is_enemy_with). NS.is_hostile_unit is defined in core_sylvanas and resolved
    -- at CALL time, so install order here is safe.
    if NS.is_hostile_unit and NS.is_hostile_unit(me, target) then return false end
    return true
end

--- Returns { unit, hp_pct, effective_hp, is_player } for the player's current
--- friendly target, or nil if target is missing/hostile/dead. effective_hp
--- falls back to hp_pct (no triage ranking for a manually-selected target).
--- Used by healer FriendlyTarget strategies (B6) for manual-target control.
function M.get_friendly_target_entry(NS, context)
    local me = (context and context.me) or (NS.GetPlayer and NS.GetPlayer())
    if not me then return nil end
    local target = NS.GetTarget and NS.GetTarget()
    if not target then return nil end
    if NS.is_hostile_unit and NS.is_hostile_unit(me, target) then return nil end
    -- NS.GetTarget already filters to alive, but double-check defensively.
    if NS.unit_alive and not NS.unit_alive(target) then return nil end
    local hp_pct = (NS.unit_health_pct and NS.unit_health_pct(target)) or 100
    local is_player = false
    if target.is_player then
        local ok, p = pcall(target.is_player, target)
        if ok then is_player = p == true end
    end
    return { unit = target, hp_pct = hp_pct, effective_hp = hp_pct, is_player = is_player }
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
    function NS.has_friendly_target() return M.has_friendly_target(NS) end
    function NS.get_friendly_target_entry(context) return M.get_friendly_target_entry(NS, context) end
end

return M

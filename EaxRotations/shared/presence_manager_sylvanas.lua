-- presence_manager_sylvanas.lua — Death Knight presence management for WotLK (3.3.5).
-- WHAT:  Decide which DK presence (Blood, Frost, Unholy) to maintain.
-- WHEN:  All Death Knight specs (Blood, Frost, Unholy) when NS.is_wotlk() is true.
-- WHY:   Blood for DPS, Frost for tanking/survival, Unholy for movement/Unholy spec.
-- SAFETY: Nil-guarded settings reads; exits safely on non-WotLK clients.
-- DECISION: DK presence auto-switch, separate from Warrior stances.

local _G = _G
local NS = _G.EaxRotations
if not NS then return nil end

local M = {}
NS.PresenceManager = M

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
local PRESENCE = {
    BLOOD = 1,
    FROST = 2,
    UNHOLY = 3,
}

local PRESENCE_SPELL_IDS = {
    [PRESENCE.BLOOD] = 48266,
    [PRESENCE.FROST] = 48263,
    [PRESENCE.UNHOLY] = 48265,
}

-- ---------------------------------------------------------------------------
-- Settings helper
-- ---------------------------------------------------------------------------
local function setting(context, key, fallback)
    local s = context and context.settings
    if s and s[key] ~= nil then return s[key] end
    if NS.get_setting then return NS.get_setting(key, fallback) end
    return fallback
end

-- ---------------------------------------------------------------------------
-- Determine the optimal presence for the current state.
-- Returns: "blood", "frost", "unholy", or nil (maintain current)
-- ---------------------------------------------------------------------------
function M.get_optimal_presence(context, state)
    context = context or {}
    state = state or {}

    -- DK presences only exist in WotLK; bail out safely on other clients.
    if not (NS.is_wotlk and NS.is_wotlk()) then
        return nil
    end

    local mode = setting(context, "presence_mode", "auto")
    -- Manual lock-in modes
    if mode == "blood" then return "blood" end
    if mode == "frost" then return "frost" end
    if mode == "unholy" then return "unholy" end
    if mode == "manual" then return nil end

    local hp = state.hp or context.hp or 100
    local in_combat = state.in_combat or context.in_combat or false
    local role = state.role or context.role or "dps"
    local spec = state.spec or context.spec or "blood"
    local movement = state.movement or context.movement or {}
    local is_rooted = movement.is_rooted or movement.rooted or false
    local is_slowed = movement.is_slowed or movement.slowed or false
    local needs_movement = movement.needs_movement or movement.needs_move or false

    -- Tank / survival: Frost Presence when tanking or low HP in combat
    if role == "tank" then
        return "frost"
    end

    if hp < 30 and in_combat then
        return "frost"
    end

    -- Movement / crowd-control: Unholy Presence for snare/root/movement needs
    if is_rooted or is_slowed or needs_movement then
        return "unholy"
    end

    -- Unholy spec prefers Unholy Presence
    if spec == "unholy" then
        return "unholy"
    end

    -- Default DPS presence is Blood
    return "blood"
end

-- ---------------------------------------------------------------------------
-- Check if a presence switch should actually happen.
-- Returns true if the desired presence differs from the current one and
-- switching is not blocked by manual mode.
-- ---------------------------------------------------------------------------
function M.should_switch_presence(context, state, desired_presence)
    if not desired_presence then return false end
    context = context or {}
    state = state or {}

    -- DK presences only exist in WotLK; bail out safely on other clients.
    if not (NS.is_wotlk and NS.is_wotlk()) then
        return false
    end

    local current_id = state.presence or context.presence or PRESENCE.BLOOD
    local desired_id = M.presence_id(desired_presence)

    if not desired_id then return false end
    if current_id == desired_id then return false end

    -- Respect manual mode
    local mode = setting(context, "presence_mode", "auto")
    if mode == "manual" then return false end

    return true
end

-- ---------------------------------------------------------------------------
-- Convenience: get presence name from ID
-- ---------------------------------------------------------------------------
function M.presence_name(id)
    if id == PRESENCE.BLOOD then return "blood" end
    if id == PRESENCE.FROST then return "frost" end
    if id == PRESENCE.UNHOLY then return "unholy" end
    return nil
end

-- ---------------------------------------------------------------------------
-- Convenience: get presence ID from name
-- ---------------------------------------------------------------------------
function M.presence_id(name)
    if name == "blood" then return PRESENCE.BLOOD end
    if name == "frost" then return PRESENCE.FROST end
    if name == "unholy" then return PRESENCE.UNHOLY end
    return nil
end

-- ---------------------------------------------------------------------------
-- Detect the CURRENT presence from the player's buffs.
-- Returns "blood", "frost", "unholy", or nil (no presence buff up).
-- ---------------------------------------------------------------------------
function M.current_presence(me)
    if not (NS.is_wotlk and NS.is_wotlk()) then return nil end
    if not me or not NS.buff_up then return nil end
    if NS.buff_up(me, { PRESENCE_SPELL_IDS[PRESENCE.BLOOD] }) then return "blood" end
    if NS.buff_up(me, { PRESENCE_SPELL_IDS[PRESENCE.FROST] }) then return "frost" end
    if NS.buff_up(me, { PRESENCE_SPELL_IDS[PRESENCE.UNHOLY] }) then return "unholy" end
    return nil
end

-- ---------------------------------------------------------------------------
-- Current presence as the numeric id (PRESENCE.*) or nil.
-- ---------------------------------------------------------------------------
function M.current_presence_id(me)
    return M.presence_id(M.current_presence(me))
end

-- ---------------------------------------------------------------------------
-- Convenience: get the spell ID for a presence
-- ---------------------------------------------------------------------------
function M.presence_spell_id(presence)
    local id = M.presence_id(presence)
    if id then return PRESENCE_SPELL_IDS[id] end
    return nil
end

-- module initialized
return M

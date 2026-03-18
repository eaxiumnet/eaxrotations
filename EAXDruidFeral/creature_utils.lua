-- creature_utils.lua
-- Shared helpers for creature-type-gated spell logic.
-- Only uses unit:get_creature_type() which is documented in game_object.lua.
-- v1.0.0

local creature_utils = {}

-- Cache enums once
local _enums = nil
local function enums()
    if not _enums then
        local ok, e = pcall(require, "common/enums")
        if ok and e then _enums = e end
    end
    return _enums
end

local function get_ct(unit)
    if not unit or not unit:is_valid() then return nil end
    local ok, ct = pcall(function() return unit:get_creature_type() end)
    return ok and ct or nil
end

-- --- Bleed immunity -----------------------------------------------------------
-- Undead and Elemental are immune to bleed effects in TBC.
-- Affects: Rip, Rake, Mangle (bleed component), Garrote.
function creature_utils.is_bleed_immune(target)
    local ct = get_ct(target)
    if not ct then return false end
    local e = enums()
    if not e then return false end
    return ct == e.creature_type.UNDEAD or ct == e.creature_type.ELEMENTAL
end

-- --- Banish -------------------------------------------------------------------
-- Only works on Demon and Elemental.
function creature_utils.is_banishable(target)
    local ct = get_ct(target)
    if not ct then return false end
    local e = enums()
    if not e then return false end
    return ct == e.creature_type.DEMON or ct == e.creature_type.ELEMENTAL
end

-- --- Polymorph / Hex ---------------------------------------------------------
-- Polymorph: Humanoid, Beast, Critter
-- Hex (Shaman TBC): Humanoid only in TBC (retail expanded to more)
function creature_utils.is_polymorphable(target)
    local ct = get_ct(target)
    if not ct then return false end
    local e = enums()
    if not e then return false end
    return ct == e.creature_type.HUMANOID
        or ct == e.creature_type.BEAST
        or ct == e.creature_type.CRITTER
end

-- --- Scare Beast (Hunter) ----------------------------------------------------
-- Only works on Beast.
function creature_utils.is_beast(target)
    local ct = get_ct(target)
    if not ct then return false end
    local e = enums()
    if not e then return false end
    return ct == e.creature_type.BEAST
end

-- --- Hibernate (Druid) -------------------------------------------------------
-- Only works on Beast and Dragonkin.
function creature_utils.is_hibernatable(target)
    local ct = get_ct(target)
    if not ct then return false end
    local e = enums()
    if not e then return false end
    return ct == e.creature_type.BEAST or ct == e.creature_type.DRAGONKIN
end

-- --- Shackle Undead (Priest) -------------------------------------------------
-- Only works on Undead.
function creature_utils.is_undead(target)
    local ct = get_ct(target)
    if not ct then return false end
    local e = enums()
    if not e then return false end
    return ct == e.creature_type.UNDEAD
end

-- --- Turn Evil (Paladin) -----------------------------------------------------
-- Works on Undead and Demon.
function creature_utils.is_turn_evailable(target)
    local ct = get_ct(target)
    if not ct then return false end
    local e = enums()
    if not e then return false end
    return ct == e.creature_type.UNDEAD or ct == e.creature_type.DEMON
end

-- --- Demon-only ---------------------------------------------------------------
-- Warlocks: Banish, Enslave Demon, Unending Breath (not game-relevant but here for completeness)
function creature_utils.is_demon(target)
    local ct = get_ct(target)
    if not ct then return false end
    local e = enums()
    if not e then return false end
    return ct == e.creature_type.DEMON
end

-- --- Elemental-only ----------------------------------------------------------
function creature_utils.is_elemental(target)
    local ct = get_ct(target)
    if not ct then return false end
    local e = enums()
    if not e then return false end
    return ct == e.creature_type.ELEMENTAL
end

-- --- Generic: get creature type name (for debug/logging) ---------------------
function creature_utils.get_name(target)
    local ct = get_ct(target)
    if not ct then return "unknown" end
    local e = enums()
    if not e then return tostring(ct) end
    for name, val in pairs(e.creature_type) do
        if val == ct then return name end
    end
    return tostring(ct)
end

return creature_utils

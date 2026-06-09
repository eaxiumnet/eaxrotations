-- Shared Helper: Potion item IDs and try_use_potion utility.
-- Centralises potion ID lists and the pcall-safe use_item loop so
-- class rotation files can share a single copy.

local M = {}
local NS = _G.EaxRotations

-- Health Potion IDs (TBC best-to-worst, with Classic fallbacks)
M.HEALTH_POTION_IDS = { 22829, 13446, 3928, 1710, 929, 858, 118 }

-- Mana Potion IDs (TBC best-to-worst, with Classic fallbacks)
M.MANA_POTION_IDS = { 33935, 32948, 22850, 22832, 13444, 13443, 6149, 3827, 3385, 2455 }

-- Damage/Combat Potion IDs (Destruction > Haste > Heroic > Insane Strength)
M.DAMAGE_POTION_IDS = { 22840, 22839, 22838, 22837, 13453, 13452, 13454 }

--- Try to use the first available item from a list.
--- Each call is pcall-wrapped for nil/throwing API safety.
---@param context table Rotation context (needs context.me).
---@param ids    table Array of item IDs to try, best-first.
---@return boolean true if an item was successfully used.
function M.try_use_potion(context, ids)
    if not NS or not NS.use_item_by_id then return false end
    for _, id in ipairs(ids) do
        local ok, used = pcall(NS.use_item_by_id, id, context and context.me)
        if ok and used then return true end
    end
    return false
end

return M

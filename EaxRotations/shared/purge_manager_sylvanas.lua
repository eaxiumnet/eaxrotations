-- ============================================================================
-- Shared Helper: Purge Manager
-- ============================================================================
-- Pattern: Check enemy for magic buffs, cast Purge if found.
-- Supports both standalone API calls and NS.action_matches/execute middleware.
-- ============================================================================

local M = {}
local _G = _G
local NS = _G.EaxRotations

-- Purge spell IDs by rank (newest first)
local PURGE_IDS = { 8012, 370 }

-- Common purgeable magic buff spell IDs (TBC)
-- Organized by category for readability
local PURGEABLE_BUFFS = {
    -- Power Word: Shield
    [17] = true, [592] = true, [600] = true, [3747] = true, [6065] = true,
    [6066] = true, [10898] = true, [10899] = true, [10900] = true, [10901] = true,
    [25217] = true, [25218] = true,
    -- Ice Barrier (Mage) - TBC ranks
    [11426] = true, [13031] = true, [13032] = true, [13033] = true,
    [27134] = true,
    -- Mana Shield (Mage)
    [1463] = true, [8494] = true, [8495] = true, [10191] = true, [10192] = true,
    [10193] = true, [27131] = true,
    -- Renew (Priest)
    [139] = true, [6074] = true, [6075] = true, [6076] = true, [6077] = true,
    [6078] = true, [10927] = true, [10928] = true, [10929] = true, [25315] = true,
    -- Rejuvenation (Druid)
    [774] = true, [1058] = true, [1430] = true, [2090] = true, [2091] = true,
    [3627] = true, [8910] = true, [9839] = true, [9840] = true, [9841] = true,
    [25299] = true,
    -- Regrowth (Druid)
    [8936] = true, [8938] = true, [8939] = true, [8940] = true, [8941] = true,
    [25297] = true, [26980] = true,
    -- Mark of the Wild (Druid)
    [1126] = true, [5232] = true, [6756] = true, [5234] = true, [8907] = true, [8910] = true,
    -- Power Word: Fortitude (Priest)
    [1243] = true, [1244] = true, [1245] = true,
    [2791] = true, [10937] = true, [10938] = true,
    [25389] = true,
    -- Arcane Intellect (Mage)
    [1459] = true, [1460] = true, [1461] = true, [168] = true,
    [7300] = true, [7301] = true,
    [10156] = true, [10157] = true,
    -- Blessing of Might (Paladin)
    [19740] = true, [19834] = true, [19835] = true, [19836] = true, [19837] = true,
    [19838] = true, [25291] = true, [27140] = true,
    -- Blessing of Wisdom (Paladin)
    [19742] = true, [19850] = true, [19852] = true, [19853] = true,
    [19854] = true, [25291] = true,
    -- Blessing of Kings (Paladin)
    [20217] = true, [25298] = true,
    -- Blessing of Salvation (Paladin)
    [1038] = true, [25895] = true,
    -- Inner Fire (Priest)
    [588] = true, [602] = true, [1006] = true,
    [10951] = true, [10952] = true, [25431] = true,
    -- Divine Spirit (Priest)
    [14752] = true, [14818] = true, [14819] = true, [27681] = true,
    -- Arcane Brilliance (Mage)
    [23028] = true, [27127] = true,
    -- Gift of the Wild (Druid)
    [21849] = true, [21850] = true,
    -- Prayer of Fortitude (Priest)
    [21562] = true, [21564] = true,
    -- Prayer of Spirit (Priest)
    [27681] = true, [32999] = true,
    -- Fel Armor (Warlock)
    [28176] = true, [28189] = true,
    -- Demon Armor (Warlock)
    [687] = true, [696] = true, [706] = true, [1086] = true,
    [11733] = true, [11734] = true, [11735] = true, [27260] = true,
    -- Ice Armor (Mage)
    [7302] = true, [7320] = true, [10219] = true, [10220] = true, [27124] = true,
}

--- Check if enemy has magic buffs that should be purged.
-- @param target table - Enemy unit object
-- @return boolean - true if purgeable buff detected
function M.has_purgeable_buff(target)
    if not target or not NS then return false end
    if not NS.has_buff then return false end

    for buff_id, _ in pairs(PURGEABLE_BUFFS) do
        if NS.has_buff(target, buff_id) then
            return true
        end
    end

    return false
end

--- Get the learned Purge spell ID (highest rank).
-- @return number|nil - Learned Purge spell ID or nil
function M.get_purge_spell_id()
    if not NS or not NS.is_spell_learned then return nil end
    for _, id in ipairs(PURGE_IDS) do
        if NS.is_spell_learned(id) then
            return id
        end
    end
    return nil
end

--- Attempt to purge enemy magic buffs.
-- @param context table - Rotation context with settings, me, target
-- @return boolean - true if purge was cast
function M.try_purge(context)
    if not context or not context.settings then return false end
    if context.settings.use_purge == false then return false end
    if not context.target then return false end

    -- Check if target has purgeable buffs
    if not M.has_purgeable_buff(context.target) then return false end

    -- Check if we have Purge learned and ready
    local purge_id = M.get_purge_spell_id()
    if not purge_id then return false end
    if not NS.spell_ready then return false end
    if not NS.spell_ready(purge_id, context.target) then return false end

    -- Cast Purge
    if NS.try_cast then
        return NS.try_cast(purge_id, context.target, "[SHAMAN] Purge")
    end
    return false
end

--- Middleware strategy for Purge (NS.action_matches / NS.action_execute compatible).
-- Returns a strategy table suitable for NS.register_class_middleware.
-- @param SPELLS table - Class spell table (must contain Purge key)
-- @return table - Strategy entry
function M.as_middleware_strategy(SPELLS)
    local spell = SPELLS and SPELLS.Purge
    if not spell then return nil end
    return {
        name = "Purge",
        matches = function(context)
            if context.settings.use_purge == false then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            if not M.has_purgeable_buff(context.target) then return false end
            return NS.action_matches(context, {
                name = "Purge",
                spell = spell,
                setting = "use_purge",
            })
        end,
        execute = function(context)
            return NS.action_execute(context, {
                name = "Purge",
                spell = spell,
                setting = "use_purge",
            }, "[SHAMAN]")
        end,
    }
end

-- Register with EaxRotations namespace if available
if _G.EaxRotations then
    _G.EaxRotations.PurgeManager = M
end

return M

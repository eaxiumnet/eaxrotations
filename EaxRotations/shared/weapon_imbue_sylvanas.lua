-- ============================================================================
-- Shared Helper: Weapon Imbue Manager
-- ============================================================================
-- Readability notes:
--   What: tracks and maintains weapon buffs (oils, stones, poisons, shaman imbues).
--   When: out-of-combat weapon buff maintenance.
--   Why: ensures optimal weapon buffs are always active.
--   Safety: API probe first, no blind casting.

local M = {}
local _G = _G
local NS = _G.EaxRotations

local EMPTY = {}

-- API availability flags
local api_available = {
    weapon_enchant = false,
}

-- Weapon buff categories
local IMBUE_CATEGORIES = {
    SHAMAN_MH = "shaman_mh",
    SHAMAN_OH = "shaman_oh",
    ROGUE_MH = "rogue_mh",
    ROGUE_OH = "rogue_oh",
    WEAPON_OIL = "weapon_oil",
    SHARPENING_STONE = "sharpening_stone",
}

-- Known weapon buff IDs (TBC only)
local WEAPON_BUFFS = {
    -- Shaman Imbues (spell IDs from TBC)
    [8232] = { category = "shaman_mh", name = "Windfury Weapon" },
    [8235] = { category = "shaman_mh", name = "Windfury Weapon Rank 2" },
    [10486] = { category = "shaman_mh", name = "Windfury Weapon Rank 3" },
    [16362] = { category = "shaman_mh", name = "Windfury Weapon Rank 4" },
    [25505] = { category = "shaman_mh", name = "Windfury Weapon Rank 5" },
    [32911] = { category = "shaman_mh", name = "Windfury Weapon Rank 6" },
    
    -- Flametongue Weapon (TBC spell IDs)
    [8024] = { category = "shaman_mh", name = "Flametongue Weapon Rank 1" },
    [8027] = { category = "shaman_mh", name = "Flametongue Weapon Rank 2" },
    [8030] = { category = "shaman_mh", name = "Flametongue Weapon Rank 3" },
    [16339] = { category = "shaman_mh", name = "Flametongue Weapon Rank 4" },
    [16341] = { category = "shaman_mh", name = "Flametongue Weapon Rank 5" },
    [16342] = { category = "shaman_mh", name = "Flametongue Weapon Rank 6" },
    [25489] = { category = "shaman_mh", name = "Flametongue Weapon Rank 7" },
    [25490] = { category = "shaman_mh", name = "Flametongue Weapon Rank 8" },
    
    -- Frostbrand Weapon (TBC spell IDs)
    [8033] = { category = "shaman_mh", name = "Frostbrand Weapon Rank 1" },
    [8038] = { category = "shaman_mh", name = "Frostbrand Weapon Rank 2" },
    [10456] = { category = "shaman_mh", name = "Frostbrand Weapon Rank 3" },
    [16355] = { category = "shaman_mh", name = "Frostbrand Weapon Rank 4" },
    [16356] = { category = "shaman_mh", name = "Frostbrand Weapon Rank 5" },
    [25500] = { category = "shaman_mh", name = "Frostbrand Weapon Rank 6" },
    
    -- Rockbiter Weapon (TBC spell IDs - removed in later expansions)
    [8017] = { category = "shaman_mh", name = "Rockbiter Weapon Rank 1" },
    [8018] = { category = "shaman_mh", name = "Rockbiter Weapon Rank 2" },
    [8019] = { category = "shaman_mh", name = "Rockbiter Weapon Rank 3" },
    [16314] = { category = "shaman_mh", name = "Rockbiter Weapon Rank 4" },
    [16315] = { category = "shaman_mh", name = "Rockbiter Weapon Rank 5" },
    [16316] = { category = "shaman_mh", name = "Rockbiter Weapon Rank 6" },
    [25479] = { category = "shaman_mh", name = "Rockbiter Weapon Rank 7" },
    [25480] = { category = "shaman_mh", name = "Rockbiter Weapon Rank 8" },
    
    -- Rogue Poisons (TBC item/spell IDs)
    [2672] = { category = "rogue_mh", name = "Instant Poison" },
    [2673] = { category = "rogue_mh", name = "Deadly Poison" },
    [2674] = { category = "rogue_mh", name = "Wound Poison" },
    [2675] = { category = "rogue_mh", name = "Crippling Poison" },
    [2676] = { category = "rogue_mh", name = "Mind-Numbing Poison" },
    [2677] = { category = "rogue_mh", name = "Anesthetic Poison" },
    
    -- Weapon Oils (TBC)
    [25123] = { category = "weapon_oil", name = "Superior Wizard Oil" },
    [25122] = { category = "weapon_oil", name = "Superior Mana Oil" },
    [25121] = { category = "weapon_oil", name = "Brilliant Wizard Oil" },
    [25120] = { category = "weapon_oil", name = "Brilliant Mana Oil" },
    [25119] = { category = "weapon_oil", name = "Wizard Oil" },
    [25118] = { category = "weapon_oil", name = "Mana Oil" },
    
    -- Sharpening/Weightstones (TBC)
    [16138] = { category = "sharpening_stone", name = "Consecrated Sharpening Stone" },
    [28421] = { category = "sharpening_stone", name = "Adamantite Weightstone" },
    [28420] = { category = "sharpening_stone", name = "Fel Weightstone" },
    [18262] = { category = "sharpening_stone", name = "Elemental Sharpening Stone" },
}

-- Probe APIs on load
function M.probe_apis()
    if not NS then return false end
    
    -- Check for weapon enchant info API
    if NS.GetPlayer then
        local me = NS.GetPlayer()
        if me then
            -- Try GetWeaponEnchantInfo equivalent
            local has_mh = false
            pcall(function() 
                if me.get_mainhand_imbue then
                    has_mh = true
                end
            end)
            local has_oh = false
            pcall(function() 
                if me.get_offhand_imbue then
                    has_oh = true
                end
            end)
            
            api_available.weapon_enchant = has_mh or has_oh
        end
    end
    
    -- Also check core.inventory
    if core and core.inventory then
        local ok = pcall(function()
            return core.inventory.get_weapon_enchant_info
        end)
        if ok then
            api_available.weapon_enchant = true
        end
    end
    
    return api_available.weapon_enchant
end

-- Get mainhand imbue
function M.get_mainhand_imbue()
    if not api_available.weapon_enchant then return nil end
    
    local me = NS and NS.GetPlayer and NS.GetPlayer()
    if not me then return nil end
    
    local ok, result = pcall(function()
        if me.get_mainhand_imbue then
            return me:get_mainhand_imbue()
        end
        return nil
    end)
    
    if ok then return result end
    return nil
end

-- Get offhand imbue
function M.get_offhand_imbue()
    if not api_available.weapon_enchant then return nil end
    
    local me = NS and NS.GetPlayer and NS.GetPlayer()
    if not me then return nil end
    
    local ok, result = pcall(function()
        if me.get_offhand_imbue then
            return me:get_offhand_imbue()
        end
        return nil
    end)
    
    if ok then return result end
    return nil
end

-- Check if weapon has specific imbue
function M.has_imbue(slot, imbue_ids)
    if type(imbue_ids) ~= "table" then
        imbue_ids = { imbue_ids }
    end
    
    local current_imbue = nil
    if slot == "mainhand" then
        current_imbue = M.get_mainhand_imbue()
    elseif slot == "offhand" then
        current_imbue = M.get_offhand_imbue()
    end
    
    if not current_imbue then return false end
    
    for _, id in ipairs(imbue_ids) do
        if current_imbue == id then return true end
    end
    
    return false
end

-- Get imbue status
function M.get_status()
    return {
        mh_imbue = M.get_mainhand_imbue(),
        oh_imbue = M.get_offhand_imbue(),
        api_available = api_available.weapon_enchant,
    }
end

-- Get recommended imbue for class/spec
function M.get_recommended_imbue(class, spec)
    if class == "shaman" then
        if spec == "enhancement" then
            return {
                mh = { 32911 }, -- Windfury Weapon
                oh = { 25490 }, -- Flametongue Weapon Rank 8
            }
        elseif spec == "elemental" or spec == "restoration" then
            return {
                mh = { 25490 }, -- Flametongue Weapon Rank 8
            }
        end
    elseif class == "rogue" then
        -- Default rogue poisons
        return {
            mh = { 2672 }, -- Instant Poison
            oh = { 2673 }, -- Deadly Poison
        }
    end
    
    return nil
end

-- Check if imbue needs refresh
function M.needs_refresh(slot, threshold_minutes)
    threshold_minutes = threshold_minutes or 5
    
    if not api_available.weapon_enchant then
        -- Can't check - assume needs refresh if API unavailable
        return true
    end
    
    local imbue = nil
    if slot == "mainhand" then
        imbue = M.get_mainhand_imbue()
    elseif slot == "offhand" then
        imbue = M.get_offhand_imbue()
    end
    
    -- No imbue = needs refresh
    if not imbue then return true end
    
    -- Check remaining duration if API provides it
    -- This would need actual API support
    
    return false
end

-- Try to apply imbue (requires item use API)
function M.try_apply_imbue(slot, item_id)
    if not NS then return false end
    if not item_id then return false end
    
    -- This would require item use API
    -- Most implementations would need:
    -- 1. Check if item is in inventory
    -- 2. Use item on weapon slot
    
    if NS.try_cast then
        -- Some imbues are cast as spells
        local me = NS.GetPlayer and NS.GetPlayer()
        if me then
            return NS.try_cast(item_id, me, "[WEAPON] Imbue", { skip_range = true })
        end
    end
    
    return false
end

-- OOC check for weapon buffs
function M.ooc_check(context)
    if not context or context.in_combat then return false end
    
    local class = context.class
    local spec = context.spec
    
    -- Only check for supported classes
    if class ~= "shaman" and class ~= "rogue" then return false end
    
    local recommended = M.get_recommended_imbue(class, spec)
    if not recommended then return false end
    
    local needs_mh = false
    local needs_oh = false
    
    -- Check mainhand
    if recommended.mh then
        if not M.has_imbue("mainhand", recommended.mh) then
            needs_mh = true
        end
    end
    
    -- Check offhand
    if recommended.oh then
        if not M.has_imbue("offhand", recommended.oh) then
            needs_oh = true
        end
    end
    
    return {
        needs_mh = needs_mh,
        needs_oh = needs_oh,
        recommended_mh = recommended.mh,
        recommended_oh = recommended.oh,
    }
end

-- Initialize
function M.init()
    M.probe_apis()
    
    if NS then
        NS.WeaponImbueManager = M
    end
end

M.init()

return M

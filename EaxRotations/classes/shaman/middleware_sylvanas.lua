-- ============================================================================
-- Shaman Middleware: Tier 1 Gap Analysis Features
-- ============================================================================
-- Features Added:
--   - Auto Tremor Totem (fear bosses)
--   - Purge dispel (enemy magic buffs)
--   - Self-dispel (Cure Poison / Cure Disease)
-- ============================================================================

-- Readability notes:
--   What: Shaman shared middleware.
--   When: dispatcher runs it before the selected playstyle.
--   Why: threat tools are centralized instead of duplicated in every spec.
--   Safety: threat drops require group combat and an ally within 40 yards; never solo.

-- Decision notes:
--   Middleware owns class-wide reactions such as interrupts, defensive checks, utility, and recovery actions.
--   A middleware row should return true only when it actually performs work; otherwise playstyle priorities must continue.
--   Safety gates are repeated here when the action can disrupt combat flow or break crowd control.
local NS = _G.EaxRotations
if not NS then return nil end
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local auto_tremor = require("shared/auto_tremor_sylvanas")
local purge_manager = require("shared/purge_manager_sylvanas")
local SPELLS = NS.ShamanSpells or {}

-- Cure Poison IDs by rank (newest first) - TBC spell IDs
local CURE_POISON_IDS = { 5264, 10295, 10296, 10297 }
-- Cure Disease IDs by rank (newest first) - TBC spell IDs
local CURE_DISEASE_IDS = { 528, 10298, 10299 }

--- Check if player has poison debuff.
-- @return boolean - true if poison debuff present
local function has_poison_debuff()
    if not NS.has_debuff then return false end
    -- Common poison debuff IDs in TBC
    local POISON_IDS = {
        [2818] = true, [2819] = true, [11397] = true, [11398] = true, [11399] = true, [11400] = true,
        [25347] = true, [26975] = true, [27282] = true, -- Deadly Poison
        [3408] = true, [3409] = true, [8995] = true, [8996] = true, [11366] = true,
        [11367] = true, [11368] = true, [11369] = true, [25349] = true, [26967] = true, [27283] = true, -- Crippling Poison
    }
    local me = NS.PLAYER_UNIT
    if not me then return false end
    for id, _ in pairs(POISON_IDS) do
        if NS.has_debuff(me, id) then return true end
    end
    return false
end

--- Check if player has disease debuff.
-- @return boolean - true if disease debuff present
local function has_disease_debuff()
    if not NS.has_debuff then return false end
    -- Common disease debuff IDs in TBC
    local DISEASE_IDS = {
        [3237] = true, [3238] = true, [3239] = true, [3240] = true, [3241] = true, [3242] = true,
        [3243] = true, [3244] = true, [3245] = true, [3246] = true, [3247] = true, [3248] = true,
        [3329] = true, [3330] = true, [3331] = true, [3332] = true, [3333] = true, [3334] = true,
    }
    local me = NS.PLAYER_UNIT
    if not me then return false end
    for id, _ in pairs(DISEASE_IDS) do
        if NS.has_debuff(me, id) then return true end
    end
    return false
end

local strategies = {

    interrupt_manager.register_interrupt_spell("shaman", "EarthShock", SPELLS),

    -- ============================================================================
    -- Auto Tremor Totem (Tier 1 Gap Feature)
    -- ============================================================================
    {
        name = "AutoTremorTotem",
        matches = function(context)
            if context.settings.use_auto_tremor_totem == false then return false end
            if not context.target then return false end
            return auto_tremor.is_fear_boss(context.target)
        end,
        execute = function(context)
            return auto_tremor.try_drop_tremor(context)
        end,
    },

    -- ============================================================================
    -- Purge (Tier 1 Gap Feature)
    -- ============================================================================
    {
        name = "Purge",
        matches = function(context)
            if context.settings.use_purge == false then return false end
            if not context.target then return false end
            
            -- Check PvP only setting
            local pvp_only = context.settings.purge_pvp_only
            if pvp_only == true then  -- Only restrict if explicitly enabled
                if not (context.is_pvp or false) then return false end
            end
            
            -- Check mana floor
            local mana_pct = context.mana_pct or 100
            local min_mana = context.settings.purge_min_mana_pct or 20
            if mana_pct < min_mana then return false end
            
            return purge_manager.has_purgeable_buff(context.target)
        end,
        execute = function(context)
            return purge_manager.try_purge(context)
        end,
    },

    -- ============================================================================
    -- Cure Poison (Tier 1 Gap Feature)
    -- ============================================================================
    {
        name = "CurePoison",
        matches = function(context)
            if context.settings.use_self_dispel == false then return false end
            if not has_poison_debuff() then return false end
            
            -- Check mana floor
            local mana_pct = context.mana_pct or 100
            local min_mana = context.settings.dispel_min_mana_pct or 20
            if mana_pct < min_mana then return false end
            
            -- Check if Cure Poison is learned and ready
            local cure_id = nil
            for _, id in ipairs(CURE_POISON_IDS) do
                if NS.is_spell_learned and NS.is_spell_learned(id) then
                    cure_id = id
                    break
                end
            end
            if not cure_id then return false end
            if not (NS.spell_ready and NS.spell_ready(cure_id)) then return false end
            
            return true
        end,
        execute = function(context)
            local cure_id = nil
            for _, id in ipairs(CURE_POISON_IDS) do
                if NS.is_spell_learned and NS.is_spell_learned(id) then
                    cure_id = id
                    break
                end
            end
            if not cure_id then return false end
            
            return NS.try_cast(cure_id, nil, "[SHAMAN] Cure Poison", { skip_range = true })
        end,
    },

    -- ============================================================================
    -- Cure Disease (Tier 1 Gap Feature)
    -- ============================================================================
    {
        name = "CureDisease",
        matches = function(context)
            if context.settings.use_self_dispel == false then return false end
            if not has_disease_debuff() then return false end
            
            -- Check mana floor
            local mana_pct = context.mana_pct or 100
            local min_mana = context.settings.dispel_min_mana_pct or 20
            if mana_pct < min_mana then return false end
            
            -- Check if Cure Disease is learned and ready
            local cure_id = nil
            for _, id in ipairs(CURE_DISEASE_IDS) do
                if NS.is_spell_learned and NS.is_spell_learned(id) then
                    cure_id = id
                    break
                end
            end
            if not cure_id then return false end
            if not (NS.spell_ready and NS.spell_ready(cure_id)) then return false end
            
            return true
        end,
        execute = function(context)
            local cure_id = nil
            for _, id in ipairs(CURE_DISEASE_IDS) do
                if NS.is_spell_learned and NS.is_spell_learned(id) then
                    cure_id = id
                    break
                end
            end
            if not cure_id then return false end
            
            return NS.try_cast(cure_id, nil, "[SHAMAN] Cure Disease", { skip_range = true })
        end,
    },

}

NS.register_class_middleware("shaman", strategies)
return strategies

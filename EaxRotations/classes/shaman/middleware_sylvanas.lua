-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/shaman/middleware_sylvanas.lua"
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
-- Shaman Middleware: Tier 1 Gap Analysis Features
-- ============================================================================
-- What: TBC Shaman middleware for tremor, purge, and self-dispel support
-- When: Per tick
-- Why: Shared maintenance actions belong above individual playstyles so they can fire consistently
-- Safety: Context and target are nil-guarded; optional modules are required conservatively; dispels check before acting
-- Features Added:
--   - Auto Tremor Totem (fear bosses)
--   - Purge dispel (enemy magic buffs)
--   - Self-dispel (Cure Poison / Cure Disease)
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local auto_tremor = require("shared/auto_tremor_sylvanas")
local purge_manager = require("shared/purge_manager_sylvanas")
local OffensiveDispelDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local SPELLS = NS.ShamanSpells or {}

-- Cure Poison IDs by rank (newest first) - TBC spell IDs
local CURE_POISON_IDS = { 526 }
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
        [11367] = true, [11368] = true, [25349] = true, [26967] = true, [27283] = true, -- Crippling Poison
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
        [3237] = true, [3238] = true, [3240] = true, [3242] = true,
        [3243] = true, [3245] = true, [3246] = true, [3247] = true, [3248] = true,
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
    -- Purge (Tier 1 Gap Feature — upgraded with priority DB targeting)
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

            -- Priority DB scan: strip Bloodlust, BoP, Recklessness, etc. first
            if OffensiveDispelDB and OffensiveDispelDB.find_best_dispel_target then
                local _, priority = OffensiveDispelDB.find_best_dispel_target(context.target, NS)
                if priority and priority >= OffensiveDispelDB.PRIORITY_HIGH then
                    return true  -- High-value buff found, purge it
                end
            end

            -- Fallback: flat purgeable buffs list (PW:S, Renew, Ice Barrier, etc.)
            return purge_manager.has_purgeable_buff(context.target)
        end,
        execute = function(context)
            -- Try priority-DB purge first
            if OffensiveDispelDB and OffensiveDispelDB.find_best_dispel_target then
                local _, priority = OffensiveDispelDB.find_best_dispel_target(context.target, NS)
                if priority and priority >= OffensiveDispelDB.PRIORITY_HIGH then
                    return purge_manager.try_purge(context)
                end
            end
            -- Fallback: flat list purge
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

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return context.in_combat end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("shaman", strategies)
return strategies

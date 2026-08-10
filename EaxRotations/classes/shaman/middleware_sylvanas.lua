-- shaman/middleware_sylvanas.lua — Shaman rotation middleware (totems, weapon imbue, shields).
-- WHAT:  pre-strategy middleware that enriches context with totem state, weapon imbue, and shield status.
-- WHEN:  every tick before strategy evaluation.
-- WHY:   centralizes shaman-specific context enrichment so specs stay focused on rotation logic.
-- SAFETY: nil-guards on all menu references; no allocations in on_update path.

-- ============================================================================
-- Shaman Middleware: Tier 1 Gap Analysis Features
-- Features Added:
--   - Auto Tremor Totem (fear bosses)
--   - Purge dispel (enemy magic buffs)
--   - Self-dispel (Cure Poison / Cure Disease)
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")
if not _ok_int or type(interrupt_manager) ~= "table" then interrupt_manager = nil end
local dispel_manager = NS.DispelManager or require("shared/dispel_manager_sylvanas")
local spec_kit = require("shared/spec_kit_sylvanas")
local auto_tremor = require("shared/auto_tremor_sylvanas")
local purge_manager = require("shared/purge_manager_sylvanas")
local OffensiveDispelDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local SPELLS = NS.ShamanSpells or {}

-- Cure Poison IDs by rank (newest first) - TBC spell IDs
local CURE_POISON_IDS = { 526 }
-- Cure Disease IDs by rank (newest first) - TBC spell IDs
local CURE_DISEASE_IDS = { 2870 }

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

    (interrupt_manager and interrupt_manager.register_interrupt_spell
        and interrupt_manager.register_interrupt_spell("shaman", "EarthShock", SPELLS))
        or { name = "EarthShockSkip", matches = function() return false end, execute = function() return false end },

    -- Defensive dispel via shared DispelManager (Cure Poison / Cure Disease)
    (dispel_manager and dispel_manager.create_dispel_strategy
        and dispel_manager.create_dispel_strategy({ name = "AutoDispel", mid_cast_safe = true }))
        or { name = "AutoDispel", matches = function() return false end, execute = function() return false end },

    -- ============================================================================
    -- Auto Tremor Totem (Tier 1 Gap Feature)
    -- ============================================================================
    {
        name = "AutoTremorTotem",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_auto_tremor_totem", true) then return false end
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
        mid_cast_safe = true,
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_purge", true) then return false end
            if not context.target then return false end
            
            -- Check PvP only setting
            local pvp_only = spec_kit.setting_bool(context, "purge_pvp_only", false)
            if pvp_only == true then  -- Only restrict if explicitly enabled
                if not (context.is_pvp or false) then return false end
            end
            
            -- Check mana floor
            local mana_pct = context.mana_pct or 100
            local min_mana = spec_kit.setting_number(context, "purge_min_mana_pct", 20)
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
            if not spec_kit.setting_bool(context, "use_self_dispel", true) then return false end
            if not has_poison_debuff() then return false end
            
            -- Check mana floor
            local mana_pct = context.mana_pct or 100
            local min_mana = spec_kit.setting_number(context, "dispel_min_mana_pct", 20)
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
            
            return NS.try_cast(cure_id, context.me, "[SHAMAN] Cure Poison", { skip_range = true })
        end,
    },

    -- ============================================================================
    -- Cure Disease (Tier 1 Gap Feature)
    -- ============================================================================
    {
        name = "CureDisease",
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_self_dispel", true) then return false end
            if not has_disease_debuff() then return false end
            
            -- Check mana floor
            local mana_pct = context.mana_pct or 100
            local min_mana = spec_kit.setting_number(context, "dispel_min_mana_pct", 20)
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
            
            return NS.try_cast(cure_id, context.me, "[SHAMAN] Cure Disease", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- LIGHTNING SHIELD (OOC self-buff — maintain shield charges)
    -- ========================================================================
    {
        name = "LightningShield",
        priority = 450,
        matches = function(context)
            if context.in_combat then return false end
            if not spec_kit.setting_bool(context, "auto_lightning_shield", true) then return false end
            local _rbf_ok, RBF = pcall(require, "shared/ranked_buff_families_sylvanas")
            local ls_buffs = (_rbf_ok and RBF and RBF.cast("lightning_shield")) or { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
            -- Combined family: Water Shield is preferred; do not clobber WS with LS.
            local all_shields = (_rbf_ok and RBF and RBF.detect("lightning_shield")) or { 33736, 24398, 23575, 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
            local spell = SPELLS.LightningShield or { id = ls_buffs, name = "LightningShield" }
            if context.me and NS.buff_would_downgrade and NS.buff_would_downgrade(context.me, all_shields, spell) then return false end
            if NS.has_player_buff and NS.has_player_buff(all_shields) then return false end
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            local ls_buffs = { 25472, 25469, 10432, 10431, 8134, 945, 905, 325, 324 }
            local spell = SPELLS.LightningShield or { id = ls_buffs, name = "LightningShield" }
            return NS.try_cast(spell, context.me, "[SHAMAN] Lightning Shield", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- BLOODLUST (Combat offensive cooldown — party/raid haste buff)
    -- ========================================================================
    {
        name = "Bloodlust",
        priority = 750,
        matches = function(context)
            if not spec_kit.setting_bool(context, "use_bloodlust", true) then return false end
            if not context.in_combat then return false end
            if not context.has_valid_enemy_target then return false end
            local spell = SPELLS.Bloodlust or { id = { 2825 }, name = "Bloodlust" }
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.Bloodlust or { id = { 2825 }, name = "Bloodlust" }
            return NS.try_cast(spell, context.me, "[SHAMAN] Bloodlust", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- SELF-HEAL (Combat emergency — Healing Surge / Lesser Healing Wave)
    -- ========================================================================
    {
        name = "Shaman_SelfHeal",
        priority = 850,
        is_defensive = true,
        matches = function(context)
            if not context.in_combat then return false end
            local threshold = spec_kit.setting_number(context, "self_heal_hp", 0)
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then
                local spell = SPELLS.LesserHealingWave or { id = { 25420, 10468, 10467, 10466, 8010, 8008, 8004 }, name = "LesserHealingWave" }
                if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            end
            return false
        end,
        execute = function(context)
            local spell = SPELLS.LesserHealingWave or { id = { 25420, 10468, 10467, 10466, 8010, 8008, 8004 }, name = "LesserHealingWave" }
            return NS.try_cast(spell, context.me, "[SHAMAN] Lesser Healing Wave", { skip_range = true })
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return consumable_manager.should_check(context) end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("shaman", strategies)
return strategies

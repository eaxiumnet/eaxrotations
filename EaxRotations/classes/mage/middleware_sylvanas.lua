-- Mage shared middleware.

-- ============================================================================
-- What: Cross-playstyle mage middleware.
-- When: Before strategies each tick.
-- Why: Shared defensives, interrupts, and utility stay in one place.
-- Safety: Nil-guarded settings; clean false returns; NS.* helpers only.
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local SPELLS = NS.MageSpells or {}
local MAGE_ARMOR_BUFFS = { 27125, 22783, 22782, 6117 }
local MOLTEN_ARMOR_BUFFS = { 30482 }
local ARCANE_INTELLECT_BUFFS = { 27126, 10157, 10156, 1461, 1460, 1459, 23028, 27127 }

local function player_unit(context)
    return context.me or NS.GetPlayer()
end

local function self_spell_ready(spell, context)
    local me = player_unit(context)
    return spell and me and NS.spell_ready(spell, me, { skip_range = true }) == true
end

local function should_use_mage_defensive(context)
    local settings = context.settings or {}
    local threshold = settings.defensive_hp_threshold or 30
    if settings.use_defensives == false then return false end
    return context.in_combat == true and (context.hp or 100) < threshold
end

local function has_armor_buff()
    return NS.has_player_buff(MAGE_ARMOR_BUFFS) or NS.has_player_buff(MOLTEN_ARMOR_BUFFS)
end

local strategies = {

    interrupt_manager.register_interrupt_spell("mage", "Counterspell", SPELLS),

    {
        name = "Defensive",
        matches = function(context)
            if not should_use_mage_defensive(context) then return false end
            local settings = context.settings or {}
            local mana_threshold = settings.mana_shield_mana_threshold or 50
            return (settings.use_ice_block ~= false and self_spell_ready(SPELLS.IceBlock, context))
                or (settings.use_mana_shield ~= false and (context.mana_pct or 0) >= mana_threshold and not NS.has_player_buff(SPELLS.ManaShield) and self_spell_ready(SPELLS.ManaShield, context))
        end,
        execute = function(context)
            local settings = context.settings or {}
            local mana_threshold = settings.mana_shield_mana_threshold or 50
            if settings.use_ice_block ~= false and self_spell_ready(SPELLS.IceBlock, context) then
                return NS.try_cast(SPELLS.IceBlock, player_unit(context), "[MAGE] Ice Block", { skip_range = true }) == true
            end
            if settings.use_mana_shield ~= false and (context.mana_pct or 0) >= mana_threshold and not NS.has_player_buff(SPELLS.ManaShield) and self_spell_ready(SPELLS.ManaShield, context) then
                return NS.try_cast(SPELLS.ManaShield, player_unit(context), "[MAGE] Mana Shield", { skip_range = true }) == true
            end
            return false
        end,
    },

    {
        name = "SelfBuff",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_self_buffs == false then return false end
            if not has_armor_buff() then
                return self_spell_ready(SPELLS.MoltenArmor, context) or self_spell_ready(SPELLS.MageArmor, context)
            end
            if not NS.has_player_buff(ARCANE_INTELLECT_BUFFS) then
                return self_spell_ready(SPELLS.ArcaneIntellect, context)
            end
            return false
        end,
        execute = function(context)
            if not has_armor_buff() then
                if self_spell_ready(SPELLS.MoltenArmor, context) and NS.try_cast(SPELLS.MoltenArmor, player_unit(context), "[MAGE] Molten Armor", { skip_range = true }) then return true end
                if self_spell_ready(SPELLS.MageArmor, context) and NS.try_cast(SPELLS.MageArmor, player_unit(context), "[MAGE] Mage Armor", { skip_range = true }) then return true end
            end
            if not NS.has_player_buff(ARCANE_INTELLECT_BUFFS) and self_spell_ready(SPELLS.ArcaneIntellect, context) then
                return NS.try_cast(SPELLS.ArcaneIntellect, player_unit(context), "[MAGE] Arcane Intellect", { skip_range = true }) == true
            end
            return false
        end,
    },

{
        name = "PvPIceBlock",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_pvp_defensives == false then return false end
            if not NS.should_kite(context) or (context.hp or 100) >= 30 then return false end
            return NS.action_matches(context, { name = "PvPIceBlock", spell = SPELLS.IceBlock, target = "self", requires_target = false })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "PvPIceBlock", spell = SPELLS.IceBlock, target = "self", requires_target = false }, "[MAGE]")
        end,
    },

    -- ============================================================================
    -- ICE BARRIER (Frost talent absorb shield — recast when expired or absorbed)
    -- ============================================================================
    {
        name = "IceBarrier",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_ice_barrier == false then return false end
            if not (context.in_combat and context.me) then return false end
            -- Check if Ice Barrier buff is active (114 # Ice Shield in TBC)
            local barrier_buffs = { 13032, 13031, 13033 }
            if NS.buff_up(context.me, barrier_buffs) then return false end
            return self_spell_ready(SPELLS.IceBarrier, context)
        end,
        execute = function(context)
            if NS.try_cast(SPELLS.IceBarrier, context.me, "[MAGE] Ice Barrier", { skip_range = true }) then
                return true
            end
            return false
        end,
    },

    -- ============================================================================
    -- EVOCATION (Mana recovery — channeled, mana threshold + movement check)
    -- ============================================================================
    {
        name = "Evocation",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_evocation == false then return false end
            if not context.in_combat then return false end
            local threshold = settings.evocation_mana_pct or 20
            if (context.mana_pct or 0) > threshold then return false end
            -- Don't cast while moving (channeled spell)
            local me = context.me or NS.GetPlayer()
            local is_moving_fn = NS.safe_field and NS.safe_field(me, "is_moving")
            if is_moving_fn then
                local ok, moving = pcall(is_moving_fn, me)
                if ok and moving == true then return false end
            end
            return self_spell_ready(SPELLS.Evocation, context)
        end,
        execute = function(context)
            if NS.try_cast(SPELLS.Evocation, context.me, "[MAGE] Evocation", { skip_range = true }) then
                return true
            end
            return false
        end,
    },

    -- ============================================================================
    -- MANA GEM (Mana recovery — Mana Emerald -> Ruby -> Citrine fallback)
    -- ============================================================================
    {
        name = "ManaGem",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_mana_gem == false then return false end
            if not context.in_combat then return false end
            local threshold = settings.mana_gem_mana_pct or 70
            if (context.mana_pct or 0) > threshold then return false end
            return true
        end,
        execute = function(context)
            -- Try Mana Emerald first, then Ruby, then Citrine
            local me = context.me or NS.GetPlayer()
            local debug = NS.get_setting and NS.get_setting("debug_system", false) or false
            local function try_item(item_id, label)
                if NS.is_item_ready and NS.is_item_ready(item_id) then
                    if NS.use_item_by_id and NS.use_item_by_id(item_id, me) then
                        if debug then NS.log("[MAGE] " .. label .. " - Mana: " .. tostring(math.floor(context.mana_pct or 0)) .. "%") end
                        return true
                    end
                end
                return false
            end
            -- Mana Emerald (36799), Mana Ruby (28498), Mana Citrine (22044)
            if try_item(36799, "Mana Emerald") then return true end
            if try_item(28498, "Mana Ruby") then return true end
            if try_item(22044, "Mana Citrine") then return true end
            return false
        end,
    },

    -- ============================================================================
    -- REMOVE CURSE (Self + party scan for curse dispel)
    -- ============================================================================
    {
        name = "RemoveCurse",
        matches = function(context)
            local settings = context.settings or {}
            if settings.auto_remove_curse == false then return false end
            if not context.in_combat then return false end
            local me = context.me or NS.GetPlayer()
            -- Check self for curse debuff
            local curse_debuffs = { 28282, 28271, 11719, 5116, 5115, 23426, 23427, 23230, 23229, 23364, 702, 703, 704, 11014, 11015, 11708, 13323, 13325, 13326, 18223, 18222, 18180, 18179, 17407, 1499, 1513, 1515 }
            if NS.debuff_up(me, curse_debuffs) then return true end
            -- Scan party members for curse
            local GetNumGroupMembers = _G.GetNumGroupMembers
            local n = GetNumGroupMembers and GetNumGroupMembers() or 0
            for i = 1, n do
                local unit = "party" .. i
                if NS.debuff_up(unit, curse_debuffs) then return true end
            end
            return false
        end,
        execute = function(context)
            local me = context.me or NS.GetPlayer()
            -- Determine target: self has curse? use self. else find party member with curse.
            local curse_debuffs = { 28282, 28271, 11719, 5116, 5115, 23426, 23427, 23230, 23229, 23364, 702, 703, 704, 11014, 11015, 11708, 13323, 13325, 13326, 18223, 18222, 18180, 18179, 17407, 1499, 1513, 1515 }
            local target = nil
            if NS.debuff_up(me, curse_debuffs) then
                target = me
            else
                local GetNumGroupMembers = _G.GetNumGroupMembers
                local n = GetNumGroupMembers and GetNumGroupMembers() or 0
                for i = 1, n do
                    local unit = "party" .. i
                    if NS.debuff_up(unit, curse_debuffs) then
                        target = unit
                        break
                    end
                end
            end
            if target and self_spell_ready(SPELLS.RemoveCurse, context) then
                if NS.try_cast(SPELLS.RemoveCurse, target, "[MAGE] Remove Curse", { skip_range = true }) then
                    return true
                end
            end
            return false
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return context.in_combat end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("mage", strategies)
return strategies

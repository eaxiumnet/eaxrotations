-- Druid shared middleware.

-- ============================================================================
-- What: Druid shared middleware for forms, consumables, interrupts, and recovery
-- When: Runs before playstyle strategies each tick
-- Why: Shared behaviors avoid duplication across Druid playstyles
-- Safety: Returns cleanly when form, target, or settings do not permit action; uses NS.* wrappers and nil guards
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local SPELLS = NS.DruidSpells or {}

-- ============================================================================
-- FORM-AWARE CONSUMABLES
-- Use pots/runes in Cat/Bear forms — auto-reshift back to form after use.
-- ============================================================================
local STANCE_CAT = 3
local STANCE_BEAR = 1
local STANCE_CASTER = 0

-- Stances where consumable use is allowed
local ITEM_ALLOWED_STANCE = {
    [STANCE_CASTER] = true,
    [STANCE_CAT] = true,
}
-- Blocked: Bear(1), Aquatic(2), Travel(4), Flight(5)
local function can_use_items(stance)
    if ITEM_ALLOWED_STANCE[stance] then return true end
    -- Moonkin/Tree at stance 5 - check if known
    if stance == 5 then
        local ok = pcall(_G.IsSpellKnown, 24858)
        if ok then return true end
        ok = pcall(_G.IsSpellKnown, 33891)
        if ok then return true end
    end
    return false
end

-- Get form cost for reshift
local function get_form_cost_for_spell(spell_id)
    -- Cat: 30 energy, Bear: 20 rage
    if spell_id == 768 then return 30 end
    if spell_id == 9634 or spell_id == 5487 then return 20 end
    return 0
end

-- Check if we can afford to reshift after using an item in a shifted form
local function can_afford_reshift(stance)
    if stance == STANCE_CASTER then return true end
    local form_spell_id = (stance == STANCE_CAT) and 768 or (stance == STANCE_BEAR) and 9634 or nil
    if not form_spell_id then return true end
    local cost = get_form_cost_for_spell(form_spell_id)
    if cost <= 0 then return true end
    -- Check if we have enough resource to reshift
    if stance == STANCE_CAT then
        local energy = NS.power_current and NS.power_current(NS.POWER_ENERGY) or 0
        return energy >= cost
    elseif stance == STANCE_BEAR then
        local rage = NS.power_current and NS.power_current(NS.POWER_RAGE) or 0
        return rage >= cost
    end
    return true
end

local strategies = {

    interrupt_manager.register_interrupt_spell("druid", "FeralCharge", SPELLS, "bear"),
    interrupt_manager.register_interrupt_spell("druid", "Bash", SPELLS, "bear"),

    -- ============================================================================
    -- FORM-AWARE CONSUMABLES (pots/runes usable in Cat/Bear with auto-reshift)
    -- ============================================================================
    {
        name = "FormAwareConsumables",
        matches = function(context)
            local settings = context.settings or {}
            if not context.in_combat then return false end
            if context.is_stealthed then return false end
            if not can_use_items(context.stance) then return false end
            if not can_afford_reshift(context.stance) then return false end

            -- Check healthstone
            if settings.use_healthstone and context.hp and context.hp <= (settings.healthstone_hp or 30) then
                if NS.is_item_ready and NS.is_item_ready(22103) then return true end
            end

            -- Check healing potion
            if settings.use_healing_potion and context.hp and context.hp <= (settings.healing_potion_hp or 35) then
                if NS.is_item_ready and NS.is_item_ready(22829) then return true end
                if NS.is_item_ready and NS.is_item_ready(22850) then return true end
            end

            return false
        end,
        execute = function(context)
            local settings = context.settings or {}
            local stance = context.stance
            local debug = NS.get_setting and NS.get_setting("debug_system", false) or false

            -- Try healthstone first
            if settings.use_healthstone and context.hp and context.hp <= (settings.healthstone_hp or 30) then
                if NS.is_item_ready and NS.is_item_ready(22103) then
                    if NS.use_item_by_id and NS.use_item_by_id(22103, context.me) then
                        if debug then NS.log("[DRUID] Healthstone - HP: " .. tostring(math.floor(context.hp or 0)) .. "%") end
                        -- Reshift back to form if needed
                        if stance == STANCE_CAT or stance == STANCE_BEAR then
                            local form_spell = (stance == STANCE_CAT) and SPELLS.CatForm or SPELLS.BearForm
                            if form_spell then
                                NS.try_cast(form_spell, context.me, "[DRUID] Reshift after item", { skip_range = true })
                            end
                        end
                        return true
                    end
                end
            end

            -- Try healing potion
            if settings.use_healing_potion and context.hp and context.hp <= (settings.healing_potion_hp or 35) then
                if NS.is_item_ready and NS.is_item_ready(22829) then
                    if NS.use_item_by_id and NS.use_item_by_id(22829, context.me) then
                        if debug then NS.log("[DRUID] Super Healing Potion - HP: " .. tostring(math.floor(context.hp or 0)) .. "%") end
                        -- Reshift back to form if needed
                        if stance == STANCE_CAT or stance == STANCE_BEAR then
                            local form_spell = (stance == STANCE_CAT) and SPELLS.CatForm or SPELLS.BearForm
                            if form_spell then
                                NS.try_cast(form_spell, context.me, "[DRUID] Reshift after item", { skip_range = true })
                            end
                        end
                        return true
                    end
                end
                if NS.is_item_ready and NS.is_item_ready(22850) then
                    if NS.use_item_by_id and NS.use_item_by_id(22850, context.me) then
                        if debug then NS.log("[DRUID] Super Rejuvenation Potion - HP: " .. tostring(math.floor(context.hp or 0)) .. "%") end
                        -- Reshift back to form if needed
                        if stance == STANCE_CAT or stance == STANCE_BEAR then
                            local form_spell = (stance == STANCE_CAT) and SPELLS.CatForm or SPELLS.BearForm
                            if form_spell then
                                NS.try_cast(form_spell, context.me, "[DRUID] Reshift after item", { skip_range = true })
                            end
                        end
                        return true
                    end
                end
            end

            return false
        end,
    },

    -- ============================================================================
    -- PARTY DISPEL (Remove Curse / Abolish Poison party scan)
    -- ============================================================================
    {
        name = "PartyDispel",
        matches = function(context)
            local settings = context.settings or {}
            if settings.auto_dispel == false then return false end
            if not context.in_combat then return false end
            -- Check self for curse or poison
            local me = context.me or NS.GetPlayer()
            -- Curse debuffs (common ones)
            local curse_debuffs = { 28282, 28271, 11719, 5116, 5115, 23426, 23427 }
            if me and NS.debuff_up(me, curse_debuffs) then return true end
            -- Poison debuffs
            local poison_debuffs = { 13218, 13219, 13222, 13223, 13225, 13227, 13228, 13229, 13230, 13235, 13237, 13238, 13240, 13241, 23232, 23233, 23235, 23236, 23237 }
            if me and NS.debuff_up(me, poison_debuffs) then return true end
            -- Scan party members
            local GetNumGroupMembers = _G.GetNumGroupMembers
            local n = GetNumGroupMembers and GetNumGroupMembers() or 0
            for i = 1, n do
                local unit = "party" .. i
                if NS.debuff_up(unit, curse_debuffs) then return true end
                if NS.debuff_up(unit, poison_debuffs) then return true end
            end
            return false
        end,
        execute = function(context)
            local me = context.me or NS.GetPlayer()
            -- Determine best dispel: Remove Curse if curse found, Abolish Poison if only poison
            local curse_debuffs = { 28282, 28271, 11719, 5116, 5115, 23426, 23427 }
            local poison_debuffs = { 13218, 13219, 13222, 13223, 13225, 13227, 13228, 13229, 13230, 13235, 13237, 13238, 13240, 13241, 23232, 23233, 23235, 23236, 23237 }
            local target = nil
            local use_remove_curse = false
            local use_abolish_poison = false
            -- Check self
            if me then
                if NS.debuff_up(me, curse_debuffs) then
                    target = me
                    use_remove_curse = true
                elseif NS.debuff_up(me, poison_debuffs) then
                    target = me
                    use_abolish_poison = true
                end
            end
            -- Scan party
            if not target then
                local GetNumGroupMembers = _G.GetNumGroupMembers
                local n = GetNumGroupMembers and GetNumGroupMembers() or 0
                for i = 1, n do
                    local unit = "party" .. i
                    if NS.debuff_up(unit, curse_debuffs) then
                        target = unit
                        use_remove_curse = true
                        break
                    elseif NS.debuff_up(unit, poison_debuffs) then
                        target = unit
                        use_abolish_poison = true
                        break
                    end
                end
            end
            -- Cast appropriate dispel
            if target then
                if use_remove_curse and SPELLS.RemoveCurse then
                    local ok = NS.try_cast(SPELLS.RemoveCurse, target, "[DRUID] Remove Curse", { skip_range = true })
                    if ok then return true end
                elseif use_abolish_poison and SPELLS.AbolishPoison then
                    local ok = NS.try_cast(SPELLS.AbolishPoison, target, "[DRUID] Abolish Poison", { skip_range = true })
                    if ok then return true end
                end
            end
            return false
        end,
    },

    {
        name = "ThreatDrop",
        matches = function(context)
            if context.settings.use_threat_drop == false then return false end
            return NS.action_matches(context, { name = "ThreatDrop", spell = SPELLS.Cower, target = "self", kind = "threat_drop", requires_target = false, required_form = "cat" })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "ThreatDrop", spell = SPELLS.Cower, target = "self", requires_target = false }, "[DRUID]")
        end,
    },

    -- ========================================================================
    -- MARK OF THE WILD (Self-buff — maintain MotW at all times)
    -- ========================================================================
    {
        name = "MarkOfTheWild",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_self_buffs == false then return false end
            local motw_buffs = { 26991, 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126, 21850, 21849 }
            if NS.has_player_buff and NS.has_player_buff(motw_buffs) then return false end
            local spell = { id = { 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126 }, name = "MarkOfTheWild" }
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast({ id = { 26990, 9885, 9884, 8907, 6756, 5234, 5232, 1126 }, name = "MarkOfTheWild" }, context.me, "[DRUID] Mark of the Wild", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- THORNS (Self-buff — maintain Thorns for minor reflect damage)
    -- ========================================================================
    {
        name = "Thorns",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_self_buffs == false then return false end
            local thorns_buffs = { 26992, 9910, 9756, 8914, 1075, 782, 467 }
            if NS.has_player_buff and NS.has_player_buff(thorns_buffs) then return false end
            local spell = { id = { 26992, 9910, 9756, 8914, 1075, 782, 467 }, name = "Thorns" }
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast({ id = { 26992, 9910, 9756, 8914, 1075, 782, 467 }, name = "Thorns" }, context.me, "[DRUID] Thorns", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- BEAR FORM OOC (Pre-combat — enter Bear form for defensive readiness)
    -- ========================================================================
    {
        name = "BearFormPreCombat",
        matches = function(context)
            local settings = context.settings or {}
            if context.in_combat then return false end
            if settings.auto_bear_form_ooc == false then return false end
            -- Check if already in Bear Form (buff check)
            local bear_buffs = { 9634, 5487 }
            if NS.has_player_buff and NS.has_player_buff(bear_buffs) then return false end
            local spell = { id = { 9634, 5487 }, name = "BearForm" }
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast({ id = { 9634, 5487 }, name = "BearForm" }, context.me, "[DRUID] Bear Form", { skip_range = true })
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return context.in_combat end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("druid", strategies)
return strategies

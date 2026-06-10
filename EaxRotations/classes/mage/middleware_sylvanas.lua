-- Mage shared middleware.


local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local OffensiveDispelDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local SPELLS = NS.MageSpells or {}

-- Spellsteal spell object (TBC: 30449, learned at level 68)
local SPELLSTEAL_SPELL = SPELLS.Spellsteal or { id = { 30449 }, name = "Spellsteal" }

-- CC Break spell objects
local BLINK_SPELL = { id = { 1953 }, name = "Blink" }
local ICE_BLOCK_IDS = { 11958, 45438, 27619 }  -- TBC Ice Block ranks

-- ============================================================================
-- Helper: scan nearby enemies for best Spellsteal target (per-tick caching)
-- ============================================================================
local _cached_steal_unit = nil
local _cached_steal_priority = 0
local _cached_steal_fresh = false
local function get_spellsteal_target(context)
    if _cached_steal_fresh then
        return _cached_steal_unit, _cached_steal_priority
    end
    _cached_steal_unit = nil
    _cached_steal_priority = 0
    local settings = context.settings or {}
    local min_mana = settings.spellsteal_mana_floor or 30
    if (context.mana_pct or 100) < min_mana then return nil, 0 end
    local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
    local best_unit, best_priority = nil, 0
    for _, enemy in ipairs(enemies) do
        if enemy then
            local id, priority = OffensiveDispelDB.find_best_dispel_target(enemy, NS)
            if id and priority and priority > best_priority then
                best_unit, best_priority = enemy, priority
                if best_priority >= OffensiveDispelDB.PRIORITY_CRITICAL then break end
            end
        end
    end
    _cached_steal_unit = best_unit
    _cached_steal_priority = best_priority
    _cached_steal_fresh = true
    return best_unit, best_priority
end
local MAGE_ARMOR_BUFFS = { 27125, 22783, 22782, 6117 }
local MOLTEN_ARMOR_BUFFS = { 30482 }
local ARCANE_INTELLECT_BUFFS = { 27126, 10157, 10156, 1461, 1460, 1459, 23028, 27127 }
local MANA_GEM_ITEM_IDS = { 22044, 8008, 8007, 5513, 5514 }
local CURSE_DEBUFFS = { 28282, 28271, 11719, 5116, 5115, 23426, 23427, 23230, 23229, 23364, 702, 703, 704, 11014, 11015, 11708, 13323, 13325, 13326, 18223, 18222, 18180, 18179, 17407, 1499, 1513, 1515 }

local function player_unit(context)
    return context.me or NS.GetPlayer()
end

local function self_spell_ready(spell, context)
    local me = player_unit(context)
    if not NS.spell_ready then return false end
    return spell and me and NS.spell_ready(spell, me, { skip_range = true })
end

local function should_use_mage_defensive(context)
    local settings = context.settings or {}
    local threshold = settings.defensive_hp_threshold or 30
    if settings.use_defensives == false then return false end
    return context.in_combat == true and (context.hp or 100) < threshold
end

local function has_armor_buff()
    if not NS.has_player_buff then return false end
    return NS.has_player_buff(MAGE_ARMOR_BUFFS) or NS.has_player_buff(MOLTEN_ARMOR_BUFFS)
end

local function first_ready_mana_gem()
    if not NS.is_item_ready then return nil end
    for _, item_id in ipairs(MANA_GEM_ITEM_IDS) do
        local ok, ready = pcall(NS.is_item_ready, item_id)
        if ok and ready then return item_id end
    end
    return nil
end

local function find_curse_target(context)
    if not context then return nil end
    local me = context.me or NS.GetPlayer()
    if me and NS.debuff_up and NS.debuff_up(me, CURSE_DEBUFFS) then return me end
    local party = NS.GetPartyMembers and NS.GetPartyMembers() or nil
    if type(party) ~= "table" then return nil end
    for _, unit in ipairs(party) do
        if unit and NS.debuff_up and NS.debuff_up(unit, CURSE_DEBUFFS) then return unit end
    end
    return nil
end

local strategies = {

    interrupt_manager.register_interrupt_spell("mage", "Counterspell", SPELLS),

    -- ============================================================================
    -- CC Break: preemptively immune incoming CC with Blink or Ice Block
    -- ============================================================================
    {
        name = "MageCCBreak",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_cc_break == false then return false end
            if not context.in_combat then return false end
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Preemptive scan: check if any nearby enemy is casting CC on us
            local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
            for _, enemy in ipairs(enemies) do
                if enemy then
                    local is_casting_cc = OffensiveDispelDB.is_casting_preemptive_cc(enemy)
                    if is_casting_cc then
                        local ok, etarget = pcall(function() return enemy:get_target() end)
                        if ok and etarget and NS.same_unit and NS.same_unit(etarget, me) then
                            -- Ice Block: preemptive immunity (expensive, use only vs big CC)
                            if settings.use_ice_block ~= false then
                                local ib_id = nil
                                for _, id in ipairs(ICE_BLOCK_IDS) do
                                    if NS.is_spell_learned and NS.is_spell_learned(id) then ib_id = id; break end
                                end
                                if ib_id and NS.spell_ready and NS.spell_ready(ib_id) then
                                    return true
                                end
                            end
                            -- Blink: cheaper alternative (breaks stuns/roots, can also dodge projectiles)
                            if NS.is_spell_learned and NS.is_spell_learned(1953) then
                                if NS.spell_ready and NS.spell_ready(1953) then
                                    return true
                                end
                            end
                            return false
                        end
                    end
                end
            end
            -- Fallback: check if player is already under breakable CC (Polymorph fizzle-safety)
            local has_cc = OffensiveDispelDB.is_breakable_cc_active(me, NS)
            if has_cc then
                local ib_id = nil
                for _, id in ipairs(ICE_BLOCK_IDS) do
                    if NS.is_spell_learned and NS.is_spell_learned(id) then ib_id = id; break end
                end
                return ib_id and NS.spell_ready and NS.spell_ready(ib_id) or false
            end
            return false
        end,
        execute = function(context)
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Prefer Ice Block for preemptive immunity (will immune the incoming CC)
            local ib_id = nil
            for _, id in ipairs(ICE_BLOCK_IDS) do
                if NS.is_spell_learned and NS.is_spell_learned(id) then ib_id = id; break end
            end
            if ib_id and NS.spell_ready and NS.spell_ready(ib_id) then
                return NS.try_cast(ib_id, me, "[MAGE] Ice Block → CC Break", { skip_range = true })
            end
            -- Fallback: Blink
            if NS.is_spell_learned and NS.is_spell_learned(1953) and NS.spell_ready and NS.spell_ready(1953) then
                return NS.try_cast(BLINK_SPELL, me, "[MAGE] Blink → CC Break", { skip_range = true })
            end
            return false
        end,
    },

    -- ============================================================================
    -- Spellsteal: strip + steal priority enemy buffs (Bloodlust, BoP, Ice Barrier, etc.)
    -- ============================================================================
    {
        name = "Spellsteal",
        matches = function(context)
            _cached_steal_fresh = false  -- invalidate per-tick cache
            local settings = context.settings or {}
            if settings.use_spellsteal == false then return false end
            if not context.in_combat then return false end
            -- Spell check: Spellsteal is learned at level 68
            if not (NS.is_spell_learned and NS.is_spell_learned(30449)) then return false end
            if not (NS.spell_ready and NS.spell_ready(30449)) then return false end
            -- Find best steal target (cached, no double-scan)
            local _, priority = get_spellsteal_target(context)
            return priority and priority >= OffensiveDispelDB.PRIORITY_LOW
        end,
        execute = function(context)
            local target = get_spellsteal_target(context)
            if not target then return false end
            return NS.try_cast(SPELLSTEAL_SPELL, target, "[MAGE] Spellsteal")
        end,
    },

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
    },    {
        name = "PvPIceBlock",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_pvp_defensives == false then return false end
            if not NS.should_kite or not NS.should_kite(context) or (context.hp or 100) >= 30 then return false end
            return true
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.IceBlock, context.me, "[MAGE] Ice Block", { skip_range = true })
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
            if NS.buff_up and NS.buff_up(context.me, barrier_buffs) then return false end
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
            return first_ready_mana_gem() ~= nil
        end,
        execute = function(context)
            local item_id = first_ready_mana_gem()
            if not item_id or not NS.use_item_by_id then return false end
            return NS.use_item_by_id(item_id) and true or false
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
            return find_curse_target(context) ~= nil
        end,
        execute = function(context)
            local target = find_curse_target(context)
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


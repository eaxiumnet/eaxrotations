-- warlock/middleware_sylvanas.lua — Warlock rotation middleware (pet, shards, curses).
-- WHAT:  pre-strategy middleware that enriches context with pet state, shard count, and curse coverage.
-- WHEN:  every tick before strategy evaluation.
-- WHY:   centralizes warlock-specific context enrichment so specs stay focused on rotation logic.
-- SAFETY: nil-guards on all menu references; no allocations in on_update path.

-- Warlock shared middleware.

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local _ok_int, interrupt_manager = pcall(require, "shared/interrupt_manager_sylvanas")
if not _ok_int or type(interrupt_manager) ~= "table" then interrupt_manager = nil end
local spec_kit = require("shared/spec_kit_sylvanas")
local scan_cache = require("shared/middleware_scan_cache_sylvanas")
local OffensiveDispelDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = {} } end
local SPELLS = NS.WarlockSpells or {}
local SHADOW_CASTER_CLASS_IDS = { [5] = true, [9] = true } -- Priest, Warlock

-- Devour Magic spell object (Felhunter pet ability, TBC: 19505)
local DEVOUR_MAGIC_SPELL = SPELLS.DevourMagic or { id = { 19505 }, name = "DevourMagic" }

-- Death Coil CC break spell object + per-tick target cache
local DEATH_COIL_IDS = { 27223, 17926, 17925, 6789 }
local SHADOW_WARD_IDS = { 28610, 11740, 11739, 6229 }
local _cached_cc_break_target = nil
local _cached_cc_break_fresh = false

-- ============================================================================
-- Helper: scan nearby enemies for best Devour Magic target (per-tick caching)
-- ============================================================================
local _cached_devour_unit = nil
local _cached_devour_priority = 0
local _cached_devour_fresh = false
local function get_devour_magic_target(context)
    if _cached_devour_fresh then
        return _cached_devour_unit, _cached_devour_priority
    end
    _cached_devour_unit = nil
    _cached_devour_priority = 0
    local min_mana = spec_kit.setting_number(context, "devour_magic_mana_floor", 20)
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
    _cached_devour_unit = best_unit
    _cached_devour_priority = best_priority
    _cached_devour_fresh = true
    return best_unit, best_priority
end
local HEALTHSTONE_ITEMS = (TBC.ITEMS and TBC.ITEMS.healthstones) or { 22105, 22104, 22103, 19013, 19012, 19011, 19010, 19009, 19008, 19007, 19006, 19005, 19004, 5510, 5509, 5511, 5512 }
local TBC_POTIONS = (TBC.ITEMS and TBC.ITEMS.potions) or {}-- Shared warlock helpers
local soulshatter_helper = require("shared/warlock_soulshatter_sylvanas")
local healthstone_helper = require("shared/warlock_healthstone_sylvanas")
local death_coil_helper = require("shared/warlock_death_coil_sylvanas")
local shadow_ward_helper = require("shared/warlock_shadow_ward_sylvanas")

local HEALING_POTION_ITEMS = {
    TBC_POTIONS.crystal_healing or 33934,
    TBC_POTIONS.auchenai_healing or 32947,
    TBC_POTIONS.super_healing or 22829,
    TBC_POTIONS.super_rejuvenation or 22850,
    TBC_POTIONS.major_healing or 13446,
    TBC_POTIONS.greater_healing or 1710,
    TBC_POTIONS.healing or 929,
    TBC_POTIONS.lesser_healing or 858,
}
local SOULSTONE_ITEMS = { 22116, 16896, 16895, 16893, 16892, 5232 }
local SOUL_SHARD_ITEM = 6265  -- TBC soul shard reagent

-- ============================================================================
-- CC Break: interrupt incoming CC with Death Coil (horror + self-heal)
-- ============================================================================
local strategies = {
    (interrupt_manager and interrupt_manager.register_interrupt_spell
        and interrupt_manager.register_interrupt_spell("warlock", "SpellLock", SPELLS))
        or { name = "SpellLockSkip", matches = function() return false end, execute = function() return false end },
    {
        name = "WarlockCCBreak",
        matches = function(context)
            _cached_cc_break_fresh = false  -- invalidate per-tick cache
            if spec_kit.setting_bool(context, "use_cc_break", true) == false then return false end
            if not context.in_combat then return false end
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Preemptive scan: enemy casting CC at us → Death Coil to interrupt
            local preemptive_enemy = scan_cache.memoize(context, "warlock_preemptive_cc", function()
                local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
                for _, enemy in ipairs(enemies) do
                    if enemy and OffensiveDispelDB.is_casting_preemptive_cc(enemy) then
                        local ok, etarget = pcall(function() return enemy:get_target() end)
                        if ok and etarget and NS.same_unit and NS.same_unit(etarget, me) then
                            return enemy
                        end
                    end
                end
                return false
            end)
            if preemptive_enemy then
                local dc_id = nil
                for _, id in ipairs(DEATH_COIL_IDS) do
                    if NS.is_spell_learned and NS.is_spell_learned(id) then dc_id = id; break end
                end
                if dc_id and NS.spell_ready and NS.spell_ready(dc_id, preemptive_enemy) then
                    _cached_cc_break_target = preemptive_enemy
                    _cached_cc_break_fresh = true
                    return true
                end
            end
            -- Fallback: player already under breakable CC — Death Coil the attacker if possible
            local has_cc = OffensiveDispelDB.is_breakable_cc_active(me, NS)
            if has_cc and context.target then
                local dc_id = nil
                for _, id in ipairs(DEATH_COIL_IDS) do
                    if NS.is_spell_learned and NS.is_spell_learned(id) then dc_id = id; break end
                end
                if dc_id and NS.spell_ready and NS.spell_ready(dc_id, context.target) then
                    _cached_cc_break_target = context.target
                    _cached_cc_break_fresh = true
                    return true
                end
            end
            return false
        end,
        execute = function(context)
            local target = _cached_cc_break_fresh and _cached_cc_break_target or context.target
            if not target then return false end
            local dc_id = nil
            for _, id in ipairs(DEATH_COIL_IDS) do
                if NS.is_spell_learned and NS.is_spell_learned(id) then dc_id = id; break end
            end
            if not dc_id then return false end
            return NS.try_cast({ id = { dc_id }, name = "DeathCoil" }, target, "[WARLOCK] Death Coil → CC Break")
        end,
    },

    -- ============================================================================
    -- Devour Magic: Felhunter pet strips + heals from priority enemy buffs
    -- ============================================================================
    {
        name = "DevourMagic",
        matches = function(context)
            _cached_devour_fresh = false  -- invalidate per-tick cache
            if spec_kit.setting_bool(context, "use_devour_magic", true) == false then return false end
            if not context.in_combat then return false end
            -- Spell check: Devour Magic requires Felhunter pet
            if not (NS.is_spell_learned and NS.is_spell_learned(19505)) then return false end
            if not (NS.spell_ready and NS.spell_ready(19505)) then return false end
            -- Find best dispel target (cached, no double-scan)
            local _, priority = get_devour_magic_target(context)
            return priority and priority >= OffensiveDispelDB.PRIORITY_LOW
        end,
        execute = function(context)
            local target = get_devour_magic_target(context)
            if not target then return false end
            return NS.try_cast(DEVOUR_MAGIC_SPELL, target, "[WARLOCK] Devour Magic")
        end,
    },

    -- Devour Magic Friendly: for group help in dungeons, toggle default off
    {
        name = "DevourMagicFriendly",
        matches = function(context)
            if spec_kit.setting_bool(context, "use_devour_magic_friendly", false) == false then return false end
            if not context.in_combat then return false end
            if not (NS.is_spell_learned and NS.is_spell_learned(19505)) then return false end
            if not (NS.spell_ready and NS.spell_ready(19505)) then return false end
            local M = NS.DispelManager
            if not M or not M.can_dispel("magic") then return false end
            -- scan self + party for magic debuff
            local targets = {context.me}
            if context.party_members then
                for _, p in ipairs(context.party_members) do table.insert(targets, p) end
            end
            for _, t in ipairs(targets) do
                if t and M.scan_unit_debuffs then
                    local dtype = M.scan_unit_debuffs(t)
                    if dtype == "magic" then return true end
                end
            end
            return false
        end,
        execute = function(context)
            local M = NS.DispelManager
            if not M then return false end
            local targets = {context.me}
            if context.party_members then
                for _, p in ipairs(context.party_members) do table.insert(targets, p) end
            end
            for _, t in ipairs(targets) do
                if t and M.scan_unit_debuffs then
                    local dtype = M.scan_unit_debuffs(t)
                    if dtype == "magic" then
                        return NS.try_cast(DEVOUR_MAGIC_SPELL, t, "[WARLOCK] Devour Magic (friendly group)")
                    end
                end
            end
            return false
        end,
    },        {
            name = "PvPHowlofTerror",
            matches = function(context)
                if spec_kit.setting_bool(context, "use_pvp_defensives", true) == false then return false end
                if NS.should_kite and not NS.should_kite(context) then return false end
                if (NS.GetEnemiesCount and NS.GetEnemiesCount(8) or 0) < 2 then return false end
                return true
            end,
        execute = function(context)
            return NS.try_cast(SPELLS.HowlofTerror, context.me, "[WARLOCK] Howl of Terror", { skip_range = true })
        end,
    },        {
            name = "Soulshatter",
            priority = 920,
            is_defensive = true,
            matches = function(context)
                return soulshatter_helper.matches(context, SPELLS.Soulshatter)
            end,
            execute = function(context)
                return soulshatter_helper.execute(context, SPELLS.Soulshatter, "[WARLOCK] Soulshatter")
            end,
        },

    -- ========================================================================
    -- DEATH COIL (Emergency heal + fear — highest priority in combat)
    -- ========================================================================
    death_coil_helper.make_strategy("Warlock_DeathCoil", SPELLS.DeathCoil or { id = DEATH_COIL_IDS, name = "DeathCoil" }, {
        priority = 1000,
        is_defensive = true,
        label = "[WARLOCK] Death Coil",
        require_in_combat = true,
    }),

    -- ========================================================================
    -- HEALTHSTONE (Recovery - Healthstone then Healing Potion)
    -- ========================================================================
    healthstone_helper.make_strategy("Warlock_Healthstone", {
        healthstone_ids = HEALTHSTONE_ITEMS,
        fallback_potion_ids = HEALING_POTION_ITEMS,
        allow_while_casting = true,
        use_consumable_manager = true,
        priority = 850,
        is_defensive = true,
    }),

    -- ========================================================================
    -- SHADOW WARD (Absorb shadow damage — PvP caster defense)
    -- ========================================================================
    shadow_ward_helper.make_strategy("Warlock_ShadowWard", SPELLS.ShadowWard or { id = SHADOW_WARD_IDS, name = "ShadowWard" }, {
        priority = 900,
        is_defensive = true,
        label = "[WARLOCK] Shadow Ward",
    }),

    -- ========================================================================
    -- FEL DOMINATION (Instant pet summon — emergency replacement)
    -- ========================================================================
    {
        name = "Warlock_FelDomination",
        priority = 950,
        is_defensive = true,
        matches = function(context)
            if not context.in_combat then return false end
            if spec_kit.setting_bool(context, "use_fel_domination", true) == false then return false end
            local hp = context.hp or 100
            if hp > spec_kit.setting_number(context, "fel_domination_hp", 35) then return false end
            -- Only if pet is dead
            if NS.has_pet and NS.has_pet() then return false end
            local spell = { id = { 18708 }, name = "FelDomination" }
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            return NS.try_cast({ id = { 18708 }, name = "FelDomination" }, context.me, "[WARLOCK] Fel Domination", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- DEMONIC SACRIFICE (Emergency defensive — sacrifice pet for buff)
    -- ========================================================================
    {
        name = "Warlock_DemonicSacrifice",
        priority = 925,
        is_defensive = true,
        matches = function(context)
            if not context.in_combat then return false end
            if spec_kit.setting_bool(context, "use_demonic_sacrifice", true) == false then return false end
            local hp = context.hp or 100
            if hp > spec_kit.setting_number(context, "demonic_sacrifice_hp", 20) then return false end
            -- Must have a pet alive to sacrifice
            if not NS.has_pet or not NS.has_pet() then return false end
            local spell = { id = { 18788 }, name = "DemonicSacrifice" }
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            return NS.try_cast({ id = { 18788 }, name = "DemonicSacrifice" }, context.me, "[WARLOCK] Demonic Sacrifice", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- HEALTH FUNNEL (Heal pet during combat — maintain pet HP)
    -- ========================================================================
    {
        name = "Warlock_HealthFunnel",
        priority = 800,
        is_defensive = true,
        matches = function(context)
            if not context.in_combat then return false end
            if spec_kit.setting_bool(context, "use_health_funnel", true) == false then return false end
            local hp = context.hp or 100
            local hp_threshold = spec_kit.setting_number(context, "health_funnel_hp", 60)
            if hp < hp_threshold then return false end
            -- Check pet exists and is low
            if not NS.has_pet or not NS.has_pet() then return false end
            local pet_hp_pct = NS.get_pet_hp and NS.get_pet_hp() or 100
            if pet_hp_pct > spec_kit.setting_number(context, "health_funnel_pet_hp", 40) then return false end
            local spell = { id = { 27259, 11695, 11694, 11693, 3700, 3699, 3698, 755 }, name = "HealthFunnel" }
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            local pet = NS.get_pet and NS.get_pet()
            if not pet then return false end
            return NS.try_cast({ id = { 27259, 11695, 11694, 11693, 3700, 3699, 3698, 755 }, name = "HealthFunnel" }, pet, "[WARLOCK] Health Funnel")
        end,
    },

    -- ========================================================================
    -- CREATE HEALTHSTONE (Pre-combat self-buff — ensure Healthstone is ready)
    -- ========================================================================
    {
        name = "Warlock_CreateHealthstone",
        priority = 500,
        is_defensive = true,
        matches = function(context)
            if context.in_combat then return false end
            if spec_kit.setting_bool(context, "auto_create_healthstone", true) == false then return false end
            -- Check if we already have a Healthstone (item check)
            local has_hs = false
            if NS.has_item then
                for _, id in ipairs(HEALTHSTONE_ITEMS) do
                    if NS.has_item(id) then has_hs = true; break end
                end
            end
            if has_hs then return false end
            -- Require at least one soul shard to create
            local has_shard = false
            if NS.has_item then
                has_shard = NS.has_item(SOUL_SHARD_ITEM)
            end
            -- Bag scan fallback for has_item being unavailable
            if not has_shard and NS.core and NS.core.inventory and NS.core.inventory.get_item_count then
                local ok_shard, count = pcall(NS.core.inventory.get_item_count, SOUL_SHARD_ITEM)
                has_shard = ok_shard and (count or 0) > 0
            end
            if not has_shard then return false end
            local spell = { id = { 27230, 11730, 11729, 6202, 6201, 5699 }, name = "CreateHealthstone" }
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            return NS.try_cast({ id = { 27230, 11730, 11729, 6202, 6201, 5699 }, name = "CreateHealthstone" }, context.me, "[WARLOCK] Create Healthstone", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- CREATE SOULSTONE (Pre-combat self-buff — ensure Soulstone is active)
    -- ========================================================================
    {
        name = "Warlock_CreateSoulstone",
        priority = 490,
        is_defensive = true,
        matches = function(context)
            if context.in_combat then return false end
            if spec_kit.setting_bool(context, "auto_create_soulstone", true) == false then return false end
            -- Check if Soulstone buff is already active
            local ss_buffs = { 27238, 20756, 20755, 20752, 693 }
            if NS.has_player_buff and NS.has_player_buff(ss_buffs) then return false end
            -- Check if we have a Soulstone item in inventory
            if NS.has_item then
                for _, id in ipairs(SOULSTONE_ITEMS) do
                    if NS.has_item(id) then return false end
                end
                -- Require at least one soul shard to create
                if not NS.has_item(SOUL_SHARD_ITEM) then return false end
            end
            local spell = { id = { 27238, 20756, 20755, 20752, 693 }, name = "CreateSoulstone" }
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            return NS.try_cast({ id = { 27238, 20756, 20755, 20752, 693 }, name = "CreateSoulstone" }, context.me, "[WARLOCK] Create Soulstone", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- DEMON ARMOR / FEL ARMOR (OOC self-buff — maintain armor buff)
    -- ========================================================================
    {
        name = "Warlock_DemonArmor",
        priority = 480,
        is_defensive = true,
        matches = function(context)
            if context.in_combat then return false end
            if spec_kit.setting_bool(context, "auto_demon_armor", true) == false then return false end
            -- Prefer Fel Armor (TBC level 62+) if learned; fall back to Demon Armor
            local _rbf_ok, RBF = pcall(require, "shared/ranked_buff_families_sylvanas")
            local fel_armor_ids = (_rbf_ok and RBF and RBF.cast("fel_armor")) or { 28189, 28176 }
            local demon_armor_ids = (_rbf_ok and RBF and RBF.cast("demon_armor")) or { 27260, 11735, 11734, 11733, 1086, 706, 687, 696 }
            local all_armor = (_rbf_ok and RBF and RBF.detect("fel_armor")) or { 28189, 28176, 27260, 11735, 11734, 11733, 1086, 706, 687, 696 }
            local has_fel = NS.is_spell_learned and NS.is_spell_learned(fel_armor_ids[1])
            local spell = has_fel and { id = fel_armor_ids, name = "FelArmor" } or { id = demon_armor_ids, name = "DemonArmor" }
            -- Any better/equal family armor already up (Fel over Demon, higher rank).
            if context.me and NS.buff_would_downgrade and NS.buff_would_downgrade(context.me, all_armor, spell) then return false end
            if has_fel and NS.has_player_buff and NS.has_player_buff(fel_armor_ids) then return false end
            if not has_fel and NS.has_player_buff and NS.has_player_buff(demon_armor_ids) then return false end
            -- Also skip if other armor family is already active (prevents Fel↔Demon toggle).
            if NS.has_player_buff and NS.has_player_buff(all_armor) then return false end
            if NS.spell_ready then return NS.spell_ready(spell, context.me, { skip_range = true }) end
            return false
        end,
        execute = function(context)
            local fel_armor_ids = { 28189, 28176 }
            local has_fel = NS.is_spell_learned and NS.is_spell_learned(fel_armor_ids[1])
            local spell = has_fel and { id = fel_armor_ids, name = "FelArmor" } or { id = { 27260, 11735, 11734, 11733, 1086, 706 }, name = "DemonArmor" }
            return NS.try_cast(spell, context.me, "[WARLOCK] " .. (has_fel and "Fel Armor" or "Demon Armor"), { skip_range = true })
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return consumable_manager.should_check(context) end, execute = function(context) return consumable_manager.on_update(context) end }

}
NS.register_class_middleware("warlock", strategies)
return strategies


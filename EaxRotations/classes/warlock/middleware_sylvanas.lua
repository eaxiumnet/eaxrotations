-- Warlock shared middleware.

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = {} } end
local SPELLS = NS.WarlockSpells or {}
local HEALTHSTONE_ITEMS = (TBC.ITEMS and TBC.ITEMS.healthstones) or { 22105, 22104, 22103, 19013, 19012, 19011, 19010, 19009, 19008, 19007, 19006, 19005, 19004, 5510, 5509, 5511, 5512 }
local TBC_POTIONS = (TBC.ITEMS and TBC.ITEMS.potions) or {}
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
local strategies = {

    interrupt_manager.register_interrupt_spell("warlock", "SpellLock", SPELLS),

    {
        name = "PvPHowlofTerror",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_pvp_defensives == false then return false end
            if not NS.should_kite(context) then return false end
            if (NS.GetEnemiesCount and NS.GetEnemiesCount(8) or 0) < 2 then return false end
            return NS.action_matches(context, { name = "PvPHowlofTerror", spell = SPELLS.HowlofTerror, target = "self", requires_target = false })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "PvPHowlofTerror", spell = SPELLS.HowlofTerror, target = "self", requires_target = false }, "[WARLOCK]")
        end,
    },

    {
        name = "ThreatDrop",
        matches = function(context)
            if context.settings.use_threat_drop == false then return false end
            return NS.action_matches(context, { name = "ThreatDrop", spell = SPELLS.Soulshatter, target = "self", kind = "threat_drop", requires_target = false })
        end,
        execute = function(context)
            return NS.action_execute(context, { name = "ThreatDrop", spell = SPELLS.Soulshatter, target = "self", requires_target = false }, "[WARLOCK]")
        end,
    },

    -- ========================================================================
    -- DEATH COIL (Emergency heal + fear — highest priority in combat)
    -- ========================================================================
    {
        name = "Warlock_DeathCoil",
        priority = 1000,
        is_defensive = true,
        matches = function(context)
            local settings = context.settings or {}
            if not context.in_combat then return false end
            local threshold = settings.death_coil_hp or 0
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then
                return true
            end
            return false
        end,
        execute = function(context)
            -- Death Coil is a fear effect that heals the warlock when it damages the enemy
            -- Cast on enemy target, the self-heal is a passive effect
            local target = context.target
            if not target then return false end
            local spell = SPELLS.DeathCoil or { id = { 6789, 17928, 17924, 17923 }, name = "DeathCoil" }
            if NS.spell_ready and NS.spell_ready(spell, target, {}) then
                return NS.try_cast(spell, target, "[WARRIOR] Death Coil")
            end
            return false
        end,
    },

    -- ========================================================================
    -- HEALTHSTONE (Recovery - Healthstone then Healing Potion)
    -- ========================================================================
    {
        name = "Warlock_Healthstone",
        priority = 850,
        is_defensive = true,
        matches = function(context)
            local settings = context.settings or {}
            if not context.in_combat then return false end
            local threshold = settings.healthstone_hp or 0
            if threshold <= 0 then return false end
            if (context.hp or 100) <= threshold then
                return true
            end
            return false
        end,
        execute = function(context)
            -- Try Healthstone first (item-based, has CD)
            local used_item = false
            if NS.use_item and context.me then
                for _, item_id in ipairs(HEALTHSTONE_ITEMS) do
                    if NS.use_item(item_id, context.me) then
                        used_item = true
                        break
                    end
                end
            end
            if used_item then return true end

            -- Fallback: Healing Potion if no Healthstone used
            if NS.use_item and context.me then
                for _, item_id in ipairs(HEALING_POTION_ITEMS) do
                    if NS.use_item(item_id, context.me) then
                        return true
                    end
                end
            end
            return false
        end,
    },

    -- ========================================================================
    -- SHADOW WARD (Absorb shadow damage — PvP caster defense)
    -- ========================================================================
    {
        name = "Warlock_ShadowWard",
        priority = 900,
        is_defensive = true,
        matches = function(context)
            local settings = context.settings or {}
            if not context.in_combat then return false end
            if settings.use_shadow_ward == false then return false end
            local hp = context.hp or 100
            local threshold = settings.shadow_ward_hp or 70
            if hp > threshold then return false end
            -- Check if Shadow Ward buff already active
            local ward_buffs = { 28610, 6229 }
            if NS.has_player_buff and NS.has_player_buff(ward_buffs) then return false end
            -- Only vs shadow casters (Warlock, Shadow Priest)
            if context.target then
                local class = nil
                pcall(function() class = context.target:get_class() end)
                if class ~= "WARLOCK" and class ~= "PRIEST" then return false end
            end
            local spell = SPELLS.ShadowWard or { id = { 28610, 6229 }, name = "ShadowWard" }
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
        end,
        execute = function(context)
            local spell = SPELLS.ShadowWard or { id = { 28610, 6229 }, name = "ShadowWard" }
            return NS.try_cast(spell, context.me, "[WARLOCK] Shadow Ward", { skip_range = true })
        end,
    },

    -- ========================================================================
    -- FEL DOMINATION (Instant pet summon — emergency replacement)
    -- ========================================================================
    {
        name = "Warlock_FelDomination",
        priority = 950,
        is_defensive = true,
        matches = function(context)
            local settings = context.settings or {}
            if not context.in_combat then return false end
            if settings.use_fel_domination == false then return false end
            local hp = context.hp or 100
            if hp > (settings.fel_domination_hp or 35) then return false end
            -- Only if pet is dead
            if NS.has_pet and NS.has_pet() then return false end
            local spell = { id = { 18708 }, name = "FelDomination" }
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
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
            local settings = context.settings or {}
            if not context.in_combat then return false end
            if settings.use_demonic_sacrifice == false then return false end
            local hp = context.hp or 100
            if hp > (settings.demonic_sacrifice_hp or 20) then return false end
            -- Must have a pet alive to sacrifice
            if not NS.has_pet or not NS.has_pet() then return false end
            local spell = { id = { 18788 }, name = "DemonicSacrifice" }
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
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
            local settings = context.settings or {}
            if not context.in_combat then return false end
            if settings.use_health_funnel == false then return false end
            local hp = context.hp or 100
            local hp_threshold = settings.health_funnel_hp or 60
            if hp < hp_threshold then return false end
            -- Check pet exists and is low
            if not NS.has_pet or not NS.has_pet() then return false end
            local pet_hp_pct = NS.get_pet_hp and NS.get_pet_hp() or 100
            if pet_hp_pct > (settings.health_funnel_pet_hp or 40) then return false end
            local spell = { id = { 27259, 11695, 11694, 11693, 3700, 3699, 3698, 755 }, name = "HealthFunnel" }
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
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
            local settings = context.settings or {}
            if context.in_combat then return false end
            if settings.auto_create_healthstone == false then return false end
            -- Check if we already have a Healthstone (item check)
            if NS.has_item then
                for _, id in ipairs(HEALTHSTONE_ITEMS) do
                    if NS.has_item(id) then return false end
                end
                -- Require at least one soul shard to create
                if not NS.has_item(SOUL_SHARD_ITEM) then return false end
            end
            local spell = { id = { 27230, 11730, 11729, 6202, 6201, 5699 }, name = "CreateHealthstone" }
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
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
            local settings = context.settings or {}
            if context.in_combat then return false end
            if settings.auto_create_soulstone == false then return false end
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
            return NS.spell_ready and NS.spell_ready(spell, context.me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast({ id = { 27238, 20756, 20755, 20752, 693 }, name = "CreateSoulstone" }, context.me, "[WARLOCK] Create Soulstone", { skip_range = true })
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return context.in_combat end, execute = function(context) return consumable_manager.on_update(context) end },

}
NS.register_class_middleware("warlock", strategies)
return strategies

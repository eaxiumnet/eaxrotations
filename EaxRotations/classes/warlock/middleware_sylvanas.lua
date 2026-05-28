-- =========================================================================
-- EaxRotations File Version: 1.1.1
-- Last Modified: 2026-05-27
-- Change: File version stamp for runtime load verification
-- =========================================================================
local __eax_file = "classes/warlock/middleware_sylvanas.lua"
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
-- Warlock shared middleware.
-- ============================================================================
-- What: TBC Warlock middleware for interrupts, threat drops, defensives, and consumables
-- When: Per tick
-- Why: Shared recovery and survival logic should run before playstyle-specific priorities
-- Safety: Settings and targets are nil-guarded; optional modules load conservatively; item use is checked before cast
-- ============================================================================

local NS = _G.EaxRotations
if not NS then return nil end
local consumable_manager = require("shared/consumable_manager_sylvanas")
local interrupt_manager = require("shared/interrupt_manager_sylvanas")
local OffensiveDispelDB = NS.OffensiveDispelDB or require("shared/offensive_dispel_sylvanas")
local _data_ok, TBC = pcall(require, "shared/tbc_data_sylvanas")
if not _data_ok or type(TBC) ~= "table" then TBC = { ITEMS = {} } end
local SPELLS = NS.WarlockSpells or {}

-- Devour Magic spell object (Felhunter pet ability, TBC: 19505)
local DEVOUR_MAGIC_SPELL = SPELLS.DevourMagic or { id = { 19505 }, name = "DevourMagic" }

-- Death Coil CC break spell object + per-tick target cache
local DEATH_COIL_IDS = { 6789, 17928, 17924, 17923 }
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
    local settings = context.settings or {}
    local min_mana = settings.devour_magic_mana_floor or 20
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
local TBC_POTIONS = (TBC.ITEMS and TBC.ITEMS.potions) or {}

-- Local anti-spam timers for long-CD spells
local _last_soulshatter_time = 0
local _last_create_hs_retry = 0
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
    {
        name = "WarlockCCBreak",
        matches = function(context)
            _cached_cc_break_fresh = false  -- invalidate per-tick cache
            local settings = context.settings or {}
            if settings.use_cc_break == false then return false end
            if not context.in_combat then return false end
            local me = context.me or NS.GetPlayer()
            if not me then return false end
            -- Preemptive scan: enemy casting CC at us → Death Coil to interrupt
            local enemies = NS.GetEnemiesInRange and NS.GetEnemiesInRange(30) or {}
            for _, enemy in ipairs(enemies) do
                if enemy then
                    local is_casting_cc = OffensiveDispelDB.is_casting_preemptive_cc(enemy)
                    if is_casting_cc then
                        local ok, etarget = pcall(function() return enemy:get_target() end)
                        if ok and etarget and NS.same_unit and NS.same_unit(etarget, me) then
                            -- Death Coil ready? (2min CD horror, interrupts the cast)
                            local dc_id = nil
                            for _, id in ipairs(DEATH_COIL_IDS) do
                                if NS.is_spell_learned and NS.is_spell_learned(id) then dc_id = id; break end
                            end
                            if dc_id and NS.spell_ready and NS.spell_ready(dc_id, enemy) then
                                _cached_cc_break_target = enemy
                                _cached_cc_break_fresh = true
                                return true
                            end
                            break
                        end
                    end
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
            local settings = context.settings or {}
            if settings.use_devour_magic == false then return false end
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

    {
        name = "PvPHowlofTerror",
        matches = function(context)
            local settings = context.settings or {}
            if settings.use_pvp_defensives == false then return false end
            if not NS.should_kite(context) then return false end
            if (NS.GetEnemiesCount and NS.GetEnemiesCount(8) or 0) < 2 then return false end
            return true
        end,
        execute = function(context)
            return NS.try_cast(SPELLS.HowlofTerror, context.me, "[WARLOCK] Howl of Terror", { skip_range = true })
        end,
    },

    {
        name = "ThreatDrop",
        matches = function(context)
            if context.settings.use_threat_drop == false then return false end
            if not context.in_combat then return false end
            -- Only when threat is high (90%+)
            if context.threat_pct and context.threat_pct < 90 then return false end
            -- Local anti-spam: Soulshatter has 5min cooldown, enforce minimum 290s between casts
            if (NS.time_now() - _last_soulshatter_time) < 290 then return false end
            local me = context.me or (NS.GetPlayer and NS.GetPlayer())
            if not me then return false end
            return NS.spell_ready(SPELLS.Soulshatter, me, { skip_range = true })
        end,
        execute = function(context)
            local me = context.me or (NS.GetPlayer and NS.GetPlayer()) or NS.PLAYER_UNIT
            local ok = NS.try_cast(SPELLS.Soulshatter, me, "[WARLOCK] Soulshatter", { skip_range = true })
            if ok then _last_soulshatter_time = NS.time_now() end
            return ok
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
            if NS.spell_ready(spell, target, {}) then
                return NS.try_cast(spell, target, "[WARLOCK] Death Coil")
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
            return NS.spell_ready(spell, context.me, { skip_range = true })
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
            return NS.spell_ready(spell, context.me, { skip_range = true })
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
            return NS.spell_ready(spell, context.me, { skip_range = true })
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
            return NS.spell_ready(spell, context.me, { skip_range = true })
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
            -- Retry throttle: don't retry for 3s after last failure (e.g. missing reagent)
            if (NS.time_now() - _last_create_hs_retry) < 3 then return false end
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
            if not has_shard and NS.inventory and NS.inventory.get_item_count then
                has_shard = (NS.inventory.get_item_count(SOUL_SHARD_ITEM) or 0) > 0
            end
            if not has_shard then
                _last_create_hs_retry = NS.time_now()
                return false
            end
            local spell = { id = { 27230, 11730, 11729, 6202, 6201, 5699 }, name = "CreateHealthstone" }
            return NS.spell_ready(spell, context.me, { skip_range = true })
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
            return NS.spell_ready(spell, context.me, { skip_range = true })
        end,
        execute = function(context)
            return NS.try_cast({ id = { 27238, 20756, 20755, 20752, 693 }, name = "CreateSoulstone" }, context.me, "[WARLOCK] Create Soulstone", { skip_range = true })
        end,
    },

    -- Auto-consumable usage
    { name = "AutoConsumable", matches = function(context) return context.in_combat end, execute = function(context) return consumable_manager.on_update(context) end }

}
NS.register_class_middleware("warlock", strategies)
return strategies

